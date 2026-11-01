import { useState } from "react";
import { type LeanRiskExplorerEntry, RISK_MAX } from "@/lean/protocol";
import type { GuaranteeId } from "@/lib/guarantees";
import { RISK_MARKS } from "./Lobby";
import { WhyChip } from "./WhyChip";
import styles from "./review.module.css";

interface Props {
  /** One entry per bot move in the hand, in order. */
  entries: LeanRiskExplorerEntry[];
  /** The bot move to show. Set it to follow the review's move list; leave it out to let the explorer keep its own. */
  selected?: number;
  onSelect?: (index: number) => void;
  /** Shows a link that opens the Risk guarantee. */
  onShowProof?: (id: GuaranteeId) => void;
}

const STREET: Record<LeanRiskExplorerEntry["street"], string> = {
  preflop: "Preflop",
  flop: "Flop",
  turn: "Turn",
  river: "River",
};

/** A count with thousands separators: 27,669. */
function count(n: number): string {
  return n.toLocaleString("en-US");
}

/** Start on the first move where Risk matters, else the first move facing a bet, else the first move. */
export function firstInteresting(entries: LeanRiskExplorerEntry[]): number {
  const changes = entries.findIndex((e) => e.riskMatters);
  if (changes >= 0) return changes;
  const facing = entries.findIndex((e) => e.toCall > 0);
  return facing >= 0 ? facing : 0;
}

/**
 * Where the bot's counts come from (the T6 guarantee): every outcome on the turn and river, an
 * estimate on the flop (sampled deals) and preflop (a table of sampled deals).
 */
function countsNote(street: LeanRiskExplorerEntry["street"], total: number): string {
  return street === "turn" || street === "river"
    ? `of all ${count(total)} possible outcomes (every one counted)`
    : `of ${count(total)} sampled deals (an estimate)`;
}

/**
 * The Risk explorer: pick one of the bot's moves, keep everything else about it the same,
 * and move Risk from 0 to 100. Lean computes the move at every Risk and the summary sentence
 * (`exploreHand` in `engine/Engine/Explain.lean`); this only shows them.
 */
export function RiskExplorer({ entries, selected, onSelect, onShowProof }: Props) {
  const [own, setOwn] = useState(() => firstInteresting(entries));
  const index = selected ?? own;
  const entry = entries[index] ?? entries[0];
  const [risk, setRisk] = useState(() => entry?.risk ?? 0);
  if (!entry) return null;

  const pick = (i: number) => {
    setOwn(i);
    onSelect?.(i);
  };
  const outcomes = entry.counts.win + entry.counts.tie + entry.counts.loss;
  const atRisk = entry.actions[risk] ?? entry.action;

  return (
    <div className={styles.explorer}>
      <div role="radiogroup" aria-label="The bot's moves this hand" className={styles.explorerMoves}>
        {entries.map((e, i) => (
          <button
            key={i}
            type="button"
            role="radio"
            aria-checked={i === index}
            className={`${styles.pill} ${i === index ? styles.isSelected : ""}`}
            onClick={() => pick(i)}
          >
            {STREET[e.street]}: {e.action}
          </button>
        ))}
      </div>

      <div className={styles.explorerCard}>
        <p className={styles.explorerSpot}>
          {entry.toCall > 0 ? `The bot had to call ${count(entry.toCall)} to win ${count(entry.pot)}.` : `No bet to face, ${count(entry.pot)} in the pot.`} Its
          cards won {count(entry.counts.win)}, tied {count(entry.counts.tie)} and lost {count(entry.counts.loss)} {countsNote(entry.street, outcomes)}.
        </p>

        <label className={styles.explorerSlider}>
          <span>
            At Risk <b>{risk}</b>, the bot would: <b>{atRisk}</b>
            {risk === entry.risk && <span className="muted"> (its real setting)</span>}
          </span>
          <input type="range" min={0} max={RISK_MAX} step={1} value={risk} aria-label="Risk" onChange={(e) => setRisk(Number(e.target.value))} />
        </label>
        <div className={styles.explorerMarks} aria-hidden="true">
          {RISK_MARKS.map((m) => (
            <span key={m.at} style={{ left: `${(m.at / RISK_MAX) * 100}%` }}>
              {m.label}
            </span>
          ))}
        </div>
        <div className={styles.explorerMarker} aria-hidden="true">
          <span className={styles.markerTip} style={{ left: `${entry.risk}%` }}>
            ▲
          </span>
          <span className={styles.markerText} style={{ left: `${entry.risk}%`, transform: `translateX(-${entry.risk}%)` }}>
            bot&apos;s Risk {entry.risk}
          </span>
        </div>
        <p>
          The bot played at Risk {entry.risk}: <b>{entry.action}</b>.{" "}
          {risk !== entry.risk && (
            <button type="button" className={styles.textButton} onClick={() => setRisk(entry.risk)}>
              Back to Risk {entry.risk}
            </button>
          )}
        </p>
        <p className={styles.explorerSummary}>{entry.summary}</p>
        <p className="muted">Only this one move changes. The moves before it stay as they were played.</p>
      </div>

      <div className={styles.linkRow}>
        <WhyChip ideas={["risk-weight"]} />
        {onShowProof && (
          <button type="button" className={styles.proofLink} onClick={() => onShowProof("risk")}>
            Why can I trust the Risk explorer?
          </button>
        )}
      </div>
    </div>
  );
}
