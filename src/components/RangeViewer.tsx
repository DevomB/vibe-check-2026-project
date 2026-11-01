import type { LeanRange } from "@/lean/protocol";

interface Props {
  range: LeanRange;
  /** Shows a "Why can I trust this?" link that opens the Bluff guarantee. */
  onShowProof?: (id: string) => void;
}

function plural(n: number, one: string, many: string): string {
  return `${n} ${n === 1 ? one : many}`;
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
    <div className="range-viewer" style={{ marginTop: 10, paddingTop: 10, borderTop: "1px solid var(--line)", fontSize: 14 }}>
      <p style={{ margin: 0 }}>
        The bot bets {plural(bets, "hand", "hands")} here: {range.value} for value and {plural(range.bluffs, "bluff", "bluffs")}. Your
        cards block {range.blocked}. Of the {left} left, you beat {range.beat}, tie {range.tie} and lose to {range.lose}.
      </p>
      {left > 0 && (
        <div
          role="img"
          aria-label={`Of ${left} hands: you beat ${range.beat}, tie ${range.tie}, lose to ${range.lose}`}
          style={{ display: "flex", height: 8, marginTop: 8, borderRadius: 4, overflow: "hidden", background: "var(--panel-2)" }}
        >
          <span style={{ width: share(range.beat), background: "var(--green)" }} />
          <span style={{ width: share(range.tie), background: "var(--muted)" }} />
          <span style={{ width: share(range.lose), background: "var(--red)" }} />
        </div>
      )}
      {onShowProof && (
        <button className="btn-link" style={{ marginTop: 6, fontSize: 13 }} onClick={() => onShowProof("bluff")}>
          Why can I trust this?
        </button>
      )}
    </div>
  );
}
