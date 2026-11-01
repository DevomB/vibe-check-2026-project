import type { LeanRange } from "@/lean/protocol";
import type { GuaranteeId } from "@/lib/guarantees";
import { WhyChip } from "./WhyChip";
import styles from "./review.module.css";

interface Props {
  range: LeanRange;
  /** Shows a link that opens the review guarantee, whose theorems cover these counts. */
  onShowProof?: (id: GuaranteeId) => void;
}

function count(n: number): string {
  return n.toLocaleString("en-US");
}

/**
 * The river range viewer, next to a graded river decision: the bot's river betting set on
 * that board, the hands your cards block, and how your hand does against the rest. Lean
 * computes every number (`rangeOf` in `engine/Engine/Explain.lean`); this only words them.
 */
export function RangeViewer({ range, onShowProof }: Props) {
  const bets = range.value + range.bluffs;
  const left = range.beat + range.tie + range.lose;
  const share = (n: number) => (left > 0 ? `${(100 * n) / left}%` : "0%");
  return (
    <div className={styles.range}>
      <h4>The hands the grade counts</h4>
      <p>
        On this board the bot bets with {count(bets)} two-card hands: {count(range.value)} for value and {count(range.bluffs)}{" "}
        {range.bluffs === 1 ? "bluff" : "bluffs"}. Your cards block {count(range.blocked)} of them. Of the {count(left)} left, you beat{" "}
        {count(range.beat)}, tie {count(range.tie)} and lose to {count(range.lose)}.
      </p>
      {left > 0 && (
        <>
          <div className={styles.rangeBar} role="img" aria-label={`Of ${left} hands: you beat ${range.beat}, tie ${range.tie}, lose to ${range.lose}`}>
            <span className={styles.beat} style={{ width: share(range.beat) }} />
            <span className={styles.tie} style={{ width: share(range.tie) }} />
            <span className={styles.lose} style={{ width: share(range.lose) }} />
          </div>
          <div className={styles.rangeKey} aria-hidden="true">
            <span className={styles.keyBeat}>you beat</span>
            <span className={styles.keyTie}>tie</span>
            <span className={styles.keyLose}>you lose to</span>
          </div>
        </>
      )}
      <div className={styles.linkRow}>
        <WhyChip ideas={["bluff-ratio", "min-defense"]} />
        {onShowProof && (
          <button type="button" className={styles.proofLink} onClick={() => onShowProof("review")}>
            Why can I trust these counts?
          </button>
        )}
      </div>
    </div>
  );
}
