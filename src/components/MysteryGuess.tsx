import { useEffect, useState } from "react";
import { BotSlider, RISK_HELP, RISK_MARKS } from "./Lobby";
import { type LeanState, type MysteryReveal, RISK_IDEAL, RISK_MAX } from "@/lean/protocol";
import styles from "./modes.module.css";

interface Props {
  /** The server's answer, once the guess is in; null while guessing. */
  reveal: MysteryReveal | null;
  /** Lean's settings for the bot, once revealed: what it derived from the real Risk. */
  sliders: LeanState["sliders"] | null;
  /** True while the guess is being sent. */
  sending: boolean;
  /** Why the server refused the guess, if it did. */
  error: string | null;
  onGuess: (risk: number) => void;
  onClose: () => void;
  /** Open the review of the last finished hand; shown after the reveal. */
  onReview?: () => void;
}

/** Within this much, a guess counts as close: a tenth of Risk's range. */
const CLOSE = 10;

function verdict(r: MysteryReveal): string {
  if (r.off === 0) return "Exactly right.";
  if (r.off <= CLOSE) return "A sharp read: close.";
  return "Not close this time. The review now shows the bot's reasons.";
}

/** "Guess the bot": one slider for the hidden Risk, then the real Risk and how far off the guess was. */
export function MysteryGuess({ reveal, sliders, sending, error, onGuess, onClose, onReview }: Props) {
  const [risk, setRisk] = useState(RISK_IDEAL);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className={`modal ${styles.guess}`} role="dialog" aria-label="Guess the bot" onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose} aria-label="Close">
          ×
        </button>
        {reveal === null ? (
          <>
            <h2>Guess the bot</h2>
            <p className="muted">
              The server picked this bot's Risk at random. From how it played, what do you think it is? You get one guess.
            </p>
            <div className={styles.guessSliders}>
              <BotSlider label="Risk" value={risk} max={RISK_MAX} shown={String(risk)} marks={RISK_MARKS} help={RISK_HELP} onChange={setRisk} />
            </div>
            {error && (
              <p className="engine-error" role="alert">
                {error}
              </p>
            )}
            <div className="modal-actions">
              <button className="btn btn-primary" onClick={() => onGuess(risk)} disabled={sending}>
                {sending ? "Checking…" : "Reveal the bot"}
              </button>
              <button className="btn btn-ghost" onClick={onClose}>
                Keep playing
              </button>
            </div>
          </>
        ) : (
          <>
            <h2>The bot revealed</h2>
            <p className={styles.verdict}>{verdict(reveal)}</p>
            <table className={styles.revealTable}>
              <thead>
                <tr>
                  <th></th>
                  <th>Your guess</th>
                  <th>Real</th>
                  <th>Off by</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <th>Risk</th>
                  <td>{reveal.guess}</td>
                  <td>{reveal.risk}</td>
                  <td>{reveal.off}</td>
                </tr>
              </tbody>
            </table>
            {sliders && <p className="muted">At Risk {sliders.risk}, Lean set the bot's bluff share to {sliders.bluffPct}%.</p>}
            <p className="muted">Nothing is hidden now: the review and the bot's reasons show the real settings.</p>
            <p className="muted">
              Graded with the bot's real settings, which you did not know when you decided.
            </p>
            <div className="modal-actions">
              {onReview && (
                <button className="btn btn-ghost" onClick={onReview}>
                  Review last hand
                </button>
              )}
              <button className="btn btn-primary" onClick={onClose}>
                Close
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
