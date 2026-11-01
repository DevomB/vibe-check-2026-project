/**
 * Differential tests: the Lean engine against the `poker-calculations` library, pinned to
 * exactly 4.0.3 (MVP section 7). Run from the repo root:
 *
 *   cd engine && lake build difftest && cd ..
 *   cd tests && npm ci && npm run diff
 *
 * The Lean side is engine/DiffTest.lean, which answers requests using the spec's `showdown`
 * and the bot's `countsFor`. Checks:
 *   1. Hand ranking: 100,000 random deals, plus deals that favour straights, wheels and flushes.
 *      Same winner, and the same kind of best hand for each player.
 *   2. Exact equity against a known hand on the flop, turn and river: the same number.
 *   3. Exact equity against a random hand on the turn and river (`countsFor`): the same number.
 *   4. Seeded estimates within 4 standard errors: `countsFor` on the flop (1,000 deals) against
 *      the library's exact answer, and the preflop table against the library's Monte Carlo.
 *
 * The harness deals distinct cards itself (the library accepts duplicates), passes cards as
 * "Ah", and never asks the library for exact preflop equity (minutes per call).
 *
 * Writes tests/diff/cases.json (every case, except the ranking deals: their seed, count and
 * SHA-256) and tests/diff/results.json. Exits with code 1 if any check fails.
 * `--deals=N` changes the number of random ranking deals, for a quick trial run.
 */
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { type Card, fullDeck, seededRng } from "../../src/engine/cards";

const require = createRequire(import.meta.url);
const pc = require("poker-calculations") as {
  evaluateHandStrength(hole: string[], board: string[]): number;
  evaluateHandCategory(hole: string[], board: string[]): string;
  handRankCategoryOrder(category: string): number;
  exactHuEquityVsKnownHand(hero: string[], villain: string[], board: string[]): number;
  exactHuEquityVsRandomHand(hero: string[], board: string[]): number;
  simulateHandOutcomeDetailed(hole: string[], board: string[], n: number, seed: number): { estimate: number; se: number; n: number };
};
const libraryPackage = fileURLToPath(new URL("../node_modules/poker-calculations/package.json", import.meta.url));
const LIBRARY = `poker-calculations@${JSON.parse(readFileSync(libraryPackage, "utf8")).version}`;
if (LIBRARY !== "poker-calculations@4.0.3") throw new Error(`Expected poker-calculations@4.0.3, found ${LIBRARY}`);

const SEED = 20261031;
const arg = (name: string) => process.argv.find((a) => a.startsWith(`--${name}=`))?.split("=")[1];
const RANDOM_DEALS = Number(arg("deals") ?? 100_000);
/** Deals from each small pool of cards (see `EDGE_POOLS`). */
const EDGE_DEALS = 2_000;
const VERSUS_SPOTS = { flop: 30, turn: 30, river: 30 };
const RANDOM_HAND_SPOTS = { turn: 20, river: 60 };
const FLOP_ESTIMATE_SPOTS = 12;
const PREFLOP_SPOTS = 36;
const PREFLOP_LIBRARY_SAMPLES = 100_000;
/** Deals per entry in data/preflop.json. */
const PREFLOP_TABLE_SAMPLES = 50_000;
/** Deals `countsFor` uses on the flop (MVP section 5). */
const FLOP_SAMPLES = 1_000;
const MAX_ERRORS = 4;
/** Two exact answers count as equal when they differ by less than this (floating-point noise). */
const EXACT_TOLERANCE = 1e-9;

const root = fileURLToPath(new URL("../../", import.meta.url));
const leanBin = `${root}engine/.lake/build/bin/difftest${process.platform === "win32" ? ".exe" : ""}`;
if (!existsSync(leanBin)) throw new Error(`No Lean driver at ${leanBin}. Build it first: cd engine && lake build difftest`);

const rng = seededRng(SEED);

/** `n` different cards from `pool`, in random order. */
function deal(n: number, pool: readonly Card[] = fullDeck()): Card[] {
  const deck = pool.slice();
  for (let k = 0; k < n; k++) {
    const j = k + Math.floor(rng() * (deck.length - k));
    [deck[k], deck[j]] = [deck[j]!, deck[k]!];
  }
  return deck.slice(0, n);
}

/** Ask the Lean driver; one answer per request, in order. */
function lean(requests: string[]): string[] {
  const out = spawnSync(leanBin, { input: requests.join("\n") + "\n", maxBuffer: 1 << 28, encoding: "utf8" });
  if (out.status !== 0) throw new Error(`Lean driver failed: ${out.stderr}`);
  const lines = out.stdout.split(/\r?\n/).filter((l) => l !== "");
  if (lines.length !== requests.length) throw new Error(`Lean driver gave ${lines.length} answers for ${requests.length} requests`);
  return lines;
}

const join = (cards: readonly string[]) => cards.join(" ");
const sha256 = (lines: string[]) => createHash("sha256").update(lines.join("\n")).digest("hex");
/** Win chance with ties counting half, from Lean's "wins ties losses" answer. */
function leanCounts(answer: string) {
  const [win, tie, loss] = answer.split(" ").map(Number) as [number, number, number];
  const n = win + tie + loss;
  return { win, tie, loss, n, equity: (win + tie / 2) / n };
}

interface Check {
  name: string;
  cases: number;
  failures: unknown[];
}
const checks: Check[] = [];
const cases: Record<string, unknown> = {};
function record(name: string, total: number, failures: unknown[]) {
  checks.push({ name, cases: total, failures });
  console.log(`${failures.length === 0 ? "PASS" : "FAIL"}  ${name}: ${total - failures.length}/${total}`);
}

// 1. Hand ranking.
const EDGE_POOLS: Record<string, Card[]> = {
  // Ace to six: wheels (A-2-3-4-5), six-high straights and many pairs.
  lowRanks: fullDeck().filter((c) => "A23456".includes(c[0]!)),
  // Ten to ace: broadway straights, royal flushes, full houses and four of a kind.
  highRanks: fullDeck().filter((c) => "TJQKA".includes(c[0]!)),
  // All 13 hearts and the 2s to 4s of other suits: flushes, straight flushes, flush against flush.
  hearts: fullDeck().filter((c) => c[1] === "h" || "234".includes(c[0]!)),
};
function rankCheck(name: string, deals: Card[][]) {
  const requests = deals.map((d) => `rank ${join(d.slice(0, 2))} | ${join(d.slice(2, 4))} | ${join(d.slice(4))}`);
  const answers = lean(requests);
  const kind = (hole: string[], board: string[]) => Math.min(8, pc.handRankCategoryOrder(pc.evaluateHandCategory(hole, board)));
  const failures: unknown[] = [];
  deals.forEach((d, i) => {
    const [h0, h1, board] = [d.slice(0, 2), d.slice(2, 4), d.slice(4)];
    const s0 = pc.evaluateHandStrength(h0, board);
    const s1 = pc.evaluateHandStrength(h1, board);
    const library = `${s0 > s1 ? "0" : s0 < s1 ? "1" : "tie"} ${kind(h0, board)} ${kind(h1, board)}`;
    if (answers[i] !== library) failures.push({ request: requests[i], lean: answers[i], library });
  });
  cases[name] = { seed: SEED, deals: deals.length, sha256: sha256(requests), first: requests.slice(0, 10) };
  record(name, deals.length, failures);
}
rankCheck("ranking: random deals", Array.from({ length: RANDOM_DEALS }, () => deal(9)));
for (const [pool, cards] of Object.entries(EDGE_POOLS)) {
  rankCheck(`ranking: deals from ${pool}`, Array.from({ length: EDGE_DEALS }, () => deal(9, cards)));
}

// 2. Exact equity against a known hand.
for (const [street, spots] of Object.entries(VERSUS_SPOTS)) {
  const boardSize = { flop: 3, turn: 4, river: 5 }[street]!;
  const deals = Array.from({ length: spots }, () => deal(4 + boardSize));
  const requests = deals.map((d) => `vs ${join(d.slice(0, 2))} | ${join(d.slice(2, 4))} | ${join(d.slice(4))}`);
  const answers = lean(requests);
  const rows = deals.map((d, i) => {
    const library = pc.exactHuEquityVsKnownHand(d.slice(0, 2), d.slice(2, 4), d.slice(4));
    return { request: requests[i], lean: answers[i], leanEquity: leanCounts(answers[i]!).equity, library };
  });
  cases[`exact vs known hand: ${street}`] = rows;
  record(`exact vs known hand: ${street}`, spots, rows.filter((r) => !(Math.abs(r.leanEquity - r.library) < EXACT_TOLERANCE)));
}

// 3 and 4. countsFor against a random hand: exact on the turn and river, estimates on the flop and preflop.
const countsRequest = (seed: number, d: Card[]) => `counts ${seed} | ${join(d.slice(0, 2))} | ${join(d.slice(2))}`;
const expectedTotal: Record<number, number> = { 4: 45_540, 5: 990 };
for (const [street, spots] of Object.entries(RANDOM_HAND_SPOTS)) {
  const boardSize = { turn: 4, river: 5 }[street]!;
  const deals = Array.from({ length: spots }, () => deal(2 + boardSize));
  const requests = deals.map((d, i) => countsRequest(SEED + i, d));
  const answers = lean(requests);
  const rows = deals.map((d, i) => {
    const library = pc.exactHuEquityVsRandomHand(d.slice(0, 2), d.slice(2));
    const k = leanCounts(answers[i]!);
    return { request: requests[i], lean: answers[i], leanEquity: k.equity, library, n: k.n };
  });
  cases[`exact vs random hand: ${street}`] = rows;
  const bad = rows.filter((r) => r.n !== expectedTotal[boardSize] || !(Math.abs(r.leanEquity - r.library) < EXACT_TOLERANCE));
  record(`exact vs random hand (countsFor): ${street}, ${expectedTotal[boardSize]} outcomes`, spots, bad);
}

{
  const deals = Array.from({ length: FLOP_ESTIMATE_SPOTS }, () => deal(5));
  const requests = deals.map((d, i) => countsRequest(SEED + i, d));
  const answers = lean(requests);
  const rows = deals.map((d, i) => {
    const library = pc.exactHuEquityVsRandomHand(d.slice(0, 2), d.slice(2));
    const k = leanCounts(answers[i]!);
    // Each deal scores 1, 1/2 or 0, so its variance is at most p(1 - p).
    const se = Math.sqrt((library * (1 - library)) / FLOP_SAMPLES);
    return { request: requests[i], lean: answers[i], leanEquity: k.equity, library, n: k.n, errors: se > 0 ? Math.abs(k.equity - library) / se : k.equity === library ? 0 : Infinity };
  });
  cases["estimate vs exact: flop"] = rows;
  record(`estimate vs exact (countsFor): flop, ${FLOP_SAMPLES} deals, within ${MAX_ERRORS} SE`, rows.length, rows.filter((r) => r.n !== FLOP_SAMPLES || !(r.errors <= MAX_ERRORS)));
}

{
  const deals = Array.from({ length: PREFLOP_SPOTS }, () => deal(2));
  const requests = deals.map((d, i) => countsRequest(SEED + i, d));
  const answers = lean(requests);
  const rows = deals.map((d, i) => {
    const mc = pc.simulateHandOutcomeDetailed(d, [], PREFLOP_LIBRARY_SAMPLES, SEED + i);
    const k = leanCounts(answers[i]!);
    const se = Math.sqrt((mc.estimate * (1 - mc.estimate)) / PREFLOP_TABLE_SAMPLES + mc.se ** 2);
    return { request: requests[i], lean: answers[i], leanEquity: k.equity, library: mc.estimate, librarySe: mc.se, n: k.n, errors: Math.abs(k.equity - mc.estimate) / se };
  });
  cases["estimate vs estimate: preflop"] = rows;
  record(
    `estimate vs estimate (countsFor): preflop table against ${PREFLOP_LIBRARY_SAMPLES} library deals, within ${MAX_ERRORS} SE`,
    rows.length,
    rows.filter((r) => r.n !== PREFLOP_TABLE_SAMPLES || !(r.errors <= MAX_ERRORS)),
  );
}

const failed = checks.filter((c) => c.failures.length > 0);
const results = {
  library: LIBRARY,
  seed: SEED,
  ranOn: new Date().toISOString().slice(0, 10),
  platform: `${process.platform} ${process.arch}, Node ${process.version}`,
  passed: failed.length === 0,
  checks: checks.map((c) => ({ name: c.name, cases: c.cases, failed: c.failures.length, firstFailures: c.failures.slice(0, 20) })),
};
writeFileSync(fileURLToPath(new URL("cases.json", import.meta.url)), JSON.stringify(cases, null, 1) + "\n");
writeFileSync(fileURLToPath(new URL("results.json", import.meta.url)), JSON.stringify(results, null, 1) + "\n");
console.log(failed.length === 0 ? `All ${checks.length} checks passed.` : `${failed.length} of ${checks.length} checks failed.`);
process.exit(failed.length === 0 ? 0 : 1);
