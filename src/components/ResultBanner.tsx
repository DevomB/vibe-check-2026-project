import { type CSSProperties, useEffect } from "react";
import { chips } from "@/lib/format";
import type { Game } from "@/hooks/useGame";

interface Winner {
  name: string;
  amount: number;
  hand: string | null;
}

function winnersOf(game: Game): Winner[] {
  const { hand, seatOf } = game.dealt;
  const result = hand.result;
  if (!result) return [];
  return result.winnings
    .map((amount, i) => ({ amount, name: game.players[seatOf[i]!]!.name, hand: result.hands[i]?.name ?? null }))
    .filter((w) => w.amount > 0)
    .sort((a, b) => b.amount - a.amount);
}

function winText(w: Winner) {
  return `${w.name} ${w.name === "You" ? "win" : "wins"}`;
}

/** Compact "who won" badge shown on the felt where the pot was. */
export function ResultBadge({ game, delay }: { game: Game; delay: number }) {
  const winners = winnersOf(game);
  const youWon = winners.some((w) => w.name === "You");
  const split = game.dealt.hand.result?.pots.some((p) => p.winners.length > 1);
  return (
    <div className={`result-badge ${youWon ? "is-you" : ""}`} style={{ animationDelay: `${delay}s` }}>
      {winners.map((w) => (
        <div key={w.name} className="result-line">
          <span className="result-who">
            {winText(w)} <strong>{chips(w.amount)}</strong>
          </span>
          <span className="result-hand">{w.hand ?? "everyone else folded"}</span>
        </div>
      ))}
      {split && <div className="result-note">Split pot</div>}
    </div>
  );
}

interface BarProps {
  game: Game;
  /** Seconds before the result is shown (an all-in run-out may still be dealing). */
  delay: number;
  gameOver: boolean;
  onNextHand: () => void;
}

/** Replaces the action bar between hands: the result, and a "Next hand" button that fires on its own after a few seconds. */
export function NextHandBar({ game, delay, gameOver, onNextHand }: BarProps) {
  const autoSeconds = game.settings.fast ? 3 : 5;
  const winners = winnersOf(game);
  const youWon = winners.some((w) => w.name === "You");

  useEffect(() => {
    if (gameOver) return;
    const timer = window.setTimeout(onNextHand, (delay + autoSeconds) * 1000);
    return () => window.clearTimeout(timer);
  }, [delay, autoSeconds, gameOver, onNextHand]);

  const headline = winners.map((w) => `${winText(w)} ${chips(w.amount)}`).join(" · ");
  return (
    <div className={`action-bar next-bar ${youWon ? "is-you" : ""}`}>
      <div className="action-info">
        <span className="strength-label">{youWon ? "Nice hand" : "Hand over"}</span>
        <span className="strength-value">{headline}</span>
      </div>
      {!gameOver && (
        <div className="action-buttons">
          <button
            className="btn btn-primary next-btn"
            onClick={onNextHand}
            style={{ "--auto": `${autoSeconds}s`, "--wait": `${delay}s` } as CSSProperties}
          >
            Next hand <kbd>Space</kbd>
            <span className="auto-bar" />
          </button>
        </div>
      )}
    </div>
  );
}
