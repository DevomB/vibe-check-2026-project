import type { Card } from "../../engine/cards";
import type { Action } from "../../engine/game";
import { type Counts, FLOP_SAMPLES, checkCards, equityAtLeast, equityPercent, riverCounts, sampledCounts, total, turnCounts } from "./counts";
import { preflopCounts } from "./preflopTable";

/** Facing a bet, the bot raises when its win chance (ties counting half) is at least this, in percent. */
export const RAISE_AT_PERCENT = 75;
/** With no bet to face, preflop to turn, the bot bets the pot when its win chance is at least this. */
export const BET_AT_PERCENT = 65;

/** The two sliders. Risk is 0 to 100; Bluff is a percentage from 0 to 60. */
export interface Sliders {
  risk: number;
  bluffPct: number;
}

/** Everything the bot looks at when it decides (MVP §5). It never sees the opponent's cards. */
export interface SliderView extends Sliders {
  hole: readonly Card[];
  /** 0, 3, 4 or 5 cards. */
  board: readonly Card[];
  /**
   * P: the chips the bot can win if it calls or checks now. Chips from earlier streets plus both
   * players' bets on this street, leaving out any part of the opponent's bet the bot cannot match.
   */
  pot: number;
  /** C: chips the bot must add to call, or 0 when it faces no bet. Its whole stack if it cannot cover the bet. */
  toCall: number;
  /** Chips the bot has already put in on this street. */
  streetBet: number;
  /** Legal bet or raise amounts, as street totals, or null if the bot may not bet or raise. */
  raise: { min: number; max: number } | null;
  /** Seed for the flop's random deals. The same view always gives the same decision. */
  seed: number;
}

/** Which rule picked the bot's action. */
export type SliderRule = "raise" | "call" | "fold" | "bet" | "check" | "river-opening";

export interface SliderDecision {
  action: Action;
  rule: SliderRule;
  /** The win/tie/loss counts the decision used. */
  counts: Counts;
  /** One plain sentence explaining the action, to show after the hand. */
  reason: string;
}

export interface SliderOptions {
  /**
   * The bot's move on the river when it faces no bet. MVP §5 picks it from the Bluff slider's
   * river betting set, which this module does not build. Without this option the bot checks there.
   */
  riverOpening?: (view: SliderView) => Action;
}

/** The counts for the bot's hand: preflop table, 1,000 seeded deals on the flop, exact on the turn and river. */
export function countsFor(view: SliderView): Counts {
  switch (view.board.length) {
    case 0:
      return preflopCounts(view.hole);
    case 3:
      return sampledCounts(view.hole, view.board, FLOP_SAMPLES, view.seed);
    case 4:
      return turnCounts(view.hole, view.board);
    case 5:
      return riverCounts(view.hole, view.board);
    default:
      throw new Error(`Expected a board of 0, 3, 4 or 5 cards, got ${view.board.length}`);
  }
}

/**
 * Is calling C chips to win a pot of P worth it at this Risk? A call wins P, loses C, or on a
 * split gains (P - C) / 2. Each lost chip counts (1 + Risk / 50) times as much as a won chip.
 * The bot calls when the total over all counted outcomes is zero or more. Times 200, in whole numbers:
 *
 *   100 × (2 × win × P + tie × (P - C))  ≥  2 × (100 + 2 × Risk) × loss × C
 *
 * At Risk 0 this is plain chip profit. A higher Risk only makes the right side bigger, so it can
 * turn a call into a fold but never a fold into a call.
 */
export function callPays(counts: Counts, pot: number, toCall: number, risk: number): boolean {
  return 100 * (2 * counts.win * pot + counts.tie * (pot - toCall)) >= 2 * (100 + 2 * risk) * counts.loss * toCall;
}

/** A pot-sized raise, as a street total: the bot's chips in so far, plus the call, plus the pot after calling. */
export function potRaiseTarget(view: SliderView): number {
  return view.streetBet + view.toCall + (view.pot + view.toCall);
}

/** A pot-sized bet, as a street total: the bot's chips in so far plus the pot. */
export function potBetTarget(view: SliderView): number {
  return view.streetBet + view.pot;
}

/** The bot's action, computing its counts first. */
export function decideSlider(view: SliderView, options: SliderOptions = {}): SliderDecision {
  checkView(view);
  return decideWithCounts(view, countsFor(view), options);
}

/**
 * The bot's action for given counts (MVP §5, preflop to turn, and the river when facing a bet):
 * - Facing a bet: raise pot-sized if the win chance is at least 75% and a raise is legal;
 *   otherwise call if `callPays` at the bot's Risk; otherwise fold.
 * - No bet to face: bet pot-sized if the win chance is at least 65% and a bet is legal; otherwise check.
 *   On the river, `options.riverOpening` decides instead.
 * Bet and raise sizes are kept inside the legal amounts.
 */
export function decideWithCounts(view: SliderView, counts: Counts, options: SliderOptions = {}): SliderDecision {
  checkView(view);
  checkCounts(counts);
  const chance = `win chance ${equityPercent(counts)}%` + (view.board.length === 3 ? ` (estimated from ${FLOP_SAMPLES} deals)` : "");
  const decision = (action: Action, rule: SliderRule, reason: string) => ({ action, rule, counts, reason });

  if (view.toCall > 0) {
    if (view.raise && equityAtLeast(counts, RAISE_AT_PERCENT)) {
      const to = clamp(potRaiseTarget(view), view.raise);
      return decision({ type: "raise", to }, "raise", `Raise to ${to}: ${chance} is at least ${RAISE_AT_PERCENT}%.`);
    }
    const odds = `calling ${view.toCall} to win ${view.pot} at Risk ${view.risk}, with ${chance}`;
    if (callPays(counts, view.pot, view.toCall, view.risk)) return decision({ type: "call" }, "call", `Call: worth ${odds}.`);
    return decision({ type: "fold" }, "fold", `Fold: not worth ${odds}.`);
  }

  if (view.board.length === 5) {
    if (options.riverOpening) return decision(options.riverOpening(view), "river-opening", "River move from the river betting set.");
    return decision({ type: "check" }, "river-opening", "Check: river bets are not built yet.");
  }

  if (view.raise && equityAtLeast(counts, BET_AT_PERCENT)) {
    const to = clamp(potBetTarget(view), view.raise);
    const verb = view.streetBet > 0 ? `Raise to ${to}` : `Bet ${to}`;
    return decision({ type: "raise", to }, "bet", `${verb}: ${chance} is at least ${BET_AT_PERCENT}%.`);
  }
  return decision({ type: "check" }, "check", `Check: ${chance} is under ${BET_AT_PERCENT}%.`);
}

function clamp(target: number, bounds: { min: number; max: number }): number {
  return Math.min(bounds.max, Math.max(bounds.min, target));
}

const isChips = (n: number) => Number.isSafeInteger(n) && n >= 0;

function checkView(view: SliderView) {
  checkCards(view.hole, view.board, view.board.length);
  if (![view.pot, view.toCall, view.streetBet].every(isChips)) throw new Error("pot, toCall and streetBet must be whole numbers of chips");
  if (view.pot < view.toCall) throw new Error("The pot must include the bet being called");
  if (view.raise && !(isChips(view.raise.min) && isChips(view.raise.max) && view.raise.min <= view.raise.max)) {
    throw new Error("raise must have whole-number bounds with min <= max");
  }
  if (!Number.isInteger(view.risk) || view.risk < 0 || view.risk > 100) throw new Error("Risk must be a whole number from 0 to 100");
  if (!Number.isInteger(view.bluffPct) || view.bluffPct < 0 || view.bluffPct > 60) throw new Error("Bluff must be a whole number from 0 to 60");
  if (!Number.isSafeInteger(view.seed)) throw new Error("seed must be a whole number");
}

function checkCounts(counts: Counts) {
  if (![counts.win, counts.tie, counts.loss].every(isChips) || total(counts) === 0) {
    throw new Error("counts must be whole numbers, not all zero");
  }
}
