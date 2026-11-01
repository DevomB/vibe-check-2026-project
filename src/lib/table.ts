import type { LeanLegal } from "@/lean/protocol";
import type { Card } from "./cards";

/**
 * The shapes the table components draw. `useGame` builds them from Lean's replies; nothing
 * here decides a rule. (The TypeScript prototype in src/engine is only a test reference.)
 */

/** One player in the current hand. */
export interface PlayerState {
  id: string;
  name: string;
  /** Chips not yet in the pot. */
  stack: number;
  /** The player's two cards; empty while they are hidden. */
  hole: Card[];
  /** Chips put in on the current street. */
  streetBet: number;
  /** Chips put in during the whole hand. */
  totalBet: number;
  folded: boolean;
  allIn: boolean;
  /** Short label of the player's latest move, for display ("bet 60"). */
  lastAction: string | null;
}

/** Who won a finished hand, from Lean's result. */
export interface HandResult {
  /** True if both players reached the end and showed their cards. */
  showdown: boolean;
  pots: { amount: number; eligible: number[]; winners: number[] }[];
  /** Chips won by each player (0 for the loser). */
  winnings: number[];
}

/** The current hand. */
export interface HandState {
  players: PlayerState[];
  button: number;
  board: Card[];
  street: "preflop" | "flop" | "turn" | "river" | "showdown";
  /** Player whose turn it is; null once the hand is over. */
  toAct: number | null;
  /** Highest street bet that the other player must match. */
  currentBet: number;
  minRaise: number;
  result: HandResult | null;
}

/** The table across hands. */
export interface Session {
  seats: { id: string; name: string; stack: number }[];
  button: number;
  handNumber: number;
  config: { smallBlind: number; bigBlind: number };
}

export interface DealtHand {
  hand: HandState;
  /** `seatOf[i]` is the table seat of hand player i. */
  seatOf: number[];
}

/** A move the human picks. `to` is the player's total bet for the street. */
export type Action = { type: "fold" } | { type: "check" } | { type: "call" } | { type: "raise"; to: number };

/** The human's legal moves, exactly as Lean sends them. */
export type LegalActions = LeanLegal;

/** Every chip bet this hand, for sizing the bet presets; 0 once the hand is over. */
export function potTotal(hand: HandState): number {
  return hand.result ? 0 : hand.players.reduce((sum, p) => sum + p.totalBet, 0);
}
