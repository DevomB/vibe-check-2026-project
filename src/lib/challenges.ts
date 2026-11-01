import type { LeanReview, LeanState, ReviewLabel } from "@/lean/protocol";

/**
 * Practice challenges: rehearsed hands that stop at a river decision. Each is hand 1 of a new
 * game. The app starts the game with the spot's seed and sliders, sends `moves` through the
 * normal `act` command, and stops when the bot has opened the river with a bet. The player
 * then calls or folds, and Lean's review grades the choice. Nothing here decides the game:
 * `best`, `labels`, `worth_bb` and `result_if_best` are what Lean answered when the spots were
 * found, kept so `challenges.test.ts` can check that Lean still answers the same.
 *
 * The spot data is copied from `docs/demo/challenges.json` on branch `release-docs` (commit
 * f55a3ee). Job 3 found and replayed the spots there with `docs/demo/find-demo-hands.mjs`.
 */

export type ChallengeId = "catch-bluff" | "avoid-bad-call" | "right-and-lose";

/** One of the human's moves before the river decision, as the `act` command takes it. */
export type ChallengeMove = { action: "fold" | "check" | "call" } | { action: "bet" | "raise"; amount: number };

export interface Challenge {
  id: ChallengeId;
  title: string;
  /** One line under the button on the setup screen. */
  about: string;
  /** The one-line prompt at the river decision. */
  prompt: string;
  /** An entered seed, so the cards are the rehearsed ones. */
  seed: string;
  risk: number;
  bluff_pct: number;
  moves: ChallengeMove[];
  /** The choice Lean grades Best. */
  best: "call" | "fold";
  /** Lean's label for each choice. */
  labels: { call: ReviewLabel; fold: ReviewLabel };
  /** Lean's worth of each choice, in big blinds, rounded for display. */
  worth_bb: { call: number; fold: number };
  /** How the hand ends after the Best choice: who won, and the human's chips won or lost in it. */
  result_if_best: { outcome: "player0" | "player1" | "tie" | "fold"; showdown: boolean; human_net_chips: number };
}

export const CHALLENGES: readonly Challenge[] = [
  {
    id: "catch-bluff",
    title: "Catch a bluff",
    about: "The bot bluffs a lot. Can you tell when it is bluffing on the river?",
    prompt: "The bot bets on the river. Is it bluffing? Call or fold.",
    seed: "1",
    risk: 0,
    bluff_pct: 60,
    moves: [{ action: "call" }, { action: "check" }, { action: "check" }],
    best: "call",
    labels: { call: "Best", fold: "Inaccuracy" },
    worth_bb: { call: 1.57, fold: 0 },
    result_if_best: { outcome: "player0", showdown: true, human_net_chips: 30 },
  },
  {
    id: "avoid-bad-call",
    title: "Avoid a bad call",
    about: "Not every river bet is a bluff. Know when to let your hand go.",
    prompt: "The bot bets on the river. Is your hand good enough to call? Call or fold.",
    seed: "6",
    risk: 0,
    bluff_pct: 60,
    moves: [{ action: "raise", amount: 30 }, { action: "check" }, { action: "check" }],
    best: "fold",
    labels: { call: "Mistake", fold: "Best" },
    worth_bb: { call: -2.67, fold: 0 },
    result_if_best: { outcome: "fold", showdown: false, human_net_chips: -30 },
  },
  {
    id: "right-and-lose",
    title: "Make the right decision and still lose",
    about: "A good decision can still lose chips. See how the review grades it.",
    prompt: "The bot bets on the river. Make the right choice: call or fold.",
    seed: "4",
    risk: 0,
    bluff_pct: 60,
    moves: [{ action: "call" }, { action: "check" }, { action: "call" }],
    best: "call",
    labels: { call: "Best", fold: "Blunder" },
    worth_bb: { call: 10.32, fold: 0 },
    result_if_best: { outcome: "player1", showdown: true, human_net_chips: -90 },
  },
];

/** The line the practice bar shows after a Best choice that lost chips at showdown (T8, `no_hindsight`). */
export const RIGHT_BUT_UNLUCKY = "Right decision, unlucky result. The grade looks at the decision, not the hand the bot turned out to hold.";

/**
 * True when Lean's state is the challenge's decision point: hand 1 is on the river, it is the
 * human's turn, and there is a bet to call (the bot opened the river). Only Lean's reply is read.
 */
export function atRiverDecision(s: Pick<LeanState, "hand" | "status" | "street" | "toAct" | "legal">): boolean {
  return s.hand === 1 && s.status === "playing" && s.street === "river" && s.toAct === 0 && s.legal !== null && s.legal.call > 0;
}

/** What the practice bar says once the hand is over, read from Lean's review and result. */
export interface PracticeVerdict {
  /** The graded river answer, or null if the player raised (raises are not graded). */
  choice: "call" | "fold" | null;
  label: ReviewLabel | null;
  /** Lean graded the choice Best, and the bot still won the showdown. */
  unlucky: boolean;
}

export function practiceVerdict(review: LeanReview, result: LeanState["result"]): PracticeVerdict {
  const graded = review.decisions.find((d) => d.label !== null);
  const choice = graded?.your_action === "call" || graded?.your_action === "fold" ? graded.your_action : null;
  const label = graded?.label ?? null;
  return { choice, label, unlucky: label === "Best" && result?.showdown === true && result.outcome === "player1" };
}
