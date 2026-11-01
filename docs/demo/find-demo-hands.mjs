#!/usr/bin/env node
/**
 * Finds and re-checks the demo hands (docs/DEMO.md) and the practice-challenge spots
 * (docs/demo/challenges.json).
 *
 * It drives the compiled Lean game program over JSON lines (MVP §13). There is no server and
 * nothing to install: the human's moves are scripted, and Lean plays the bot.
 *
 *   node docs/demo/find-demo-hands.mjs            search seeds and print what it finds
 *   node docs/demo/find-demo-hands.mjs --write    search, then write challenges.json and scenes.json
 *   node docs/demo/find-demo-hands.mjs --check    replay the recorded spots and scenes; exit 1 on a mismatch
 *
 * Options: --seeds N (search seeds 1..N, default 60). POKER_BIN picks the program; the
 * default is engine/.lake/build/bin/poker (poker.exe on Windows) under the current folder.
 *
 * Every spot is in hand 1 of a new game. Each spot is the human's call or fold after the bot
 * opens the river with a bet: Lean grades it with the bot's river betting set ("model":
 * "river-set", the proved grade, MVP §6). Lean also grades other calls and folds facing a bet
 * ("model": "any-hand", not proved); this script ignores those. Each spot is checked by
 * replaying the same seed and moves twice, once ending in a call and once in a fold.
 */
import { spawn, execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CHALLENGES = path.join(HERE, "challenges.json");
const SCENES = path.join(HERE, "scenes.json");
const START_STACK = 500;
const REPLY_TIMEOUT_MS = 60_000;
const LABELS = ["Best", "Good", "Inaccuracy", "Mistake", "Blunder"];

function binaryPath() {
  const name = process.platform === "win32" ? "poker.exe" : "poker";
  return process.env.POKER_BIN ?? path.join(process.cwd(), "engine", ".lake", "build", "bin", name);
}

/** Which program produced the results: its hash, build time and the checkout it was built in. */
function engineIdentity(bin) {
  const sha256 = createHash("sha256").update(readFileSync(bin)).digest("hex");
  const git = (...args) => {
    try {
      return execFileSync("git", args, { cwd: path.dirname(bin), encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    } catch {
      return null;
    }
  };
  const top = git("rev-parse", "--show-toplevel");
  const dirty = top === null ? null : git("-C", top, "status", "--porcelain", "--", "engine") !== "";
  return { sha256, built: statSync(bin).mtime.toISOString(), checkout_commit: top && git("-C", top, "rev-parse", "HEAD"), engine_files_changed_in_checkout: dirty };
}

/** The Lean game program, one request line in and one reply line out. */
class Engine {
  constructor(bin) {
    this.child = spawn(bin, [], { stdio: ["pipe", "pipe", "inherit"] });
    this.waiting = [];
    const lines = createInterface({ input: this.child.stdout });
    lines.on("line", (line) => {
      const w = this.waiting.shift();
      if (!w) return;
      clearTimeout(w.timer);
      w.resolve(JSON.parse(line));
    });
    lines.on("close", () => {
      for (const w of this.waiting.splice(0)) w.reject(new Error("the Lean program stopped"));
    });
  }

  send(command) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`no reply within ${REPLY_TIMEOUT_MS / 1000} s to ${JSON.stringify(command)}`));
        this.child.kill();
      }, REPLY_TIMEOUT_MS);
      this.waiting.push({ resolve, reject, timer });
      this.child.stdin.write(`${JSON.stringify(command)}\n`);
    });
  }

  /** Send a command that must be accepted. */
  async ok(command) {
    const reply = await this.send(command);
    if (!reply.ok) throw new Error(`${JSON.stringify(command)} was rejected: ${reply.error}`);
    return reply;
  }

  close() {
    this.child.stdin.end();
  }
}

/** Is the human facing the bot's opening river bet? The human has put nothing in on the river. */
function facingRiverBet(s) {
  return s.status === "playing" && s.toAct === 0 && s.board.length === 5 && s.legal.call > 0 && s.players[0].bet === 0;
}

/**
 * Is this the proved grade of a call or fold against the bot's opening river bet? Lean marks it
 * "model": "river-set". An engine from before "model" existed graded only that decision, on
 * the river.
 */
function isRiverSetGrade(d) {
  if (d.label === null) return false;
  return d.model === undefined ? d.street === "river" : d.model === "river-set";
}

/** Scripted human lines: each gives the human's move in a state before the river decision. */
const LINES = {
  /** Call the small blind, then check, or call any bet. */
  passive: (s) => (s.legal.check ? { action: "check" } : { action: "call" }),
  /** Raise to 30 from the small blind, then play passively. */
  raise30: (s) =>
    s.street === "preflop" && s.players[0].bet === 5 && s.legal.raise && s.legal.raise.min <= 30
      ? { action: "raise", amount: 30 }
      : LINES.passive(s),
};

function newGame(seed, risk) {
  return { cmd: "new_game", seed: String(seed), risk };
}

/** Play hand 1 by `line` until the human faces the bot's opening river bet or the hand ends. */
async function playToRiver(engine, seed, risk, line) {
  let reply = await engine.ok(newGame(seed, risk));
  const moves = [];
  for (let i = 0; i < 20; i++) {
    const s = reply.state;
    if (s.status !== "playing") return null;
    if (facingRiverBet(s)) return { moves, state: s };
    const move = line(s);
    moves.push(move);
    reply = await engine.ok({ cmd: "act", ...move });
  }
  return null;
}

/** The bot's role in its last move, from its reason ("a bluff, picked at ..." or "a value hand"). */
function roleOf(reason) {
  if (/a bluff, picked at Bluff/.test(reason)) return "bluff";
  if (/a value hand/.test(reason)) return "value";
  return "other";
}

/**
 * Start a new game, send `moves`, check the human now faces the bot's opening river bet,
 * answer with `final`, and read the review of hand 1.
 */
async function replay(engine, spot, final) {
  let reply = await engine.ok(newGame(spot.seed, spot.risk));
  for (const move of spot.moves) reply = await engine.ok({ cmd: "act", ...move });
  const before = reply.state;
  if (!facingRiverBet(before)) throw new Error(`seed ${spot.seed}: the moves do not reach the bot's opening river bet`);
  const after = (await engine.ok({ cmd: "act", action: final })).state;
  const review = (await engine.ok({ cmd: "review", hand: 1 })).review;
  const graded = review.decisions.filter(isRiverSetGrade);
  if (graded.length !== 1 || graded[0].your_action !== final || graded[0].street !== "river") {
    throw new Error(`seed ${spot.seed}: expected one river-set grade of the river ${final}, got ${JSON.stringify(review.decisions)}`);
  }
  const reasons = after.botReasons ?? [];
  return {
    before,
    after,
    decision: graded[0],
    allDecisions: review.decisions,
    riverReason: reasons[reasons.length - 1] ?? null,
    result: {
      action: final,
      outcome: after.result.outcome,
      showdown: after.result.showdown,
      human_net_chips: after.players[0].stack - START_STACK,
      human_cards: after.players[0].cards,
      bot_cards: after.players[1].cards,
      board: after.board,
    },
  };
}

/** Replay a spot ending in a call and ending in a fold, and check both saw the same decision. */
async function gradeBoth(engine, spot) {
  const call = await replay(engine, spot, "call");
  const fold = await replay(engine, spot, "fold");
  const same = JSON.stringify(call.before) === JSON.stringify(fold.before);
  if (!same) throw new Error(`seed ${spot.seed}: the call and fold replays reached different river states`);
  if (JSON.stringify(call.decision.worth_bb) !== JSON.stringify(fold.decision.worth_bb)) {
    throw new Error(`seed ${spot.seed}: call and fold reviews disagree on worth_bb`);
  }
  const s = call.before;
  return {
    seed: String(spot.seed),
    risk: spot.risk,
    moves: spot.moves,
    labels: { call: call.decision.label, fold: fold.decision.label },
    worth_bb: call.decision.worth_bb,
    equity_had: call.decision.equity_had,
    equity_needed: call.decision.equity_needed,
    river: {
      board: s.board,
      human_cards: s.players[0].cards,
      human_hand: s.players[0].handName,
      pot_before_bet: s.pot + s.players[0].bet,
      bot_bet: s.players[1].bet,
      to_call: s.legal.call,
    },
    bot_river_reason: call.riverReason,
    bot_role: roleOf(call.riverReason ?? ""),
    results: { call: call.result, fold: fold.result },
    review_if_call: call.allDecisions,
  };
}

const rank = (label) => LABELS.indexOf(label);

/**
 * The human is at the river decision: call in this game and read the review. The fold label
 * is only guessed here from the rounded worth of calling (MVP §6 bands); `gradeBoth` replays
 * the fold for real before a spot is kept.
 */
async function quickLook(engine) {
  const after = (await engine.ok({ cmd: "act", action: "call" })).state;
  const d = (await engine.ok({ cmd: "review", hand: 1 })).review.decisions.find(isRiverSetGrade);
  const worth = d.worth_bb.call;
  const foldGuess = worth <= 0 ? "Best" : worth < 0.5 ? "Good" : worth < 2 ? "Inaccuracy" : worth < 5 ? "Mistake" : "Blunder";
  const reasons = after.botReasons ?? [];
  return {
    labels: { call: d.label, fold: foldGuess },
    worth_bb: d.worth_bb,
    equity_had: d.equity_had,
    bot_role: roleOf(reasons[reasons.length - 1] ?? ""),
    results: { call: { outcome: after.result.outcome } },
  };
}

/** The three practice spots (job 5) and what each needs. */
const CHALLENGE_KINDS = [
  {
    id: "catch-bluff",
    title: "Catch a bluff",
    best: "call",
    // The bot bets a designated bluff hand; calling is Best and clearly better than folding,
    // and the call wins at showdown.
    fits: (g) => g.bot_role === "bluff" && g.labels.call === "Best" && rank(g.labels.fold) >= rank("Inaccuracy") && g.results.call.outcome === "player0",
  },
  {
    id: "avoid-bad-call",
    title: "Avoid a bad call",
    best: "fold",
    // Calling is Mistake or Blunder. The human had some equity, and the call would really lose.
    fits: (g) => rank(g.labels.call) >= rank("Mistake") && g.labels.fold === "Best" && g.equity_had >= 0.1 && g.results.call.outcome === "player1",
  },
  {
    id: "right-and-lose",
    title: "Make the right decision and still lose",
    best: "call",
    // Calling is Best and worth at least half a big blind more than folding (so folding is
    // Inaccuracy or worse), yet the call loses at the actual showdown.
    fits: (g) => g.labels.call === "Best" && rank(g.labels.fold) >= rank("Inaccuracy") && g.worth_bb.call >= 0.5 && g.results.call.outcome === "player1",
  },
];

/** Risk values tried for the river spots, in order. Risk 100 (Vex, the most bluffs) is scene (c). */
const RIVER_RISKS = [100, 50, 0];

function asChallenge(kind, g, identity) {
  return {
    id: kind.id,
    title: kind.title,
    seed: g.seed,
    risk: g.risk,
    moves: g.moves,
    best: kind.best,
    labels: g.labels,
    worth_bb: g.worth_bb,
    result_if_best: g.results[kind.best],
    equity_had: g.equity_had,
    equity_needed: g.equity_needed,
    river: g.river,
    bot_river_reason: g.bot_river_reason,
    result_if_other: g.results[kind.best === "call" ? "fold" : "call"],
    verified: { engine: identity, checked_at: new Date().toISOString(), replayed: "call and fold, each from new_game with the same seed and moves" },
  };
}

/** Scene (b): at Risk 0 (Ivy), the bot folds to a raise to `amount` preflop; at Risk 100 (Vex) it calls. */
async function sceneB(engine, seed, amount) {
  const move = { action: "raise", amount };
  await engine.ok(newGame(seed, 0));
  const low = (await engine.ok({ cmd: "act", ...move })).state;
  const folded = low.status === "handOver" && low.result.outcome === "fold" && low.players[1].folded;
  if (!folded) return null;
  await engine.ok(newGame(seed, 100));
  const high = (await engine.ok({ cmd: "act", ...move })).state;
  const botCalled = high.events.some((e) => e.type === "action" && e.player === 1 && e.action === "call");
  const reason = low.botReasons[0];
  const chance = Number(/win chance (\d+)%/.exec(reason)?.[1] ?? 0);
  return {
    id: "b",
    title: "Risk 0: the bot folds to a big bet",
    seed: String(seed),
    risk: 0,
    moves: [move],
    human_cards: low.players[0].cards,
    bot_reason: reason,
    bot_win_chance_percent: chance,
    human_net_chips: low.players[0].stack - START_STACK,
    same_seed_at_risk_100: { bot_called: botCalled, events: high.events.filter((e) => e.type === "action") },
  };
}

async function search(engine, maxSeeds, identity) {
  const found = new Map();
  let sceneC = null;
  let attempts = 0;
  for (let seed = 1; seed <= maxSeeds; seed++) {
    const missing = CHALLENGE_KINDS.filter((k) => !found.has(k.id));
    if (missing.length === 0 && sceneC) break;
    for (const risk of RIVER_RISKS) {
      for (const [lineName, line] of Object.entries(LINES)) {
        attempts++;
        const reached = await playToRiver(engine, seed, risk, line);
        if (!reached) continue;
        const tag = `seed ${seed} ${lineName} risk ${risk}`;
        // First a cheap look: call in this game. Only a likely fit gets the full call and fold replays.
        const look = await quickLook(engine);
        console.error(`${tag}: call ${look.labels.call}, worth ${look.worth_bb.call} bb, bot ${look.bot_role}, call ends ${look.results.call.outcome}`);
        const wantC = !sceneC && risk === 100 && look.bot_role === "bluff";
        if (!wantC && !CHALLENGE_KINDS.some((k) => !found.has(k.id) && k.fits(look))) continue;
        const g = await gradeBoth(engine, { seed, risk, moves: reached.moves });
        console.error(`  replayed: call ${g.labels.call}, fold ${g.labels.fold}`);
        for (const kind of CHALLENGE_KINDS) {
          if (!found.has(kind.id) && kind.fits(g)) {
            found.set(kind.id, asChallenge(kind, g, identity));
            console.error(`  -> ${kind.id}`);
          }
        }
        if (!sceneC && risk === 100 && g.bot_role === "bluff") sceneC = g;
      }
    }
  }
  // Scene (b): a short preflop search; it needs only the preflop table, so it is fast.
  let sceneBFound = null;
  for (let seed = 1; seed <= maxSeeds && !sceneBFound; seed++) {
    const b = await sceneB(engine, seed, 150);
    if (b && b.same_seed_at_risk_100.bot_called && b.bot_win_chance_percent >= 50) sceneBFound = b;
  }
  console.error(`${attempts} river attempts over seeds 1..${maxSeeds}`);
  return { challenges: CHALLENGE_KINDS.map((k) => found.get(k.id)).filter(Boolean), sceneB: sceneBFound, sceneC };
}

/** Compare a fresh replay with what was recorded; return a list of differences. */
function differences(recorded, fresh, keys) {
  return keys.filter((k) => JSON.stringify(recorded[k]) !== JSON.stringify(fresh[k])).map((k) => `${k}: recorded ${JSON.stringify(recorded[k])}, now ${JSON.stringify(fresh[k])}`);
}

async function check(engine) {
  let failures = 0;
  const report = (name, diffs) => {
    if (diffs.length === 0) console.log(`PASS ${name}`);
    else {
      failures++;
      console.log(`FAIL ${name}\n  ${diffs.join("\n  ")}`);
    }
  };
  const challenges = JSON.parse(readFileSync(CHALLENGES, "utf8"));
  for (const c of challenges) {
    const g = await gradeBoth(engine, c);
    const fresh = { ...g, result_if_best: g.results[c.best], result_if_other: g.results[c.best === "call" ? "fold" : "call"] };
    report(`challenge ${c.id}`, differences(c, fresh, ["labels", "worth_bb", "equity_had", "equity_needed", "river", "bot_river_reason", "result_if_best", "result_if_other"]));
  }
  if (existsSync(SCENES)) {
    const scenes = JSON.parse(readFileSync(SCENES, "utf8"));
    for (const sc of scenes) {
      if (sc.id === "b") {
        const b = await sceneB(engine, sc.seed, sc.moves[0].amount);
        report("scene b", b ? differences(sc, b, ["bot_reason", "human_net_chips", "same_seed_at_risk_100"]) : ["the bot no longer folds"]);
      } else {
        const g = await gradeBoth(engine, sc);
        report(`scene ${sc.id}`, differences(sc, g, ["labels", "worth_bb", "equity_had", "equity_needed", "river", "bot_river_reason", "results"]));
      }
    }
  }
  return failures;
}

async function main() {
  const args = process.argv.slice(2);
  const seedsAt = args.indexOf("--seeds");
  const maxSeeds = seedsAt >= 0 ? Number(args[seedsAt + 1]) : 60;
  const bin = binaryPath();
  if (!existsSync(bin)) throw new Error(`Lean game program not found at ${bin}; set POKER_BIN`);
  const identity = engineIdentity(bin);
  console.error(`engine ${bin}\n  ${JSON.stringify(identity)}`);
  const engine = new Engine(bin);
  try {
    if (args.includes("--check")) {
      const failures = await check(engine);
      process.exitCode = failures === 0 ? 0 : 1;
      return;
    }
    const { challenges, sceneB: b, sceneC: c } = await search(engine, maxSeeds, identity);
    const avoid = challenges.find((x) => x.id === "avoid-bad-call");
    const scenes = [
      avoid && { id: "a", title: "Review scene: a bad river call", ...pick(avoid) },
      b,
      c && { id: "c", title: "Risk 100: the bot bets a designated bluff on the river", ...c },
    ].filter(Boolean);
    console.log(JSON.stringify({ engine: identity, challenges, scenes }, null, 2));
    if (args.includes("--write")) {
      writeFileSync(CHALLENGES, `${JSON.stringify(challenges, null, 2)}\n`);
      writeFileSync(SCENES, `${JSON.stringify(scenes, null, 2)}\n`);
      console.error(`wrote ${challenges.length} challenges and ${scenes.length} scenes`);
    }
    if (challenges.length < CHALLENGE_KINDS.length || !b || !c) {
      console.error("not every spot was found; raise --seeds");
      process.exitCode = 1;
    }
  } finally {
    engine.close();
  }
}

/** The fields of a challenge that a river scene shares. */
function pick(c) {
  const { seed, risk, moves, labels, worth_bb, equity_had, equity_needed, river, bot_river_reason } = c;
  const byChoice = (choice) => (choice === c.best ? c.result_if_best : c.result_if_other);
  return { seed, risk, moves, labels, worth_bb, equity_had, equity_needed, river, bot_river_reason, results: { call: byChoice("call"), fold: byChoice("fold") } };
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exitCode = 1;
});
