import type { Card } from "@/engine";

/**
 * Messages between the browser and the Lean game program (`Main.lean`), passed through
 * the bridge at `/api/game`. Player 0 is the human, player 1 is the bot. Lean plays the
 * bot's moves itself: every reply is a state where the human is to act or the hand is over.
 */

/** The bot's two settings. Risk is 0-100, Bluff is a whole percentage, 0-60. */
export const RISK_MAX = 100;
export const BLUFF_PCT_MAX = 60;

export type LeanCommand =
  /** At the HTTP boundary, an empty seed requests a private server-generated game. */
  | { cmd: "new_game"; seed: string; risk: number; bluff_pct: number }
  | { cmd: "act"; action: "fold" | "check" | "call" }
  /** A bet or raise to `amount` chips this round. Lean treats "bet" and "raise" the same. */
  | { cmd: "act"; action: "bet" | "raise"; amount: number }
  | { cmd: "next_hand" }
  | { cmd: "state" }
  | { cmd: "review"; hand: number };

export interface LeanPlayer {
  stack: number;
  /** Chips put in during the current betting round. */
  bet: number;
  /** Null while hidden: the bot's cards until a showdown. */
  cards: Card[] | null;
  folded: boolean;
  allIn: boolean;
  /** A short, generic note of the last move, like "bet 60". */
  lastAction: string | null;
  /**
   * The kind of this player's best five-card hand, like "Two Pair" or "Flush". For
   * the human, once the board has 3 or more cards; for the bot, only when its cards are
   * shown at a showdown. Otherwise null.
   */
  handName: string | null;
  /** The five cards making that hand; null exactly when handName is. */
  bestCards: Card[] | null;
}

export interface LeanLegal {
  fold: boolean;
  check: boolean;
  /** Chips needed to call; 0 when there is nothing to call. */
  call: number;
  /** Allowed totals for this round's bet, or null when raising is not allowed. */
  raise: { min: number; max: number } | null;
}

export type LeanEvent =
  | { type: "blind"; player: number; amount: number; kind: "small" | "big" }
  | { type: "action"; player: number; action: "fold" | "check" | "call" | "raise"; amount: number; allIn: boolean; to?: number }
  | { type: "street"; street: "flop" | "turn" | "river"; cards: Card[] }
  | { type: "win"; player: number; amount: number };

export interface LeanState {
  hand: number;
  /** Public HTTP replies reveal the seed only once the whole game is over. */
  seed: string | null;
  street: "preflop" | "flop" | "turn" | "river" | "showdown";
  button: number;
  toAct: number | null;
  board: Card[];
  /** Chips collected from earlier betting rounds. */
  pot: number;
  currentBet: number;
  minRaise: number;
  status: "playing" | "handOver" | "gameOver";
  players: [LeanPlayer, LeanPlayer];
  /** The human's moves; null when it is not the human's turn. */
  legal: LeanLegal | null;
  result: { showdown: boolean; outcome: "player0" | "player1" | "tie" | "fold"; winnings: [number, number] } | null;
  /** What happened since the previous reply, in order, including each bot move. */
  events: LeanEvent[];
  /** The bot's settings for this game. */
  sliders: { risk: number; bluffPct: number };
  /** The bot's reason for each of its moves this hand. Null until the hand is over. */
  botReasons: string[] | null;
}

/** The labels of a graded decision, best first. */
export type ReviewLabel = "Best" | "Good" | "Inaccuracy" | "Mistake" | "Blunder";

/**
 * One of the human's moves in a hand (MVP §13). Only a call or fold facing the bot's
 * opening river bet is graded; for every other move the label and numbers are null,
 * and the screen shows "not graded yet".
 */
export interface ReviewDecision {
  street: "preflop" | "flop" | "turn" | "river";
  your_action: "fold" | "check" | "call" | "bet" | "raise";
  label: ReviewLabel | null;
  /** What calling and folding were each worth from this point, in big blinds. */
  worth_bb: { call: number; fold: number } | null;
  /** The human's chance to win against the bot's possible hands, 0 to 1. */
  equity_had: number | null;
  /** The chance needed for a call to break even, 0 to 1. */
  equity_needed: number | null;
}

export interface LeanReview {
  hand: number;
  decisions: ReviewDecision[];
}

export type LeanReply =
  | { ok: true; state: LeanState; review?: LeanReview }
  | { error: string; state: LeanState | null };

/**
 * A reply from `/api/game`: Lean's reply, plus what the bridge adds.
 * `lost` is true when the game is gone: the program stopped, did not answer, or restarted
 * without it. The screen must then offer only a new game. A malformed request is turned away
 * (HTTP 400) without `lost`, and the game goes on.
 */
export type ApiReply = LeanReply & { lost?: true };
