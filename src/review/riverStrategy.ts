import { type Card, SUITS, fullDeck, isCard, rankOf, suitOf } from "../engine/cards";
import { evaluate } from "../engine/evaluator";

/**
 * The bot's river betting set (MVP section 5). When the bot faces no bet on the river, it
 * bets with a fixed set of hands chosen from the board alone: the strongest 30% for value,
 * plus some of the weakest hands as bluffs, as many as the Bluff slider asks for. The game
 * review uses this same set as the list of hands the bot can hold when it bets.
 */

/** Share of the candidate hands the bot bets for value, in percent. */
const VALUE_PCT = 30;
/** Highest Bluff slider setting, in percent. */
export const MAX_BLUFF_PCT = 60;

/** Two hole cards, the card with the lower ID first. */
export type HoleCards = readonly [Card, Card];

export interface RankedHand {
  readonly cards: HoleCards;
  /** Showdown score with the board. Higher wins; equal scores split the pot. */
  readonly score: number;
}

export interface RiverBettingSet {
  /** The strongest hands, strongest first. */
  value: RankedHand[];
  /** The weakest hands not used for value, strongest first. */
  bluffs: RankedHand[];
}

/** What the bot does with its hand on the river when it faces no bet. */
export type RiverRole = "value" | "bluff" | "check";

/** Card ID from 0 to 51: by rank 2..A, then by suit c, d, h, s. "2c" is 0, "2d" is 1, "3c" is 4, "As" is 51. */
export function cardId(card: Card): number {
  return (rankOf(card) - 2) * SUITS.length + SUITS.indexOf(suitOf(card));
}

/** Every two-card hand the bot could hold on this board: each pair of cards not on the board, once. */
export function riverCandidates(board: readonly Card[]): HoleCards[] {
  checkBoard(board);
  const onBoard = new Set(board);
  const rest = fullDeck()
    .filter((c) => !onBoard.has(c))
    .sort((a, b) => cardId(a) - cardId(b));
  const hands: HoleCards[] = [];
  for (let i = 0; i < rest.length; i++) {
    for (let j = i + 1; j < rest.length; j++) hands.push([rest[i]!, rest[j]!]);
  }
  return hands;
}

/** The last board ranked. The bot and the review often rank the same board several times in a row. */
let lastRanking: { key: string; hands: readonly RankedHand[] } | null = null;

/**
 * The candidate hands from strongest to weakest showdown score. Hands with equal scores are
 * ordered by card IDs, lowest first: compare the lower cards, then the higher cards. This
 * order only chooses the betting set; equal scores still split the pot at showdown.
 */
export function rankRiverHands(board: readonly Card[]): RankedHand[] {
  const key = board.join(" ");
  if (lastRanking?.key !== key) {
    const hands = riverCandidates(board)
      .map((cards) => ({ cards, score: evaluate([...cards, ...board]).score }))
      .sort((a, b) => b.score - a.score || cardId(a.cards[0]) - cardId(b.cards[0]) || cardId(a.cards[1]) - cardId(b.cards[1]));
    lastRanking = { key, hands };
  }
  return lastRanking.hands.slice();
}

/** Number of value hands among `candidates` hands: 30%, rounded down. */
export function valueCount(candidates: number): number {
  return Math.floor((VALUE_PCT * candidates) / 100);
}

/**
 * Number of bluff hands to go with `values` value hands at Bluff `bluffPct`:
 * values × b / (100 − b), rounded to the nearest whole hand, halves up.
 * With that many, bluffs are b% of the betting set, to the nearest whole hand.
 */
export function bluffCount(values: number, bluffPct: number): number {
  checkBluffPct(bluffPct);
  return Math.floor((2 * values * bluffPct + (100 - bluffPct)) / (2 * (100 - bluffPct)));
}

/**
 * The hands the bot bets with on the river when it faces no bet. It depends only on the
 * board and the Bluff setting, never on the human's cards. Value and bluff hands never overlap.
 */
export function riverBettingSet(board: readonly Card[], bluffPct: number): RiverBettingSet {
  const ranked = rankRiverHands(board);
  const values = valueCount(ranked.length);
  const bluffs = bluffCount(values, bluffPct);
  // Cannot happen on a river (1,081 candidates, at most 324 + 486 bet), but keep the sets apart regardless.
  if (values + bluffs > ranked.length) throw new Error("Not enough hands for the value and bluff sets");
  return { value: ranked.slice(0, values), bluffs: ranked.slice(ranked.length - bluffs) };
}

/** Whether the bot bets `hole` for value, bets it as a bluff, or checks, on the river with no bet to face. */
export function riverRole(board: readonly Card[], bluffPct: number, hole: readonly Card[]): RiverRole {
  if (hole.length !== 2 || hole[0] === hole[1] || hole.some((c) => !isCard(c) || board.includes(c))) {
    throw new Error("Hole cards must be two different cards that are not on the board");
  }
  const { value, bluffs } = riverBettingSet(board, bluffPct);
  const isHole = (h: RankedHand) => h.cards.every((c) => hole.includes(c));
  if (value.some(isHole)) return "value";
  if (bluffs.some(isHole)) return "bluff";
  return "check";
}

function checkBoard(board: readonly Card[]): void {
  if (board.length !== 5 || !board.every(isCard) || new Set(board).size !== 5) {
    throw new Error("A river board needs five different cards");
  }
}

function checkBluffPct(bluffPct: number): void {
  if (!Number.isInteger(bluffPct) || bluffPct < 0 || bluffPct > MAX_BLUFF_PCT) {
    throw new Error(`Bluff must be a whole number from 0 to ${MAX_BLUFF_PCT}, got ${bluffPct}`);
  }
}
