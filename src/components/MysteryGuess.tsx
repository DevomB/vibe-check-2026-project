import { useEffect, useState } from "react";
import { BotSlider } from "./Lobby";
import { BLUFF_PCT_MAX, type MysteryReveal, RISK_MAX } from "@/lean/protocol";
import styles from "./modes.module.css";

interface Props {
  /** The server's answer, once the guess is in; null while guessing. */
  reveal: MysteryReveal | null;
  /** True while the guess is being sent. */
  sending: boolean;
  /** Why the server refused the guess, if it did. */
  error: string | null;
  onGuess: (risk: number, bluffPct: number) => void;
  onClose: () => void;
  /** Open the review of the last finished hand; shown after the reveal. */
  onReview?: () => void;
}

/** Within this much, a guess counts as close: a tenth of each slider's range. */
const CLOSE = { risk: 10, bluffPct: 6 };

function verdict(r: MysteryReveal): string {
  const risk = r.off.risk <= CLOSE.risk;
  const bluff = r.off.bluff_pct <= CLOSE.bluffPct;
  if (risk && bluff) return "A sharp read: close on both.";
  if (risk) return "Close on Risk, further off on Bluff.";
  if (bluff) return "Close on Bluff, further off on Risk.";
  return "Not close this time. The review now shows the bot's reasons.";
}

/** "Guess the bot": two sliders for the hidden Risk and Bluff, then the real settings and how far off each guess was. */
export function MysteryGuess({ reveal, sending, error, onGuess, onClose, onReview }: Props) {
  const [risk, setRisk] = useState(50);
  const [bluffPct, setBluffPct] = useState(30);

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
              The server picked this bot's Risk and Bluff at random. From how it played, what do you think they are? You get one guess.
            </p>
            <div className={styles.guessSliders}>
              <BotSlider
                label="Risk"
                value={risk}
                max={RISK_MAX}
                shown={String(risk)}
                help="High Risk folds more to big bets; low Risk calls more."
                onChange={setRisk}
              />
              <BotSlider
                label="Bluff"
                value={bluffPct}
                max={BLUFF_PCT_MAX}
                shown={`${bluffPct}%`}
                help="The share of bluffs in the hands it bets on the river."
                onChange={setBluffPct}
              />
            </div>
            {error && (
              <p className="engine-error" role="alert">
                {error}
              </p>
            )}
            <div className="modal-actions">
              <button className="btn btn-primary" onClick={() => onGuess(risk, bluffPct)} disabled={sending}>
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
                  <td>{reveal.guess.risk}</td>
                  <td>{reveal.risk}</td>
                  <td>{reveal.off.risk}</td>
                </tr>
                <tr>
                  <th>Bluff</th>
                  <td>{reveal.guess.bluff_pct}%</td>
                  <td>{reveal.bluff_pct}%</td>
                  <td>{reveal.off.bluff_pct} points</td>
                </tr>
              </tbody>
            </table>
            <p className="muted">Nothing is hidden now: the review and the bot's reasons show the real settings.</p>
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
