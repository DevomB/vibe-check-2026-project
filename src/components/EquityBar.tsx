import { formatPct } from "@/lib/review";
import styles from "./review.module.css";

interface Props {
  /** Your chance to win at the selected move, 0 to 1 (Lean's `equity_had`); null when the move has no grade. */
  had: number | null;
  /** The chance a call needed to break even, 0 to 1 (Lean's `equity_needed`). */
  needed: number | null;
}

/**
 * The review's vertical bar, read like a chess evaluation bar: the light part is your chance
 * to win at the selected move, and the gold line is the chance a call needed. Light above the
 * gold line means calling was worth it.
 */
export function EquityBar({ had, needed }: Props) {
  const graded = had !== null && needed !== null;
  const label = graded ? `You win ${formatPct(had)}. Calling needed ${formatPct(needed)}.` : "The selected move has no grade, so there are no chances to show.";
  return (
    <div className={`${styles.equityBar} ${graded ? "" : styles.isEmpty}`} role="img" aria-label={label} title={label}>
      <div className={styles.equityTrack}>
        <div className={styles.equityClip}>{graded && <div className={styles.equityFill} style={{ height: `${had * 100}%` }} />}</div>
        {graded && <div className={styles.equityNeed} style={{ bottom: `${needed * 100}%` }} />}
      </div>
      <div className={styles.equityLegend} aria-hidden="true">
        <b>{graded ? formatPct(had) : "–"}</b>
        <span>{graded ? "you win" : "no grade"}</span>
        {graded && (
          <>
            <b className={styles.needText}>{formatPct(needed)}</b>
            <span>needed</span>
          </>
        )}
      </div>
    </div>
  );
}
