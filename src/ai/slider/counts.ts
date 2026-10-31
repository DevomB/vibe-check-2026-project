import { type Card, fullDeck, isCard, seededRng } from "../../engine/cards";
import { evaluate } from "../../engine/evaluator";

/**
 * How many of the opponent's possible outcomes the bot's hand wins, ties and loses.
 * The bot uses the counts, not a decimal win chance, so all its math is in whole numbers.
 */
export interface Counts {
  win: number;
  tie: number;
  loss: number;
}

/** Random deals counted on the flop (MVP §5). */
export const FLOP_SAMPLES = 1000;

/**
 * How the turn is counted: "exact" visits every (opponent hand, river card) pair, 45,540 in all.
 * Chosen from a benchmark: about 0.4 s per decision in Node 22 (Oct 31, 2026), which fits inside
 * the bot's think time and needs no seed. Fixed, so replays do not depend on machine speed.
 */
export const TURN_MODE = "exact";

/** Win chance with ties counting half, in percent, rounded. For display only; decisions use `equityAtLeast`. */
export function equityPercent(c: Counts): number {
  return Math.round((100 * (2 * c.win + c.tie)) / (2 * total(c)));
}

/** True when the win chance (ties counting half) is at least `percent`%. Exact, in whole numbers. */
export function equityAtLeast(c: Counts, percent: number): boolean {
  return 100 * (2 * c.win + c.tie) >= 2 * percent * total(c);
}

export function total(c: Counts): number {
  return c.win + c.tie + c.loss;
}

/** River: every opponent hand from the 45 unseen cards, each once (990 hands). */
export function riverCounts(hole: readonly Card[], board: readonly Card[]): Counts {
  checkCards(hole, board, 5);
  const unseen = unseenCards(hole, board);
  const mine = evaluate([...hole, ...board]).score;
  const counts = { win: 0, tie: 0, loss: 0 };
  for (let i = 0; i < unseen.length; i++) {
    for (let j = i + 1; j < unseen.length; j++) {
      addResult(counts, mine, evaluate([unseen[i]!, unseen[j]!, ...board]).score);
    }
  }
  return counts;
}

/** Turn: every river card, and with it every opponent hand from the cards left (46 × 990 = 45,540 outcomes). */
export function turnCounts(hole: readonly Card[], board: readonly Card[]): Counts {
  checkCards(hole, board, 4);
  const unseen = unseenCards(hole, board);
  const counts = { win: 0, tie: 0, loss: 0 };
  for (let r = 0; r < unseen.length; r++) {
    const fullBoard = [...board, unseen[r]!];
    const mine = evaluate([...hole, ...fullBoard]).score;
    for (let i = 0; i < unseen.length; i++) {
      if (i === r) continue;
      for (let j = i + 1; j < unseen.length; j++) {
        if (j === r) continue;
        addResult(counts, mine, evaluate([unseen[i]!, unseen[j]!, ...fullBoard]).score);
      }
    }
  }
  return counts;
}

/**
 * An estimate from `samples` random deals of the opponent's hand and the rest of the board.
 * Used on the flop and to build the preflop table. The same seed always gives the same counts.
 *
 * Each deal shuffles a fresh copy of the unseen cards (in deck order) just far enough to take
 * the opponent's two cards, then the missing board cards: position k swaps with a position from
 * k to the end, picked by `seededRng(seed)`.
 */
export function sampledCounts(hole: readonly Card[], board: readonly Card[], samples: number, seed: number): Counts {
  checkCards(hole, board, board.length);
  if (!Number.isSafeInteger(samples) || samples <= 0) throw new Error("samples must be a positive whole number");
  if (!Number.isSafeInteger(seed)) throw new Error("seed must be a whole number");
  const rng = seededRng(seed);
  const unseen = unseenCards(hole, board);
  const draws = 2 + (5 - board.length);
  const counts = { win: 0, tie: 0, loss: 0 };
  for (let s = 0; s < samples; s++) {
    const deck = unseen.slice();
    for (let k = 0; k < draws; k++) {
      const j = k + Math.floor(rng() * (deck.length - k));
      [deck[k], deck[j]] = [deck[j]!, deck[k]!];
    }
    const fullBoard = [...board, ...deck.slice(2, draws)];
    const mine = evaluate([...hole, ...fullBoard]).score;
    addResult(counts, mine, evaluate([deck[0]!, deck[1]!, ...fullBoard]).score);
  }
  return counts;
}

function addResult(counts: Counts, mine: number, theirs: number) {
  if (mine > theirs) counts.win++;
  else if (mine === theirs) counts.tie++;
  else counts.loss++;
}

/** The cards in neither the bot's hand nor the board, in deck order. */
function unseenCards(hole: readonly Card[], board: readonly Card[]): Card[] {
  const known = new Set<Card>([...hole, ...board]);
  return fullDeck().filter((c) => !known.has(c));
}

/** Two hole cards, a board of `boardSize` cards (0, 3, 4 or 5), all valid and different. */
export function checkCards(hole: readonly Card[], board: readonly Card[], boardSize: number) {
  if (hole.length !== 2) throw new Error("Expected two hole cards");
  if (![0, 3, 4, 5].includes(board.length) || board.length !== boardSize) {
    throw new Error(`Expected a board of ${boardSize} cards, got ${board.length}`);
  }
  const cards = [...hole, ...board];
  if (!cards.every(isCard) || new Set(cards).size !== cards.length) throw new Error("Cards must be valid and all different");
}
