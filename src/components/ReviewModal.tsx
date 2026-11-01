import { useEffect } from "react";
import type { LeanReview, ReviewDecision } from "@/lean/protocol";

interface Props {
  review: LeanReview;
  /** The bot's detailed reasons for this hand's moves, from Lean. */
  botReasons: string[] | null;
  /** "Peek at bot's cards" was on while this hand was played. Display only. */
  peeked?: boolean;
  onClose: () => void;
}

const LABEL_HELP: Record<string, string> = {
  Best: "the better of call and fold",
  Good: "lost less than 0.5 big blinds",
  Inaccuracy: "lost 0.5 to 2 big blinds",
  Mistake: "lost 2 to 5 big blinds",
  Blunder: "lost 5 big blinds or more",
};

const PAST: Record<ReviewDecision["your_action"], string> = {
  fold: "folded",
  check: "checked",
  call: "called",
  bet: "bet",
  raise: "raised",
};

/** Lean's numbers are exact fractions turned into decimals for display; round them only here. */
function bb(x: number): string {
  const r = Math.round(x * 10) / 10;
  return `${r > 0 ? "+" : ""}${r === 0 ? "0" : r.toFixed(1)} BB`;
}

function pct(x: number): string {
  return `${Math.round(x * 100)}%`;
}

function titleCase(s: string): string {
  return s ? s[0]!.toUpperCase() + s.slice(1) : s;
}

function Decision({ d }: { d: ReviewDecision }) {
  const graded = d.label !== null;
  return (
    <li className={`review-item ${graded ? "" : "is-ungraded"}`}>
      <div className="review-head">
        <span className="review-move">
          {titleCase(d.street)}: you {PAST[d.your_action]}
        </span>
        {graded ? (
          <span className={`review-label label-${d.label!.toLowerCase()}`} title={LABEL_HELP[d.label!]}>
            {d.label}
          </span>
        ) : (
          <span className="review-label label-none">not graded yet</span>
        )}
      </div>
      {graded && (
        <div className="review-numbers">
          {d.worth_bb && (
            <div>
              <span className="muted">Call was worth</span> <b>{bb(d.worth_bb.call)}</b>
              <span className="muted"> · Fold was worth</span> <b>{bb(d.worth_bb.fold)}</b>
            </div>
          )}
          {d.equity_had !== null && d.equity_needed !== null && (
            <div>
              <span className="muted">Your equity</span> <b>{pct(d.equity_had)}</b>
              <span className="muted"> · needed to call</span> <b>{pct(d.equity_needed)}</b>
            </div>
          )}
        </div>
      )}
    </li>
  );
}

/** After a hand: Lean's grades for the human's river call/fold decisions, and the bot's reasons. */
export function ReviewModal({ review, botReasons, peeked = false, onClose }: Props) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const graded = review.decisions.filter((d) => d.label !== null);
  const ungraded = review.decisions.filter((d) => d.label === null);

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal review" role="dialog" aria-label={`Review of hand ${review.hand}`} onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose} aria-label="Close">
          ×
        </button>
        <h2>Hand #{review.hand} review</h2>
        <p className="muted review-intro">
          Only your call or fold after the bot's first bet on the river is graded. Values are in big blinds and count the chips you
          could still win or lose from that point.
        </p>
        {peeked && (
          <p className="review-peeked" role="note">
            You peeked at the bot's cards this hand. The grade assumes you didn't know them.
          </p>
        )}

        <h3>Graded decisions</h3>
        {graded.length > 0 ? (
          <ul className="review-list">
            {graded.map((d, i) => (
              <Decision key={`g-${i}`} d={d} />
            ))}
          </ul>
        ) : (
          <p className="muted">No river call or fold to grade in this hand.</p>
        )}

        {ungraded.length > 0 && (
          <>
            <h3>Other decisions</h3>
            <ul className="review-list">
              {ungraded.map((d, i) => (
                <Decision key={`u-${i}`} d={d} />
              ))}
            </ul>
          </>
        )}

        <h3>Why the bot played this way</h3>
        {botReasons && botReasons.length > 0 ? (
          <ol className="review-reasons">
            {botReasons.map((r, i) => (
              <li key={i}>{r}</li>
            ))}
          </ol>
        ) : (
          <p className="muted">The bot made no moves this hand.</p>
        )}

        <div className="modal-actions">
          <button className="btn btn-primary" onClick={onClose}>
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
