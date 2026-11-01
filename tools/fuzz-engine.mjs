#!/usr/bin/env node
// Stress test for the compiled Lean game program (`engine/.lake/build/bin/poker`).
//
// It plays many random games through the program's JSON protocol (one request per line,
// MVP §13), the same way the web app does, and checks every reply. It uses only Node's
// built-in modules, so it runs anywhere Node runs (Linux, macOS, Windows).
//
//   node tools/fuzz-engine.mjs --games 300          play 300 games
//   node tools/fuzz-engine.mjs --minutes 45         stop after 45 minutes
//   node tools/fuzz-engine.mjs --workers 4          run 4 programs at once
//   node tools/fuzz-engine.mjs --replay file.json   rerun one saved failure
//
// Other options: --seed N (the fuzzer's own seed), --out DIR (where repros and the summary
// go, default ./fuzz-out), --bad-rate 0.1, --replay-rate 0.05, --stop-after-serious MIN.
// The program is found at $POKER_BIN, else engine/.lake/build/bin/poker(.exe).
//
// Sources of truth: engine/Engine/Protocol.lean (requests and state JSON), MVP.txt §4
// (rules), MVP.txt §6 (review labels).

import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline";

const TOTAL_CHIPS = 1000;
const RISKS = [0, 25, 50, 75, 100];
const BLUFFS = [0, 20, 33, 60];
const STATUSES = new Set(["playing", "handOver", "gameOver"]);
const LABELS = new Set(["Best", "Good", "Inaccuracy", "Mistake", "Blunder"]);
const REPLY_TIMEOUT_MS = 60_000; // a reply slower than this counts as a hang
const SLOW_MS = 3_000;
const MAX_HANDS_PER_GAME = 400;
// Failure kinds that stop the run early (after a short extra search).
const SERIOUS = new Set(["crash", "hang", "stuck-turn", "chips", "rejected-changed-state"]);

// ---------- options ----------

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..");

function parseArgs(argv) {
  const o = {
    games: 3000, minutes: 45, workers: 1, seed: 1, out: "fuzz-out",
    badRate: 0.1, replayRate: 0.05, stopAfterSerious: 10, replay: null,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i], v = argv[i + 1];
    const num = () => { i++; return Number(v); };
    if (a === "--games") o.games = num();
    else if (a === "--minutes") o.minutes = num();
    else if (a === "--workers") o.workers = num();
    else if (a === "--seed") o.seed = num();
    else if (a === "--out") { o.out = v; i++; }
    else if (a === "--bad-rate") o.badRate = num();
    else if (a === "--replay-rate") o.replayRate = num();
    else if (a === "--stop-after-serious") o.stopAfterSerious = num();
    else if (a === "--replay") { o.replay = v; i++; }
    else if (a === "--help" || a === "-h") { console.log(readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n").slice(1, 18).join("\n")); process.exit(0); }
    else { console.error(`unknown option ${a}`); process.exit(2); }
  }
  return o;
}

function pokerPath() {
  if (process.env.POKER_BIN) return process.env.POKER_BIN;
  const exe = process.platform === "win32" ? "poker.exe" : "poker";
  return join(repoRoot, "engine", ".lake", "build", "bin", exe);
}

// ---------- small seeded random generator (for the fuzzer's own choices) ----------

function rng(seed) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), a | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    float: next,
    int: (n) => Math.floor(next() * n),           // 0 .. n-1
    range: (lo, hi) => lo + Math.floor(next() * (hi - lo + 1)), // lo .. hi, both ends
    pick: (xs) => xs[Math.floor(next() * xs.length)],
    chance: (p) => next() < p,
  };
}

// ---------- the program ----------

/** One running `poker` program. `send` writes one line and waits for one reply line. */
class Program {
  constructor(bin) {
    this.bin = bin;
    this.dead = null;
    this.child = spawn(bin, [], { stdio: ["pipe", "pipe", "pipe"] });
    this.waiting = null;
    this.stderr = "";
    this.child.stderr.on("data", (d) => { this.stderr = (this.stderr + d).slice(-4000); });
    this.child.stdin.on("error", () => {});
    createInterface({ input: this.child.stdout }).on("line", (line) => {
      const w = this.waiting; this.waiting = null;
      if (w) w.resolve(line);
    });
    this.child.on("exit", (code, signal) => {
      this.dead = `exited (code ${code}, signal ${signal})${this.stderr ? ": " + this.stderr.trim() : ""}`;
      const w = this.waiting; this.waiting = null;
      if (w) w.reject(new Error("crash: " + this.dead));
    });
    this.child.on("error", (e) => {
      this.dead = `could not start: ${e.message}`;
      const w = this.waiting; this.waiting = null;
      if (w) w.reject(new Error("crash: " + this.dead));
    });
  }

  /** Returns { line, ms }. Throws Error("crash: ...") or Error("hang: ...") on failure. */
  send(line) {
    if (this.dead) return Promise.reject(new Error("crash: " + this.dead));
    const start = process.hrtime.bigint();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.waiting = null;
        reject(new Error(`hang: no reply within ${REPLY_TIMEOUT_MS} ms`));
      }, REPLY_TIMEOUT_MS);
      this.waiting = {
        resolve: (l) => { clearTimeout(timer); resolve({ line: l, ms: Number(process.hrtime.bigint() - start) / 1e6 }); },
        reject: (e) => { clearTimeout(timer); reject(e); },
      };
      this.child.stdin.write(line + "\n");
    });
  }

  kill() { try { this.child.kill(); } catch {} }
}

// ---------- JSON helpers ----------

/** JSON with object keys sorted, so two values compare by content only. */
function canon(v) {
  if (Array.isArray(v)) return "[" + v.map(canon).join(",") + "]";
  if (v && typeof v === "object") return "{" + Object.keys(v).sort().map((k) => JSON.stringify(k) + ":" + canon(v[k])).join(",") + "}";
  return JSON.stringify(v);
}

/** The state as a rejected request (or a review, or `state`) must return it: same, but no events. */
const withoutEvents = (s) => (s ? { ...s, events: [] } : s);

// ---------- checks on one state ----------

/** Problems with one state object, as [kind, sentence] pairs. */
function checkState(s) {
  const bad = [];
  if (!s || typeof s !== "object") return [["bad-reply", "reply has no state object"]];
  const [p0, p1] = s.players ?? [];
  if (!p0 || !p1) return [["bad-reply", "state has no two players"]];
  const total = s.pot + p0.stack + p1.stack + p0.bet + p1.bet;
  if (total !== TOTAL_CHIPS) bad.push(["chips", `pot ${s.pot} + stacks ${p0.stack}/${p1.stack} + bets ${p0.bet}/${p1.bet} = ${total}, not ${TOTAL_CHIPS}`]);
  for (const n of [s.pot, p0.stack, p1.stack, p0.bet, p1.bet]) {
    if (!Number.isInteger(n) || n < 0) bad.push(["chips", `chip count ${n} is not a whole number >= 0`]);
  }
  if (!STATUSES.has(s.status)) bad.push(["status", `status is ${JSON.stringify(s.status)}`]);
  if (s.status === "playing") {
    if (s.toAct === 1) bad.push(["stuck-turn", "a playing state leaves the bot to act (bot loop ran out of fuel?)"]);
    else if (s.toAct !== 0) bad.push(["status", `playing but toAct is ${JSON.stringify(s.toAct)}`]);
    if (s.toAct === 0 && !s.legal) bad.push(["legal-options", "playing, human to act, but legal is null"]);
    if (p1.cards !== null) bad.push(["hidden-cards", "bot cards are shown while the hand is playing"]);
    if (s.result !== null) bad.push(["status", "playing but result is set"]);
  } else {
    if (s.legal !== null) bad.push(["legal-options", `${s.status} but legal is not null`]);
    if (s.toAct !== null) bad.push(["status", `${s.status} but toAct is ${s.toAct}`]);
    if (!s.result) bad.push(["status", `${s.status} but result is null`]);
    else if (!s.result.showdown && p1.cards !== null) bad.push(["hidden-cards", "bot cards are shown after a hand that ended by a fold"]);
  }
  const l = s.legal;
  if (l) {
    if (!Number.isInteger(l.call) || l.call < 0 || l.call > p0.stack) bad.push(["legal-options", `call ${l.call} is more than the human's stack ${p0.stack}`]);
    if (l.check && l.call !== 0) bad.push(["legal-options", `check is allowed but call is ${l.call}`]);
    const toCall = Math.max(0, p1.bet - p0.bet);
    if (l.check !== (toCall === 0)) bad.push(["legal-options", `check is ${l.check} but the human owes ${toCall}`]);
    if (toCall > 0 && l.call !== Math.min(toCall, p0.stack)) bad.push(["legal-options", `call is ${l.call} but the human owes ${toCall} with stack ${p0.stack}`]);
    if (l.raise) {
      const { min, max } = l.raise;
      if (!(min <= max)) bad.push(["legal-options", `raise min ${min} > max ${max}`]);
      if (max > p0.stack + p0.bet) bad.push(["legal-options", `raise max ${max} > stack ${p0.stack} + bet ${p0.bet}`]);
      if (min <= p1.bet) bad.push(["legal-options", `raise min ${min} is not above the bot's bet ${p1.bet}`]);
    }
    if (!l.fold && !l.check && !l.call && !l.raise) bad.push(["legal-options", "human to act with no legal move"]);
  }
  if (s.status === "gameOver") {
    if (!(p0.stack === TOTAL_CHIPS || p1.stack === TOTAL_CHIPS)) bad.push(["game-over", `game over but stacks are ${p0.stack}/${p1.stack}`]);
  } else if (s.status === "handOver") {
    if (p0.stack === 0 || p1.stack === 0) bad.push(["game-over", `a player has 0 chips but status is handOver`]);
  }
  if (s.result) {
    const w = s.result.winnings ?? [];
    if (w.length !== 2 || w[0] + w[1] <= 0) bad.push(["chips", `hand result pays ${JSON.stringify(w)}`]);
  }
  return bad;
}

// ---------- review checks (MVP §6) ----------

const EDGES = [0, 0.5, 2, 5];
function labelFromLost(lost) {
  if (lost <= 0) return "Best";
  if (lost < 0.5) return "Good";
  if (lost < 2) return "Inaccuracy";
  if (lost < 5) return "Mistake";
  return "Blunder";
}

/** Problems with one review, plus notes about cases near a band edge. */
function checkReview(rv, hand, expectedGraded) {
  const bad = [], notes = [];
  if (!rv || rv.hand !== hand || !Array.isArray(rv.decisions)) return { bad: [["review", `review of hand ${hand} is malformed`]], notes };
  if (!Array.isArray(rv.bot_reasons)) bad.push(["review", `review of finished hand ${hand} has bot_reasons ${JSON.stringify(rv.bot_reasons)}`]);
  let graded = 0;
  for (const d of rv.decisions) {
    if (d.label === null) {
      if (d.worth_bb !== null || d.equity_had !== null) bad.push(["review", "ungraded decision carries numbers"]);
      continue;
    }
    graded++;
    if (!LABELS.has(d.label)) { bad.push(["review-label", `label ${JSON.stringify(d.label)} is not one of the five`]); continue; }
    if (d.street !== "river" || !["call", "fold"].includes(d.your_action)) bad.push(["review", `graded a ${d.street} ${d.your_action}; only river calls and folds are graded`]);
    const { call, fold } = d.worth_bb ?? {};
    if (fold !== 0) bad.push(["review", `fold is worth ${fold}, not 0`]);
    const best = Math.max(call, fold);
    const mine = d.your_action === "call" ? call : fold;
    const lost = best - mine;
    const want = labelFromLost(lost);
    // The worths are rounded to 0.01, so `lost` may be off by up to 0.005; allow 0.01.
    const nearEdge = EDGES.some((e) => Math.abs(lost - e) <= 0.01);
    // Note real borderline cases only: a Best with nothing lost is not one.
    if (nearEdge && (lost !== 0 || want !== d.label)) notes.push({ hand, action: d.your_action, worth_bb: d.worth_bb, lost: +lost.toFixed(3), label: d.label, expected: want });
    if (want !== d.label && !nearEdge) bad.push(["review-label", `${d.your_action} lost ${lost.toFixed(2)} BB (call ${call}, fold ${fold}) but is labelled ${d.label}, not ${want}`]);
    // Calling breaks even exactly when equity had = equity needed.
    const eh = d.equity_had, en = d.equity_needed;
    if (Math.abs(call) > 0.02 && Math.abs(eh - en) > 0.002 && (call > 0) !== (eh > en)) {
      bad.push(["review-numbers", `call worth ${call} BB but equity had ${eh} vs needed ${en}`]);
    }
  }
  if (graded !== expectedGraded) bad.push(["review-graded-count", `hand ${hand}: ${graded} graded decisions, expected ${expectedGraded} (river call/fold answering the bot's opening bet)`]);
  return { bad, notes };
}

// ---------- requests ----------

const req = (o) => JSON.stringify(o);

/** A legal move for the human, picked at random among the legal buttons. `graded` says it
answers the bot's opening river bet with a call or fold. */
function legalMove(s, r) {
  const l = s.legal, me = s.players[0], botBet = s.players[1].bet;
  // The bot opened the river with a bet: the human has put nothing in this round.
  const facingOpen = s.street === "river" && me.bet === 0 && botBet > 0;
  if (facingOpen && l.fold && l.call > 0 && r.chance(0.85)) {
    return { line: req({ cmd: "act", action: r.chance(0.5) ? "call" : "fold" }), graded: true };
  }
  const opts = [];
  if (l.fold) opts.push("fold");
  if (l.check) opts.push("check");
  if (l.call > 0) opts.push("call");
  if (l.raise) opts.push("raise");
  const a = r.pick(opts);
  if (a !== "raise") return { line: req({ cmd: "act", action: a }), graded: facingOpen && (a === "call" || a === "fold") };
  const { min, max } = l.raise;
  const x = r.float();
  const amount = x < 0.15 ? min : x < 0.3 ? max : r.range(min, max);
  const word = s.currentBet === 0 ? "bet" : "raise";
  return { line: req({ cmd: "act", action: word, amount }), graded: false };
}

/** A deliberately wrong request that fits the state, or null if none fits. */
function badRequest(s, r) {
  const c = [];
  const l = s.legal;
  if (s.status === "playing" && l) {
    if (l.raise) {
      if (l.raise.min - 1 > s.players[1].bet || r.chance(0.5)) c.push(["raise below min", { cmd: "act", action: "raise", amount: l.raise.min - 1 }]);
      c.push(["raise above max", { cmd: "act", action: "raise", amount: l.raise.max + 1 + r.int(50) }]);
    } else {
      c.push(["raise when no raise is allowed", { cmd: "act", action: "raise", amount: s.players[0].stack + s.players[0].bet + 10 }]);
    }
    if (!l.check) c.push(["check facing a bet", { cmd: "act", action: "check" }]);
    if (l.check) c.push(["call with nothing to call", { cmd: "act", action: "call" }]);
    c.push(["negative amount", { cmd: "act", action: "raise", amount: -r.range(1, 100) }]);
    c.push(["decimal amount", { cmd: "act", action: "raise", amount: (l.raise ? l.raise.min : 20) + 0.5 }]);
    c.push(["string amount", { cmd: "act", action: "raise", amount: String(l.raise ? l.raise.min : 20) }]);
    c.push(["raise with no amount", { cmd: "act", action: "raise" }]);
    c.push(["unknown action", { cmd: "act", action: "allin" }]);
    c.push(["next_hand while playing", { cmd: "next_hand" }]);
  }
  if (s.status === "handOver") {
    c.push(["act after the hand is over", { cmd: "act", action: r.pick(["call", "check", "fold"]) }]);
  }
  c.push(["review of a hand not played yet", { cmd: "review", hand: s.hand + 1 + r.int(3) }]);
  c.push(["review of hand 0", { cmd: "review", hand: 0 }]);
  c.push(["unknown command", { cmd: r.pick(["bot", "deal", "undo", ""]) }]);
  c.push(["broken JSON", null]);
  c.push(["risk out of range", { cmd: "new_game", seed: "7", risk: 101 + r.int(50), bluff_pct: 20 }]);
  c.push(["bluff out of range", { cmd: "new_game", seed: "7", risk: 50, bluff_pct: 61 + r.int(40) }]);
  c.push(["negative slider", { cmd: "new_game", seed: "7", risk: -1, bluff_pct: 20 }]);
  c.push(["seed not digits", { cmd: "new_game", seed: "12x", risk: 50, bluff_pct: 20 }]);
  const [what, o] = r.pick(c);
  const line = o ? req(o) : r.pick(['{"cmd":"act","action":', "not json", '{"cmd":"state"', "[1,2", "{}"]);
  return { what, line };
}

// ---------- results ----------

class Results {
  constructor(out) {
    this.out = out;
    this.games = 0; this.requests = 0; this.hands = 0; this.restarts = 0;
    this.replays = 0; this.cappedGames = 0; this.badSent = 0;
    this.failures = []; // { kind, sentence, repro }
    this.kindCounts = {};
    this.notes = [];
    this.times = {}; // bucket -> [ms]
    this.slow = [];
    this.firstSeriousAt = null;
    this.reviewsGraded = 0;
    this.labelCounts = {};
  }
  time(bucket, ms, line) {
    (this.times[bucket] ??= []).push(ms);
    if (ms > SLOW_MS) this.slow.push({ bucket, ms: Math.round(ms), request: line });
  }
  fail(kind, sentence, game, requests) {
    this.kindCounts[kind] = (this.kindCounts[kind] ?? 0) + 1;
    // Keep at most 5 repros per kind; count the rest.
    if (this.failures.filter((f) => f.kind === kind).length >= 5) return;
    const n = this.failures.length + 1;
    const file = join(this.out, `repro-${String(n).padStart(3, "0")}-${kind}.json`);
    const repro = { kind, sentence, seed: game.seed, risk: game.risk, bluff_pct: game.bluff, requests: [...requests] };
    writeFileSync(file, JSON.stringify(repro, null, 1) + "\n");
    this.failures.push({ kind, sentence, file, seed: game.seed, risk: game.risk, bluff_pct: game.bluff, requestCount: requests.length });
    if (SERIOUS.has(kind) && this.firstSeriousAt === null) this.firstSeriousAt = Date.now();
    console.log(`FAIL [${kind}] ${sentence}  (${file})`);
  }
}

// ---------- one game ----------

/** Plays one game on `prog` (restarting it if it dies). Returns the program to keep using
and the game's request lines and reply lines. */
async function playGame(ctx, prog, gameNo) {
  const { opts, res } = ctx;
  const r = rng((opts.seed * 1_000_003 + gameNo * 7919) >>> 0);
  const seed = (BigInt(r.int(2 ** 32)) * 4294967296n + BigInt(r.int(2 ** 32))).toString();
  const risk = RISKS[gameNo % RISKS.length];
  const bluff = BLUFFS[Math.floor(gameNo / RISKS.length) % BLUFFS.length];
  const game = { seed, risk, bluff };
  const requests = [], replies = [];
  let crashed = false;
  let state = null;
  let expectedGraded = 0;

  const send = async (line, bucketOf) => {
    requests.push(line);
    res.requests++;
    try {
      const { line: out, ms } = await prog.send(line);
      replies.push(out);
      let reply;
      try { reply = JSON.parse(out); } catch { res.fail("bad-reply", `reply is not JSON: ${out.slice(0, 200)}`, game, requests); return null; }
      res.time(bucketOf(reply), ms, line);
      return reply;
    } catch (e) {
      const kind = e.message.startsWith("hang") ? "hang" : "crash";
      res.fail(kind, `${e.message} after request ${line}`, game, requests);
      prog.kill();
      prog = new Program(ctx.bin);
      res.restarts++;
      crashed = true;
      return null;
    }
  };
  const streetBucket = (s) => (rep) => rep?.state?.street ?? s;
  const checkAll = (reply) => {
    for (const [k, msg] of checkState(reply.state)) res.fail(k, msg, game, requests);
  };

  // Start.
  let reply = await send(req({ cmd: "new_game", seed, risk, bluff_pct: bluff }), () => "new_game");
  if (!reply) return { prog, requests, replies, crashed };
  if (!reply.ok) { res.fail("rejected-good", `new_game rejected: ${reply.error}`, game, requests); return { prog, requests, replies, crashed }; }
  checkAll(reply);
  state = reply.state;
  res.hands++;

  for (let steps = 0; steps < 20_000; steps++) {
    if (crashed) break;
    // About 1 request in 10 is deliberately wrong.
    if (r.chance(opts.badRate)) {
      const { what, line } = badRequest(state, r);
      res.badSent++;
      const rep = await send(line, () => "rejected");
      if (!rep) break;
      if (rep.ok) {
        res.fail(what.startsWith("review") || what.includes("out of range") || what.includes("slider") || what.includes("seed") ? "accepted-bad-request" : "accepted-illegal-move",
          `${what} was accepted: ${line}`, game, requests);
        if (rep.state && canon(withoutEvents(rep.state)) !== canon(withoutEvents(state))) {
          checkAll(rep);
          state = rep.state; // the game moved on; keep going from here
        }
        if (rep.state?.hand === 1 && line.includes("new_game")) break; // a new game began
        continue;
      }
      if (typeof rep.error !== "string") res.fail("bad-reply", `rejected request has no error text: ${line}`, game, requests);
      if (canon(rep.state) !== canon(withoutEvents(state))) {
        res.fail("rejected-changed-state", `${what} was rejected ("${rep.error}") but the returned state differs from the state before it`, game, requests);
        if (rep.state) state = rep.state;
      }
      continue;
    }
    // Now and then, ask for the state: it must not change anything.
    if (r.chance(0.03)) {
      const rep = await send(req({ cmd: "state" }), () => "state");
      if (!rep) break;
      if (!rep.ok || canon(rep.state) !== canon(withoutEvents(state))) res.fail("state-changed", `"state" returned a different state (${rep.error ?? "ok"})`, game, requests);
      continue;
    }

    if (state.status === "playing") {
      const { line, graded } = legalMove(state, r);
      const rep = await send(line, streetBucket(state.street));
      if (!rep) break;
      if (!rep.ok) { res.fail("rejected-legal-move", `legal move ${line} was rejected: ${rep.error}`, game, requests); continue; }
      if (graded) expectedGraded++;
      checkAll(rep);
      state = rep.state;
      continue;
    }

    // The hand is over (or the game is): review it.
    const handNo = state.hand;
    const rv = await send(req({ cmd: "review", hand: handNo }), () => "review");
    if (!rv) break;
    if (!rv.ok) res.fail("review", `review of finished hand ${handNo} was rejected: ${rv.error}`, game, requests);
    else {
      if (canon(rv.state) !== canon(withoutEvents(state))) res.fail("review-changed-state", "a review returned a different state", game, requests);
      const { bad, notes } = checkReview(rv.review, handNo, expectedGraded);
      for (const [k, msg] of bad) res.fail(k, msg, game, requests);
      for (const n of notes) res.notes.push({ ...n, seed, risk, bluff_pct: bluff });
      for (const d of rv.review.decisions ?? []) if (d.label) { res.reviewsGraded++; res.labelCounts[d.label] = (res.labelCounts[d.label] ?? 0) + 1; }
    }
    // Sometimes look back at an older hand: still there, still the same shape.
    if (handNo > 1 && r.chance(0.1)) {
      const old = await send(req({ cmd: "review", hand: 1 + r.int(handNo - 1) }), () => "review");
      if (!old) break;
      if (!old.ok) res.fail("review", `review of an earlier hand was rejected: ${old.error}`, game, requests);
    }
    expectedGraded = 0;

    if (state.status === "gameOver") {
      // Nothing may advance after game over.
      for (const line of [req({ cmd: "next_hand" }), req({ cmd: "act", action: "call" }), req({ cmd: "act", action: "fold" }), req({ cmd: "act", action: "raise", amount: 100 })]) {
        const rep = await send(line, () => "rejected");
        if (!rep) break;
        if (rep.ok) res.fail("advanced-after-game-over", `${line} was accepted after game over`, game, requests);
        else if (canon(rep.state) !== canon(withoutEvents(state))) res.fail("rejected-changed-state", `${line} after game over changed the state`, game, requests);
      }
      break;
    }
    if (state.hand >= MAX_HANDS_PER_GAME) { res.cappedGames++; break; }
    const rep = await send(req({ cmd: "next_hand" }), () => "next_hand");
    if (!rep) break;
    if (!rep.ok) { res.fail("rejected-good", `next_hand in handOver was rejected: ${rep.error}`, game, requests); break; }
    if (rep.state.hand !== handNo + 1) res.fail("status", `next_hand went from hand ${handNo} to ${rep.state.hand}`, game, requests);
    checkAll(rep);
    state = rep.state;
    res.hands++;
  }
  return { prog, requests, replies, crashed, game };
}

/** Replays a game's requests in a fresh program and checks every reply is the same. */
async function replayCheck(ctx, played) {
  const p = new Program(ctx.bin);
  try {
    for (let i = 0; i < played.requests.length; i++) {
      let out;
      try { out = (await p.send(played.requests[i])).line; }
      catch (e) { ctx.res.fail("replay", `replay died at request ${i + 1}: ${e.message}`, played.game, played.requests.slice(0, i + 1)); return; }
      if (out !== played.replies[i]) {
        ctx.res.fail("replay", `replay differs at request ${i + 1} of ${played.requests.length} (${played.requests[i]})`, played.game, played.requests.slice(0, i + 1));
        return;
      }
    }
    ctx.res.replays++;
  } finally { p.kill(); }
}

// ---------- the run ----------

function pct(xs, q) {
  if (!xs.length) return 0;
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.floor(q * s.length))];
}

async function fuzz(opts) {
  const bin = pokerPath();
  if (!existsSync(bin)) { console.error(`No game program at ${bin}. Build it: cd engine && lake build (or set POKER_BIN).`); process.exit(2); }
  mkdirSync(opts.out, { recursive: true });
  const res = new Results(opts.out);
  const ctx = { opts, res, bin };
  const start = Date.now();
  const deadline = start + opts.minutes * 60_000;
  let nextGame = 0;
  const timeUp = () => {
    if (Date.now() > deadline) return true;
    if (res.firstSeriousAt !== null && Date.now() > res.firstSeriousAt + opts.stopAfterSerious * 60_000) return true;
    return false;
  };
  let lastLog = Date.now();
  const worker = async () => {
    let prog = new Program(bin);
    while (!timeUp()) {
      const g = nextGame++;
      if (g >= opts.games) break;
      const played = await playGame(ctx, prog, g);
      prog = played.prog;
      res.games++;
      if (!played.crashed && played.game && rng(g * 31 + 5).chance(opts.replayRate)) await replayCheck(ctx, played);
      if (Date.now() - lastLog > 30_000) {
        lastLog = Date.now();
        console.log(`${Math.round((Date.now() - start) / 1000)}s: ${res.games} games, ${res.hands} hands, ${res.requests} requests, ${Object.values(res.kindCounts).reduce((a, b) => a + b, 0)} failures`);
      }
    }
    prog.kill();
  };
  await Promise.all(Array.from({ length: opts.workers }, worker));

  const wall = (Date.now() - start) / 1000;
  const speed = Object.fromEntries(Object.entries(res.times).map(([k, xs]) => [k, { n: xs.length, median: +pct(xs, 0.5).toFixed(1), p95: +pct(xs, 0.95).toFixed(1), max: +Math.max(...xs).toFixed(1) }]));
  const summary = {
    games: res.games, hands: res.hands, requests: res.requests, badRequestsSent: res.badSent,
    wallSeconds: Math.round(wall), workers: opts.workers, fuzzSeed: opts.seed,
    replaysMatched: res.replays, programRestarts: res.restarts, gamesStoppedAtHandCap: res.cappedGames,
    gradedDecisions: res.reviewsGraded, labelCounts: res.labelCounts,
    failureCounts: res.kindCounts, failures: res.failures,
    speedMs: speed, slowReplies: res.slow.sort((a, b) => b.ms - a.ms).slice(0, 50),
    nearBandEdge: res.notes,
  };
  writeFileSync(join(opts.out, "summary.json"), JSON.stringify(summary, null, 1) + "\n");
  console.log(JSON.stringify({ ...summary, failures: undefined, nearBandEdge: res.notes.length, slowReplies: res.slow.length }, null, 1));
  console.log(`Summary written to ${join(opts.out, "summary.json")}`);
  process.exit(Object.keys(res.kindCounts).length ? 1 : 0);
}

/** `--replay file`: send the saved requests to a fresh program, print each reply, and
recheck what can be checked one reply at a time. */
async function replay(opts) {
  const repro = JSON.parse(readFileSync(opts.replay, "utf8"));
  console.log(`Replaying ${repro.requests.length} requests (seed ${repro.seed}, risk ${repro.risk}, bluff ${repro.bluff_pct}); recorded failure: [${repro.kind}] ${repro.sentence}`);
  const p = new Program(pokerPath());
  let prev = null, problems = 0;
  for (const [i, line] of repro.requests.entries()) {
    let out, ms;
    try { ({ line: out, ms } = await p.send(line)); }
    catch (e) { console.log(`#${i + 1} ${line}\n  ${e.message}`); problems++; break; }
    const rep = JSON.parse(out);
    const found = rep.state ? checkState(rep.state) : [];
    if (!rep.ok && prev && canon(rep.state) !== canon(withoutEvents(prev))) found.push(["rejected-changed-state", "rejected, but the state changed"]);
    const last = i === repro.requests.length - 1;
    if (last || found.length) {
      console.log(`#${i + 1} (${ms.toFixed(0)} ms) ${line}\n  ${out}`);
      for (const [k, m] of found) console.log(`  -> [${k}] ${m}`);
    }
    problems += found.length;
    if (rep.ok && rep.state) prev = rep.state;
  }
  p.kill();
  console.log(problems ? `${problems} problem(s) found by the per-reply checks.` : "No per-reply check failed (game-level checks, such as review counts or replays, need the full fuzz run).");
}

const opts = parseArgs(process.argv.slice(2));
if (opts.replay) await replay(opts); else await fuzz(opts);
