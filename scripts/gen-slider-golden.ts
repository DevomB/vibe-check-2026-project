/**
 * Builds engine/Engine/SliderGolden.lean: spots where the TypeScript bot (`decideWithCounts` in
 * src/ai/slider/decide.ts) has decided, so the Lean port can be checked against it move for move.
 * Run from the repo root:
 *
 *   npx --yes tsx@4.20.6 scripts/gen-slider-golden.ts
 *
 * The Lean file is generated. Never edit it by hand; run this again. The same SEED always gives
 * the same file.
 *
 * Each spot is a Lean betting `State` (stacks, pot, bets, last raise, whose turn). The TypeScript
 * bot sees it through the real `sliderView` and `legalActions` of src/engine/game.ts, so the pot,
 * the amount to call and the legal raise sizes come from the reference code, not from this script.
 * Spots where the river betting set decides (river, no bet to face) go in a second list.
 */
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { type Card, fullDeck, seededRng } from "../src/engine/cards";
import type { Action, HandState } from "../src/engine/game";
import { type Counts } from "../src/ai/slider/counts";
import { type SliderDecision, decideWithCounts, riverOpeningFromSet } from "../src/ai/slider/decide";
import { sliderView } from "../src/ai/slider/fromHand";

const SEED = 20261031;
const RANDOM_CASES = 200;
const RIVER_OPENING_CASES = 40;
const COMMAND = "npx --yes tsx@4.20.6 scripts/gen-slider-golden.ts";
const leanPath = fileURLToPath(new URL("../engine/Engine/SliderGolden.lean", import.meta.url));

/** All chips on the table, as in a real game: two stacks of 500. */
const TABLE_CHIPS = 1000;
/** Outcomes counted on each street: preflop table, flop samples, exact turn, exact river. */
const COUNT_TOTAL: Record<number, number> = { 0: 50000, 3: 1000, 4: 45540, 5: 990 };

/** A spot in the Lean engine's terms. Player `toAct` is the bot. */
interface Spot {
  risk: number;
  bluffPct: number;
  counts: Counts;
  hole: Card[];
  board: Card[];
  stack: [number, number];
  pot: number;
  bet: [number, number];
  lastRaise: number;
  toAct: 0 | 1;
}

const rng = seededRng(SEED);
const int = (lo: number, hi: number) => lo + Math.floor(rng() * (hi - lo + 1));
const pick = <T>(xs: readonly T[]) => xs[int(0, xs.length - 1)]!;

function deal(boardSize: number): { hole: Card[]; board: Card[] } {
  const deck = fullDeck();
  for (let k = 0; k < 2 + boardSize; k++) {
    const j = int(k, deck.length - 1);
    [deck[k], deck[j]] = [deck[j]!, deck[k]!];
  }
  return { hole: deck.slice(0, 2), board: deck.slice(2, 2 + boardSize) };
}

/** The Lean spec's minimum raise: the last raise, but never less than the big blind (10). */
const minRaise = (lastRaise: number) => Math.max(lastRaise, 10);

/** The TypeScript hand state for a spot. Only the fields `sliderView` and `legalActions` read. */
function handState(s: Spot): HandState {
  const half = s.pot / 2;
  const player = (i: 0 | 1) => ({
    id: `p${i}`,
    name: `p${i}`,
    stack: s.stack[i],
    hole: i === s.toAct ? s.hole : [],
    streetBet: s.bet[i],
    totalBet: half + s.bet[i],
    folded: false,
    allIn: s.stack[i] === 0,
    hasActed: false,
    // Heads-up, a short all-in only matters when the other player is all-in, and then nobody
    // can raise anyway. So this flag never changes the legal moves here.
    mayRaise: true,
  });
  return {
    players: [player(0), player(1)],
    board: s.board,
    toAct: s.toAct,
    currentBet: Math.max(s.bet[0], s.bet[1]),
    minRaise: minRaise(s.lastRaise),
  } as unknown as HandState;
}

function decide(s: Spot): SliderDecision {
  const view = sliderView(handState(s), s.toAct, { risk: s.risk, bluffPct: s.bluffPct }, SEED);
  return decideWithCounts(view, s.counts, { riverOpening: riverOpeningFromSet });
}

function randomCounts(boardSize: number): Counts {
  const n = COUNT_TOTAL[boardSize]!;
  const win = int(0, n);
  const tie = int(0, Math.floor((n - win) / 8));
  return { win, tie, loss: n - win - tie };
}

/** A random spot where the bot may act. The pot is even, so each player's share of it is whole. */
function randomSpot(): Spot {
  for (;;) {
    const boardSize = pick([0, 3, 4, 5]);
    const toAct = pick([0, 1] as const);
    const pot = boardSize === 0 ? 0 : 2 * int(1, 150);
    const myBet = pick([0, 0, 5, 10, int(0, 200)]);
    const facing = rng() < 0.65;
    const theirBet = facing ? myBet + pick([5, 10, int(1, 60), int(1, 400)]) : myBet;
    const rest = TABLE_CHIPS - pot - myBet - theirBet;
    if (rest < 1) continue;
    // Sometimes the bot is short, so the call is capped at its stack; sometimes the opponent is all-in.
    const myStack = rng() < 0.2 ? int(1, Math.min(rest, 60)) : rng() < 0.15 ? rest : int(1, rest);
    const bet: [number, number] = toAct === 0 ? [myBet, theirBet] : [theirBet, myBet];
    const stack: [number, number] = toAct === 0 ? [myStack, rest - myStack] : [rest - myStack, myStack];
    const lastRaise = pick([0, 10, 10, Math.max(10, theirBet - myBet), int(10, 300)]);
    return { risk: int(0, 100), bluffPct: int(0, 60), counts: randomCounts(boardSize), ...deal(boardSize), stack, pot, bet, lastRaise, toAct };
  }
}

/** Hand-picked spots on the edges of each rule. */
function edgeSpots(): Spot[] {
  const base = (boardSize: number): Spot => ({
    risk: 50,
    bluffPct: 20,
    counts: { win: 1, tie: 0, loss: 1 },
    ...deal(boardSize),
    stack: [400, 400],
    pot: 100,
    bet: [0, 50],
    lastRaise: 50,
    toAct: 0,
  });
  const spots: Spot[] = [];
  for (const boardSize of [0, 3, 4, 5]) {
    // Win chance exactly 75% facing a bet: raise. Just under (74.95%): call or fold.
    spots.push({ ...base(boardSize), counts: { win: 3, tie: 0, loss: 1 } });
    spots.push({ ...base(boardSize), counts: { win: 749, tie: 1, loss: 250 } });
    // Calling 50 to win 150 with 1 win in 4: exactly break-even at Risk 0 (call), a fold at Risk 1.
    for (const risk of [0, 1, 100]) spots.push({ ...base(boardSize), risk, counts: { win: 1, tie: 0, loss: 3 } });
    // Ties count half: 2 ties in 2 is a 50% win chance.
    spots.push({ ...base(boardSize), counts: { win: 0, tie: 2, loss: 0 } });
    // A strong hand against an all-in opponent: no raise is legal, so call.
    spots.push({ ...base(boardSize), counts: { win: 9, tie: 0, loss: 1 }, stack: [750, 0] });
    // A strong hand with a short stack: the raise is capped at all-in.
    spots.push({ ...base(boardSize), counts: { win: 9, tie: 0, loss: 1 }, stack: [70, 730] });
    // The bot cannot cover the bet: the call is capped at its stack.
    spots.push({ ...base(boardSize), counts: { win: 1, tie: 0, loss: 1 }, stack: [30, 770] });
    // A huge last raise: the pot-sized raise is pushed up to the minimum raise.
    spots.push({ ...base(boardSize), counts: { win: 9, tie: 0, loss: 1 }, lastRaise: 600 });
    if (boardSize === 5) continue;
    // No bet to face: exactly 65% bets the pot, just under checks.
    spots.push({ ...base(boardSize), bet: [0, 0], counts: { win: 13, tie: 0, loss: 7 } });
    spots.push({ ...base(boardSize), bet: [0, 0], counts: { win: 1299, tie: 1, loss: 700 } });
    // Big blind's option before the flop: the bot already has 10 in, so a bet is a raise.
    spots.push({ ...base(boardSize), pot: 0, bet: [10, 10], counts: { win: 9, tie: 0, loss: 1 } });
  }
  return spots;
}

const actionText = (a: Action) => (a.type === "raise" ? `raise ${a.to}` : a.type);

function leanCase(s: Spot): string {
  const d = decide(s);
  const fields = [
    s.risk, s.bluffPct, s.counts.win, s.counts.tie, s.counts.loss,
    JSON.stringify(s.hole.join(" ")), JSON.stringify(s.board.join(" ")),
    s.stack[0], s.stack[1], s.pot, s.bet[0], s.bet[1], s.lastRaise, s.toAct,
    JSON.stringify(actionText(d.action)), JSON.stringify(d.reason),
  ];
  return `  ⟨${fields.join(", ")}⟩`;
}

const isRiverOpening = (s: Spot) => decide(s).rule === "river-opening";

const edges = edgeSpots();
const mainCases = edges.filter((s) => !isRiverOpening(s));
const riverCases = edges.filter(isRiverOpening);
let randomCases = 0;
while (randomCases < RANDOM_CASES || riverCases.length < RIVER_OPENING_CASES) {
  const s = randomSpot();
  if (isRiverOpening(s)) {
    if (riverCases.length < RIVER_OPENING_CASES) riverCases.push(s);
  } else if (randomCases < RANDOM_CASES) {
    mainCases.push(s);
    randomCases++;
  }
}

const lean = `-- Generated by scripts/gen-slider-golden.ts from the TypeScript bot. Do not edit by hand.
-- To rebuild, run from the repo root: ${COMMAND}

/-!
# Golden cases for the slider bot (generated)

Spots where the TypeScript reference \`decideWithCounts\` (\`src/ai/slider/decide.ts\`) has
decided, with seed ${SEED}. \`Engine/SliderTests.lean\` checks that the Lean bot makes the
same move in every one.
-/

/-- A spot for the bot, and the move the TypeScript bot makes there. Player \`toAct\` is the bot. -/
structure GoldenCase where
  risk : Nat
  bluffPct : Nat
  win : Nat
  tie : Nat
  loss : Nat
  /-- The bot's two cards, as text: \`"Ah Kd"\`. -/
  hole : String
  /-- The board: 0, 3, 4 or 5 cards, as text. -/
  board : String
  stack0 : Nat
  stack1 : Nat
  pot : Nat
  bet0 : Nat
  bet1 : Nat
  lastRaise : Nat
  toAct : Nat
  /-- The TypeScript move: \`"fold"\`, \`"check"\`, \`"call"\` or \`"raise 120"\` (a street total). -/
  expected : String
  /-- The TypeScript reason, word for word. -/
  reason : String
  deriving Inhabited

/-- ${mainCases.length} spots decided by the win-chance and Risk rules: hand-picked edge cases first, then random ones. -/
def goldenCases : List GoldenCase := [
${mainCases.map(leanCase).join(",\n")}
]

/-- ${riverCases.length} river spots with no bet to face, decided by the river betting set
(\`riverOpeningFromSet\`). These need the real \`riverBets\` from \`Engine/River.lean\`. -/
def goldenRiverOpeningCases : List GoldenCase := [
${riverCases.map(leanCase).join(",\n")}
]
`;

writeFileSync(leanPath, lean);
const tally = (spots: Spot[]) =>
  Object.entries(spots.reduce<Record<string, number>>((acc, s) => ((acc[decide(s).rule] = (acc[decide(s).rule] ?? 0) + 1), acc), {}))
    .map(([k, v]) => `${k} ${v}`)
    .join(", ");
console.log(`Wrote ${leanPath}: ${mainCases.length} cases (${tally(mainCases)}), ${riverCases.length} river-opening cases (${tally(riverCases)})`);
