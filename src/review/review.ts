import { type Card, isCard } from "../engine/cards";
import { evaluate } from "../engine/evaluator";
import { type RankedHand, riverBettingSet } from "./riverStrategy";

/**
 * Game review of river decisions (MVP section 6). It grades one kind of decision: the human
 * calls or folds after the bot opens the river with a bet. Raises are not graded.
 *
 * What the bot can hold: any hand in its river betting set (riverStrategy.ts) that does not
 * use one of the human's cards, each equally likely. This ignores the earlier betting, so it
 * only approximates what the bot really holds.
 */

/** An exact fraction num / den, with den above 0. */
export interface Fraction {
  num: number;
  den: number;
}

export type RiverChoice = "call" | "fold";

/** Review labels, best first. */
export const REVIEW_LABELS = ["Best", "Good", "Inaccuracy", "Mistake", "Blunder"] as const;
export type ReviewLabel = (typeof REVIEW_LABELS)[number];

/** What the human knew when the bot opened the river with a bet. It has no field for the bot's cards, on purpose. */
export interface RiverSpot {
  /** The five board cards. */
  board: readonly Card[];
  /** The human's two cards. */
  hole: readonly Card[];
  /** All chips in the pot, including the bot's bet. */
  pot: number;
  /** Chips the human must add to call, before any limit from the human's stack. */
  toCall: number;
  /** The human's chips not yet in the pot. */
  stack: number;
  bigBlind: number;
  /** The bot's Bluff setting, from 0 to 60. */
  bluffPct: number;
}

export interface RiverVerdict {
  choice: RiverChoice;
  label: ReviewLabel;
  /** The average result of each choice, from this decision on, in big blinds. Folding is always 0. */
  worthBb: { call: Fraction; fold: Fraction };
  /** Big blinds lost by `choice` compared to the better of call and fold. 0 means the choice was Best. */
  lostBb: Fraction;
  /** Share of the bot's possible hands the human beats, ties counting half. */
  equityHad: Fraction;
  /** The share needed for a call to break even: cost / (pot + cost). */
  equityNeeded: Fraction;
  /** How many of the bot's possible hands the human beats, ties and loses to. */
  counts: { wins: number; ties: number; losses: number };
}

/** A fraction as a decimal, for display only. */
export function toNumber(f: Fraction): number {
  return f.num / f.den;
}

/**
 * The chips at stake in a call: `cost` is what the human pays and `pot` is what the human can
 * win, including the bot's bet. If the human cannot cover the whole bet, the part of the bet
 * they cannot match goes back to the bot, so it is not in `pot`.
 */
export function callStakes(spot: Pick<RiverSpot, "pot" | "toCall" | "stack">): { pot: number; cost: number } {
  const cost = Math.min(spot.toCall, spot.stack);
  return { pot: spot.pot - (spot.toCall - cost), cost };
}

/** The hands the bot can hold: its river betting set, minus the hands that use one of the human's cards. */
export function botRiverRange(spot: Pick<RiverSpot, "board" | "hole" | "bluffPct">): RankedHand[] {
  const { value, bluffs } = riverBettingSet(spot.board, spot.bluffPct);
  return [...value, ...bluffs].filter((h) => !h.cards.some((c) => spot.hole.includes(c)));
}

/**
 * The label for losing `lostBb` big blinds: Best = 0, Good = less than 0.5, Inaccuracy = 0.5 to
 * less than 2, Mistake = 2 to less than 5, Blunder = 5 or more. Uses the exact amount, before any rounding.
 */
export function labelFor(lostBb: Fraction): ReviewLabel {
  const { num, den } = lostBb;
  if (num < 0 || den <= 0) throw new Error(`Big blinds lost must be 0 or more, got ${num}/${den}`);
  if (num === 0) return "Best";
  if (2 * num < den) return "Good";
  if (num < 2 * den) return "Inaccuracy";
  if (num < 5 * den) return "Mistake";
  return "Blunder";
}

/**
 * Grades a call or fold against the bot's opening river bet. The result depends only on what
 * the human could see and on the bot's rules, never on the cards the bot really holds.
 */
export function reviewRiverDecision(spot: RiverSpot, choice: RiverChoice): RiverVerdict {
  checkSpot(spot);
  const { pot, cost } = callStakes(spot);
  const range = botRiverRange(spot);
  // The bot's real hand is always in this list, so it is empty only for a decision the review should not grade.
  if (range.length === 0) throw new Error("No hand in the bot's betting set fits these cards");

  const mine = evaluate([...spot.hole, ...spot.board]).score;
  let wins = 0;
  let ties = 0;
  for (const hand of range) {
    if (mine > hand.score) wins++;
    else if (mine === hand.score) ties++;
  }
  const losses = range.length - wins - ties;

  // Calling wins `pot`, loses `cost`, or on a tie gets half of pot + cost back: (pot - cost) / 2.
  // The numerator is twice the chips summed over the bot's hands, so it stays a whole number.
  const den = 2 * range.length * spot.bigBlind;
  const call = { num: 2 * wins * pot + ties * (pot - cost) - 2 * losses * cost, den };
  const lostBb = { num: Math.max(call.num, 0) - (choice === "call" ? call.num : 0), den };
  return {
    choice,
    label: labelFor(lostBb),
    worthBb: { call, fold: { num: 0, den } },
    lostBb,
    equityHad: { num: 2 * wins + ties, den: 2 * range.length },
    equityNeeded: { num: cost, den: pot + cost },
    counts: { wins, ties, losses },
  };
}

function checkSpot(spot: RiverSpot): void {
  const cards = [...spot.board, ...spot.hole];
  if (spot.board.length !== 5 || spot.hole.length !== 2 || !cards.every(isCard) || new Set(cards).size !== 7) {
    throw new Error("A river spot needs five board cards and two hole cards, all different");
  }
  const chips = { pot: spot.pot, toCall: spot.toCall, stack: spot.stack, bigBlind: spot.bigBlind };
  for (const [name, value] of Object.entries(chips)) {
    if (!Number.isInteger(value) || value <= 0) throw new Error(`${name} must be a whole number above 0, got ${value}`);
  }
  if (spot.toCall > spot.pot) throw new Error("The pot must include the bot's bet");
}
