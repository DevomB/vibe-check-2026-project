import type { ReviewLabel } from "@/lean/protocol";
import { labelInfo } from "@/lib/review";
import styles from "./review.module.css";

interface Props {
  label: ReviewLabel;
  /** Also write the label's name next to the badge. */
  named?: boolean;
  size?: "sm" | "md" | "lg";
}

/** A review label as a round badge with its mark: Best ★, Good !, Inaccuracy ?!, Mistake ?, Blunder ??. */
export function ReviewBadge({ label, named = false, size = "md" }: Props) {
  const info = labelInfo(label);
  return (
    <span className={`${styles.badgeWrap} ${styles[`tone-${info.key}`]}`} title={`${info.label}: ${info.band}`}>
      <span className={`${styles.badge} ${styles[`badge-${size}`]}`} aria-hidden="true">
        <span className={info.glyph.length > 1 ? styles.badgeTwo : undefined}>{info.glyph}</span>
      </span>
      {named ? <span className={styles.badgeName}>{info.label}</span> : <span className={styles.srOnly}>{info.label}</span>}
    </span>
  );
}
