import type { Card } from "@/lib/cards";
import type { LeanEvent, LeanReview, ReviewDecision, ReviewLabel } from "@/lean/protocol";

/**
 * Display helpers for the game review: the label badges, the move list and the coach's
 * sentences. Lean grades the moves and sends every number. This file only lines Lean's lists
 * up and puts them into words.
 */

export interface LabelInfo {
  label: ReviewLabel;
  /** The mark chess players know from move reviews. */
  glyph: string;
  /** CSS-friendly name, like "best". */
  key: string;
  /** What the label means: Lean's band (`labelFor` in engine/Engine/Review.lean), in words. */
  band: string;
}

/** The five labels, best first. */
export const LABELS: readonly LabelInfo[] = [
  { label: "Best", glyph: "★", key: "best", band: "worth as much as the best choice" },
  { label: "Good", glyph: "!", key: "good", band: "less than 0.5 big blinds worse than the best choice" },
  { label: "Inaccuracy", glyph: "?!", key: "inaccuracy", band: "0.5 to 2 big blinds worse than the best choice" },
  { label: "Mistake", glyph: "?", key: "mistake", band: "2 to 5 big blinds worse than the best choice" },
  { label: "Blunder", glyph: "??", key: "blunder", band: "5 or more big blinds worse than the best choice" },
];

export function labelInfo(label: ReviewLabel): LabelInfo {
  return LABELS.find((l) => l.label === label)!;
}

/** How many decisions got each label, best first. */
export function labelCounts(decisions: readonly ReviewDecision[]): { info: LabelInfo; count: number }[] {
  return LABELS.map((info) => ({ info, count: decisions.filter((d) => d.label === info.label).length }));
}

/** Big blinds with a sign, at the 2 decimals Lean sends: "+1.57 BB", "0.00 BB", "−2.67 BB". */
export function formatBb(x: number): string {
  const s = Math.abs(x).toFixed(2);
  if (s === "0.00") return "0.00 BB";
  return `${x > 0 ? "+" : "−"}${s} BB`;
}

/** A chance from 0 to 1 as a percentage with one decimal: 0.596 is "59.6%". */
export function formatPct(x: number): string {
  return `${(x * 100).toFixed(1)}%`;
}

export type Street = ReviewDecision["street"];

/** One line of the move list. */
export interface MoveRow {
  /** The event's place in the hand. Also a stable key. */
  at: number;
  kind: "blind" | "move" | "win";
  player: number;
  /** The table's words for it, like "You call 20" or "Mia bets 40". */
  text: string;
  /** For your moves: the review's entry for that move. */
  decision: ReviewDecision | null;
  /** For the bot's moves: which of its moves this is (0 for the first). It indexes `bot_reasons` and `risk_explorer`. */
  botMove: number | null;
}

/** The moves of one street, with the cards it put on the board. */
export interface StreetMoves {
  street: Street;
  /** The cards this street put on the board: none preflop, and none when they are not known. */
  cards: Card[];
  /** The place in the hand's events where these cards were dealt; -1 for preflop. */
  dealtAt: number;
  rows: MoveRow[];
}

/**
 * Lean's events for a hand, grouped by street. Your moves are matched with the review's
 * decisions, and the bot's moves are numbered for its reasons and the Risk explorer. Both
 * lists come from Lean in the order the moves were made, so your first move is the first
 * decision, and so on. `lines` has the table's words for each event, in the same order.
 * Returns null when the lists do not match (for example, when events are missing), so the
 * screen can fall back to the review alone.
 */
export function buildMoveList(
  events: readonly LeanEvent[],
  lines: readonly string[],
  review: LeanReview,
  human: number,
): StreetMoves[] | null {
  if (lines.length !== events.length) return null;
  const yours = events.filter((e) => e.type === "action" && e.player === human).length;
  if (yours !== review.decisions.length) return null;
  const bots = events.filter((e) => e.type === "action" && e.player !== human).length;
  const explorer = review.risk_explorer ?? null;
  const reasons = review.bot_reasons ?? null;
  // Number the bot's moves only if the review's per-move lists have one entry per move.
  const numbered = (explorer === null || explorer.length === bots) && (reasons === null || reasons.length === bots);

  const streets: StreetMoves[] = [{ street: "preflop", cards: [], dealtAt: -1, rows: [] }];
  let yourMove = 0;
  let botMove = 0;
  events.forEach((e, at) => {
    const current = streets[streets.length - 1]!;
    if (e.type === "street") {
      streets.push({ street: e.street, cards: e.cards, dealtAt: at, rows: [] });
    } else if (e.type === "action") {
      const mine = e.player === human;
      current.rows.push({
        at,
        kind: "move",
        player: e.player,
        text: lines[at]!,
        decision: mine ? review.decisions[yourMove]! : null,
        botMove: !mine && numbered ? botMove : null,
      });
      if (mine) yourMove++;
      else botMove++;
    } else {
      current.rows.push({ at, kind: e.type, player: e.player, text: lines[at]!, decision: null, botMove: null });
    }
  });
  return streets;
}

const YOUR_ACTION: Record<ReviewDecision["your_action"], string> = {
  fold: "You fold",
  check: "You check",
  call: "You call",
  bet: "You bet",
  raise: "You raise",
};

/** The review alone, grouped by street: your moves only, without amounts. The fallback when the events are missing. */
export function movesFromReview(review: LeanReview, human: number): StreetMoves[] {
  const streets: StreetMoves[] = [];
  review.decisions.forEach((d, i) => {
    let group = streets[streets.length - 1];
    if (!group || group.street !== d.street) {
      group = { street: d.street, cards: [], dealtAt: -1, rows: [] };
      streets.push(group);
    }
    group.rows.push({ at: i, kind: "move", player: human, text: YOUR_ACTION[d.your_action], decision: d, botMove: null });
  });
  return streets;
}

/** The moves one can step through, in order. Blinds and wins are not moves. */
export function selectableMoves(streets: readonly StreetMoves[]): MoveRow[] {
  return streets.flatMap((s) => s.rows.filter((r) => r.kind === "move"));
}

/** The board when event number `at` happened, or the whole board when `at` is null. */
export function boardAt(streets: readonly StreetMoves[], at: number | null): Card[] {
  return streets.filter((s) => at === null || s.dealtAt < at).flatMap((s) => s.cards);
}

/** The street event number `at` happened on, or the last street when `at` is null. */
export function streetAt(streets: readonly StreetMoves[], at: number | null): Street {
  const before = streets.filter((s) => at === null || s.dealtAt < at);
  return (before[before.length - 1] ?? streets[0])?.street ?? "preflop";
}

const GERUND = { call: "Calling", fold: "Folding" } as const;

function withArticle(label: ReviewLabel): string {
  if (label === "Best" || label === "Good") return label;
  return `${label === "Inaccuracy" ? "an" : "a"} ${label}`;
}

/** The coach's words for a graded call or fold. The numbers are Lean's; only the words are chosen here. */
export interface GradedCoach {
  /** "Calling is a Mistake." */
  headline: string;
  /** "You win 18.0% against the hands the bot bets here (a tie counts half). Calling needed 33.3% to break even." */
  chances: string | null;
  /** "Folding was Best." when the other choice was the better one. */
  better: string | null;
  /** "Calling was worth −2.67 BB; folding was worth 0.00 BB." */
  worths: string | null;
  /** The label's band: "Mistake: 2 to 5 big blinds worse than the best choice." */
  band: string;
  /** What the grade assumes, for a grade that is not proved (`any-hand`); null for the proved river grade. */
  note: string | null;
}

/** A grade against the bot's river betting set: the proved one. An engine without `model` graded only this. */
export function isRiverSetGrade(d: ReviewDecision): boolean {
  return d.label !== null && (d.model ?? "river-set") === "river-set";
}

/** The note under an any-hand grade: what it assumes, and that it is not proved. */
export const ANY_HAND_NOTE =
  "This grade counts every hand the bot could hold as equally likely, and assumes no more betting after a call. It ignores how the bot played. Unlike the river grade, it is not proved in Lean.";

/**
 * Words for a graded decision: a call or a fold, the only moves the review grades. When the
 * label is not Best, the other choice was worth more (theorem `review_best_iff` for the river
 * grade), so it was Best.
 */
export function gradedCoach(d: ReviewDecision): GradedCoach | null {
  if (d.label === null || (d.your_action !== "call" && d.your_action !== "fold")) return null;
  const mine = d.your_action;
  const other = mine === "call" ? "fold" : "call";
  const info = labelInfo(d.label);
  const riverSet = isRiverSetGrade(d);
  const against = riverSet ? "the hands the bot bets here" : "any two cards the bot could hold";
  const chances =
    d.equity_had !== null && d.equity_needed !== null
      ? `You win ${formatPct(d.equity_had)} against ${against} (a tie counts half). Calling needed ${formatPct(d.equity_needed)} to break even.`
      : null;
  // Display amounts are rounded; equal decimals do not establish an exact tie.
  const better = d.label !== "Best" ? `${GERUND[other]} was Best.` : null;
  const worths = d.worth_bb ? `Calling was worth ${formatBb(d.worth_bb.call)}; folding was worth ${formatBb(d.worth_bb.fold)}.` : null;
  // `countsFor` deals 1,000 random boards on the flop; the turn and river counts are exact.
  const note = riverSet ? null : d.street === "flop" ? `${ANY_HAND_NOTE} On the flop, the chance comes from 1,000 random deals, so it is an estimate.` : ANY_HAND_NOTE;
  return { headline: `${GERUND[mine]} is ${withArticle(d.label)}.`, chances, better, worths, band: `${info.label}: ${info.band}.`, note };
}

const NO_SUCH_DECISION = "This hand had no such decision.";

/**
 * Why a hand has no grade. `events` are the hand's events, or null when they are not known;
 * `human` is your seat. Lean grades your calls and folds that face a bet, so the reason says
 * why the hand had none.
 */
export function noGradeReason(events: readonly LeanEvent[] | null, human: number): string {
  const what = "Lean grades your calls and folds when you face a bet.";
  return `${what} ${events === null ? NO_SUCH_DECISION : missingGradedMove(events, human)}`;
}

/** Why a hand had no call or fold that faced a bet: you made no move, you only raised the bets, or you faced none. */
function missingGradedMove(events: readonly LeanEvent[], human: number): string {
  // Chips each player has put in on this street: a player faces a bet when the other has put in more.
  const bets = [0, 0];
  let moved = false;
  let raisedBets = false;
  let answeredBet = false;
  for (const e of events) {
    if (e.type === "street") bets.fill(0);
    else if (e.type === "blind") bets[e.player] = (bets[e.player] ?? 0) + e.amount;
    else if (e.type === "action") {
      const facing = (bets[1 - e.player] ?? 0) > (bets[e.player] ?? 0);
      if (e.player === human) {
        moved = true;
        if (facing && e.action === "raise") raisedBets = true;
        if (facing && (e.action === "call" || e.action === "fold")) answeredBet = true;
      }
      bets[e.player] = (bets[e.player] ?? 0) + e.amount;
    }
  }
  if (!moved) return "You made no move in this hand.";
  if (answeredBet) return NO_SUCH_DECISION;
  if (raisedBets) return "You raised the bets you faced instead of calling or folding.";
  return "You never faced a bet in this hand.";
}
