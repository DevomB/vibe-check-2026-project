import type { Card } from "@/lib/cards";

/**
 * Messages between the browser and the Lean game program (`Main.lean`), passed through
 * the bridge at `/api/game`. Player 0 is the human, player 1 is the bot. Lean plays the
 * bot's moves itself: every reply is a state where the human is to act or the hand is over.
 */

/**
 * The bot's one setting, Risk: its appetite for risk, a whole number 0-100. 0 is a "Rock",
 * 50 is the ideal, 100 is a "Maniac". Lean derives everything else from it (see `sliders`).
 */
export const RISK_MAX = 100;
/** The Risk of the ideal bot, and the setup screen's starting value. */
export const RISK_IDEAL = 50;

export type LeanCommand = (
  /** At the HTTP boundary, an empty seed requests a private server-generated game. */
  | { cmd: "new_game"; seed: string; risk: number }
  | { cmd: "act"; action: "fold" | "check" | "call" }
  /** A bet or raise to `amount` chips this round. Lean treats "bet" and "raise" the same. */
  | { cmd: "act"; action: "bet" | "raise"; amount: number }
  | { cmd: "next_hand" }
  | { cmd: "state" }
  | { cmd: "review"; hand: number }
) & {
  /**
   * The "Peek at bot's cards" toggle: when true, the reply's state also shows the bot's cards.
   * It changes nothing else. Any command may carry it.
   */
  peek?: boolean;
};

export interface LeanPlayer {
  stack: number;
  /** Chips put in during the current betting round. */
  bet: number;
  /** Null while hidden: the bot's cards until a showdown, unless the command asked to peek. */
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
  /**
   * The bot's settings for this game: the Risk it was started with, and the two values Lean
   * derives from it. `caution` (0-100) is how heavily the bot weighs a lost chip when it
   * decides to call. `bluffPct` is the share of bluffs in its river betting set, in percent.
   */
  sliders: { risk: number; caution: number; bluffPct: number };
  /** The bot's reason for each of its moves this hand. Null until the hand is over. */
  botReasons: string[] | null;
  /**
   * Replay record (MVP §5, §15). How the bot counts its chances on the turn: always "exact"
   * (the mode note is in engine/Engine/Equity.lean).
   */
  turnMode: "exact";
  /**
   * The git commit the Lean program was built from. "unknown" when that cannot be told: git
   * failed, or files under engine/ had changes when it was built.
   */
  engineCommit: string;
  /**
   * Added by the HTTP bridge, not Lean: the commit of the server's checkout, read when the
   * server starts, or "unknown". It can differ from `engineCommit`.
   */
  serverCommit?: string;
}

/** The labels of a graded decision, best first. */
export type ReviewLabel = "Best" | "Good" | "Inaccuracy" | "Mistake" | "Blunder";

/**
 * What a grade counts as the bot's possible hands.
 * - `river-set`: the bot's river betting set, for your call or fold after the bot opens the
 *   river with a bet. This grade is proved (T5, T8).
 * - `any-hand`: every hand the bot could hold, equally likely, with the hand checked down
 *   after a call. For every other call or fold that faces a bet. Not proved.
 */
export type ReviewModel = "river-set" | "any-hand";

/**
 * One of the human's moves in a hand (MVP §13). A call or fold that faces a bet is graded;
 * for every other move the label and numbers are null, and the screen says it is not graded.
 */
export interface ReviewDecision {
  street: "preflop" | "flop" | "turn" | "river";
  your_action: "fold" | "check" | "call" | "bet" | "raise";
  label: ReviewLabel | null;
  /** How the grade counts the bot's hands; null when not graded. Missing from an engine built
   * before any-hand grades, which graded only the river set. */
  model?: ReviewModel | null;
  /** What calling and folding were each worth from this point, in big blinds. */
  worth_bb: { call: number; fold: number } | null;
  /** The human's chance to win against the bot's possible hands, 0 to 1. */
  equity_had: number | null;
  /** The chance needed for a call to break even, 0 to 1. */
  equity_needed: number | null;
  /** The name of your best hand when you moved, like "Pair"; null before the flop. */
  hand_then?: string | null;
  /** Your chance to win against one random hand then, 0 to 1 (ties count half), worked out as the bot does. */
  win_chance?: number | null;
  /** The share of the pot after a call that calling would cost: call / (pot + call). Null with no bet to face. */
  price?: number | null;
}

/** One player's hand in a review (`handSummaryJson` in engine/Engine/Protocol.lean). */
export interface LeanHandSummary {
  cards: Card[];
  /** The name of the best five-card hand, like "Full House"; null before the flop. */
  hand: string | null;
  /** The five cards that make it; null before the flop. */
  best: Card[] | null;
  /** How many of the player's own two cards the best hand uses: 0 means the board alone makes it. */
  cards_used: number;
}

/** Both players' hands, sent once the hand is over. The bot's cards are always included. */
export interface LeanHands {
  board: Card[];
  you: LeanHandSummary;
  bot: LeanHandSummary;
  /** Whose best hand is stronger on the final board; null before the flop. */
  stronger: "you" | "bot" | "tie" | null;
}

export interface LeanReview {
  hand: number;
  decisions: ReviewDecision[];
  /** Both players' cards and hands. Null while the hand is played (and in older replies). */
  hands?: LeanHands | null;
  /** The bot's best hand when it made each move, in order (null entries before the flop). */
  bot_hands?: (string | null)[] | null;
  /** The bot's detailed reason for each of its moves in this hand. Null while the hand is still being played. */
  bot_reasons: string[] | null;
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

/* ---------- Review insights: the river range viewer and the Risk explorer ---------- */

/**
 * The river range viewer's numbers for a graded river decision (`rangeOf` in
 * `engine/Engine/Explain.lean`). They always add up: value + bluffs = blocked + beat + tie + lose.
 */
export interface LeanRange {
  /** Value hands in the bot's river betting set on this board. */
  value: number;
  /** Bluff hands in that set. */
  bluffs: number;
  /** Hands in the set that use one of your cards, so the bot cannot hold them. */
  blocked: number;
  /** Of the hands left, how many your hand beats, ties and loses to. */
  beat: number;
  tie: number;
  lose: number;
}

// This merges into `ReviewDecision` above. The field is optional: only graded decisions have it,
// and Mystery mode removes it until the reveal.
export interface ReviewDecision {
  /** Only on graded decisions: the river range viewer's numbers. */
  range?: LeanRange;
}

/**
 * How Risk affects one bot move, over the player's Risk 0-100.
 * - `noBet`: no bet to face before the river, so the bot does not look at Risk.
 * - `raises`: facing a bet with a win chance of 75% or more, it raises at every Risk.
 * - `callsAlways` / `foldsAlways`: facing a bet, the same at every Risk.
 * - `callsFrom`: facing a bet, folds below `continuesFrom` and calls from it up.
 * - `betsAlways` / `checksAlways`: the river with no bet to face, the same at every Risk.
 * - `bluffsFrom`: the river with no bet to face, checks below `continuesFrom` and bets a bluff
 *   from it up (more Risk, more bluffs).
 * - `varies`: any other pattern.
 */
export type LeanRiskEffect =
  | "noBet"
  | "raises"
  | "callsAlways"
  | "foldsAlways"
  | "callsFrom"
  | "betsAlways"
  | "checksAlways"
  | "bluffsFrom"
  | "varies";

/**
 * One bot move in the Risk explorer (`exploreHandAt` in `engine/Engine/Explain.lean`): the
 * move at every Risk from 0 to 100, with everything else about the decision kept the same.
 */
export interface LeanRiskExplorerEntry {
  street: "preflop" | "flop" | "turn" | "river";
  /** The pot the bot could win, as it saw it. */
  pot: number;
  /** Chips the bot had to add to call; 0 with no bet to face. */
  toCall: number;
  /** The bot's win, tie and loss counts for this move. */
  counts: { win: number; tie: number; loss: number };
  /** The Risk set in this game. */
  risk: number;
  /** The move the bot made, as the table names it ("Call", "Bet 60", "Raise to 120"). */
  action: string;
  /** The move at each Risk: 101 entries, entry r for Risk r. */
  actions: string[];
  /** The lowest Risk at which the bot calls, raises or bets; null if it does none of them. */
  continuesFrom: number | null;
  /** Whether Risk changes this move at all. */
  riskMatters: boolean;
  effect: LeanRiskEffect;
  /** One sentence, such as "Folds at Risk 0-35, calls at 36-100." */
  summary: string;
}

// This merges into `LeanReview` above. The field is optional: Mystery mode removes it until the
// reveal.
export interface LeanReview {
  /** Every bot move in the hand, in order. Null while the hand is still being played. */
  risk_explorer?: LeanRiskExplorerEntry[] | null;
}
/*
 * Mystery opponent (MVP §10, S9): route-level messages. Lean never sees these: the route picks
 * the hidden settings, keeps them, and answers the reveal itself.
 */

/**
 * Start a Mystery game. The route picks Risk (0-100) and a private seed at random, and keeps
 * them secret until the reveal. It must not carry a seed or a Risk.
 */
export interface MysteryNewGame {
  cmd: "new_game";
  mystery: true;
  peek?: boolean;
}

/** The player's one guess at the Mystery bot's Risk. Allowed after 3 finished hands, or at game over. */
export interface RevealCommand {
  cmd: "reveal";
  risk: number;
  peek?: boolean;
}

/** Everything the browser may send to `/api/game`. */
export type ApiCommand = LeanCommand | MysteryNewGame | RevealCommand;

/** The reveal: the real Risk, the guess, and how far off the guess was. */
export interface MysteryReveal {
  risk: number;
  guess: number;
  /** How far the guess was from the real Risk (never negative). */
  off: number;
}

/**
 * A state as `/api/game` sends it. Until a Mystery game is revealed, the route removes
 * `sliders` and `botReasons`, and `seed` stays null even at game over.
 */
export type RouteState = Omit<LeanState, "sliders" | "botReasons"> & Partial<Pick<LeanState, "sliders" | "botReasons">>;

/**
 * A reply from `/api/game`, Mystery games included. Before the reveal, a review request gets
 * `reviewDeferred: true` and no `review`: its grades, equities and reasons would give away the
 * hidden Bluff setting. A reveal gets `reveal`.
 */
export type RouteReply =
  | { ok: true; state: RouteState; review?: LeanReview; reviewDeferred?: true; reveal?: MysteryReveal }
  | { error: string; state: RouteState | null; lost?: true };
