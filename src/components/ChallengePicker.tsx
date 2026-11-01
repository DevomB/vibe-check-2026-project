import type { ReactNode } from "react";
import type { Game } from "@/hooks/useGame";
import { CHALLENGES, type Challenge, type PracticeVerdict, RIGHT_BUT_UNLUCKY, atRiverDecision } from "@/lib/challenges";
import { ReviewBadge } from "./ReviewBadge";
import styles from "./modes.module.css";

/** The practice buttons on the setup screen. Each loads a rehearsed hand at its river decision. */
export function ChallengePicker({ onPick }: { onPick: (c: Challenge) => void }) {
  return (
    <div className={styles.challenges}>
      {CHALLENGES.map((c) => (
        <button key={c.id} type="button" className={styles.challenge} onClick={() => onPick(c)}>
          <span className={styles.challengeTitle}>{c.title}</span>
          <span className={styles.challengeAbout}>{c.about}</span>
        </button>
      ))}
    </div>
  );
}

interface BarProps {
  game: Game;
  challenge: Challenge;
  /** Lean's grade of this practice hand, once its review has arrived. */
  verdict: PracticeVerdict | null;
  /** The review is open: float the verdict above it. */
  overReview: boolean;
  onRetry: () => void;
}

/**
 * The practice line under the table: the prompt at the river decision, then Lean's grade once
 * the hand is over. The grade is read from Lean's review, never from the recorded spot.
 */
export function PracticeBar({ game, challenge, verdict, overReview, onRetry }: BarProps) {
  if (game.lean.hand !== 1) return null;
  if (atRiverDecision(game.lean)) {
    return (
      <div className={styles.practiceBar} role="status">
        <span>
          <b>{challenge.title}.</b> {challenge.prompt} Lean grades your choice when the hand ends.
        </span>
      </div>
    );
  }
  if (game.lean.result === null) return null;
  let text: ReactNode;
  if (verdict === null) text = "The hand is over. The review shows Lean's grade.";
  else if (verdict.choice === null || verdict.label === null) text = "Lean grades only a call or a fold here, so this hand has no grade.";
  else
    text = (
      <>
        Lean graded your {verdict.choice}: <ReviewBadge label={verdict.label} named size="sm" />.{verdict.unlucky ? ` ${RIGHT_BUT_UNLUCKY}` : ""}
      </>
    );
  return (
    <div className={`${styles.practiceBar} ${overReview ? styles.practiceFloat : ""}`} role="status">
      <span>
        <b>{challenge.title}.</b> {text}
      </span>
      <button className="btn btn-ghost btn-sm" onClick={onRetry}>
        Try again
      </button>
    </div>
  );
}
