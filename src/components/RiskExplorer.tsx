import { useState } from "react";
import type { LeanRiskExplorerEntry } from "@/lean/protocol";

interface Props {
  /** One entry per bot move in the hand, in order. */
  entries: LeanRiskExplorerEntry[];
  /** Shows a "Why can I trust this?" link that opens the Risk guarantee. */
  onShowProof?: (id: string) => void;
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
function firstInteresting(entries: LeanRiskExplorerEntry[]): number {
  const changes = entries.findIndex((e) => e.riskMatters);
  if (changes >= 0) return changes;
  const facing = entries.findIndex((e) => e.toCall > 0);
  return facing >= 0 ? facing : 0;
}

/**
 * The Risk explorer: pick one of the bot's moves, keep everything else about it the same,
 * and move Risk from 0 to 100. Lean computes the move at every Risk and the summary sentence
 * (`exploreHand` in `engine/Engine/Explain.lean`); this only shows them.
 */
export function RiskExplorer({ entries, onShowProof }: Props) {
  const [selected, setSelected] = useState(() => firstInteresting(entries));
  const entry = entries[selected] ?? entries[0];
  const [risk, setRisk] = useState(() => entry?.risk ?? 0);
  if (!entry) return null;

  const outcomes = entry.counts.win + entry.counts.tie + entry.counts.loss;
  const atRisk = entry.actions[risk] ?? entry.action;

  return (
    <div className="risk-explorer" style={{ display: "grid", gap: 10, fontSize: 14 }}>
      <div role="radiogroup" aria-label="The bot's moves this hand" style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
        {entries.map((e, i) => (
          <button
            key={i}
            role="radio"
            aria-checked={i === selected}
            className={`btn btn-sm ${i === selected ? "btn-primary" : "btn-ghost"}`}
            onClick={() => setSelected(i)}
          >
            {STREET[e.street]}: {e.action}
          </button>
        ))}
      </div>

      <div className="review-item" style={{ display: "grid", gap: 8 }}>
        <div className="muted">
          {entry.toCall > 0 ? `The bot had to call ${entry.toCall} to win ${entry.pot}.` : `No bet to face, ${entry.pot} in the pot.`} Its
          cards won {count(entry.counts.win)}, tied {count(entry.counts.tie)} and lost {count(entry.counts.loss)} of {count(outcomes)}{" "}
          outcomes.
        </div>

        <label style={{ display: "grid", gap: 4 }}>
          <span>
            At Risk <b>{risk}</b>, the bot would: <b>{atRisk}</b>
            {risk === entry.risk && <span className="muted"> (its real setting)</span>}
          </span>
          <input type="range" min={0} max={100} step={1} value={risk} aria-label="Risk" onChange={(e) => setRisk(Number(e.target.value))} />
        </label>
        <div style={{ position: "relative", height: 18 }} aria-hidden="true">
          <span
            className="muted"
            style={{ position: "absolute", left: `${entry.risk}%`, transform: "translateX(-50%)", fontSize: 12, whiteSpace: "nowrap" }}
          >
            ▲ bot's Risk {entry.risk}
          </span>
        </div>
        <div>
          The bot played at Risk {entry.risk}: <b>{entry.action}</b>.{" "}
          {risk !== entry.risk && (
            <button className="btn-link" onClick={() => setRisk(entry.risk)}>
              Back to Risk {entry.risk}
            </button>
          )}
        </div>
        <div>
          <b>{entry.summary}</b>
        </div>
      </div>

      {onShowProof && (
        <button className="btn-link" style={{ justifySelf: "start", fontSize: 13 }} onClick={() => onShowProof("risk")}>
          Why can I trust this?
        </button>
      )}
    </div>
  );
}
