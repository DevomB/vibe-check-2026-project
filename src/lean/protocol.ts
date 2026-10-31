import type { Card } from "@/engine";

/**
 * Messages between the browser and the Lean game program (`Main.lean`), passed through
 * the bridge at `/api/game`. Player 0 is the human, player 1 is the bot.
 */

export type LeanCommand =
  | { cmd: "new_game"; seed: string }
  | { cmd: "act"; action: "fold" | "check" | "call" }
  | { cmd: "act"; action: "raise"; amount: number }
  | { cmd: "bot" }
  | { cmd: "next_hand" }
  | { cmd: "state" };

export interface LeanPlayer {
  stack: number;
  /** Chips put in during the current betting round. */
  bet: number;
  /** Null while hidden: the bot's cards until a showdown. */
  cards: Card[] | null;
  folded: boolean;
  allIn: boolean;
  lastAction: string | null;
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
  seed: string;
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
  /** What happened since the previous reply. */
  events: LeanEvent[];
}

export type LeanReply = { ok: true; state: LeanState } | { error: string; state: LeanState | null };
