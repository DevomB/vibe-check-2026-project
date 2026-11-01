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
    .map((amount, i) => ({
      amount,
      name: game.players[seatOf[i]!]!.name,
      // Lean names the hand; after a fold the winner's cards are not part of the result.
      hand: result.showdown ? game.lean.players[seatOf[i]!]!.handName : null,
    }))
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
  const { hand, seatOf } = game.dealt;
  const folders = hand.players.flatMap((p, i) => (p.folded ? [game.players[seatOf[i]!]!.name] : []));
  const foldText = folders.length === 1 ? `${folders[0]} folded` : "everyone else folded";
  return (
    <div className={`result-badge ${youWon ? "is-you" : ""}`} style={{ animationDelay: `${delay}s` }}>
      {winners.map((w) => (
        <div key={w.name} className="result-line">
          <span className="result-who">
            {winText(w)} <strong>{chips(w.amount)}</strong>
          </span>
          <span className="result-hand">{w.hand ?? foldText}</span>
        </div>
      ))}
      {split && <div className="result-note">Split pot</div>}
    </div>
  );
}

interface BarProps {
  game: Game;
  /** Seconds before the result appears (an all-in run-out may still be dealing). */
  delay: number;
  gameOver: boolean;
  onNextHand: () => void;
  onReview: () => void;
}

/** Replaces the action bar between hands. The result stays until the human clicks Next hand; nothing advances on its own. */
export function NextHandBar({ game, delay, gameOver, onNextHand, onReview }: BarProps) {
  const winners = winnersOf(game);
  const youWon = winners.some((w) => w.name === "You");

  const headline = winners.map((w) => `${winText(w)} ${chips(w.amount)}`).join(" · ");
  return (
    <div className={`action-bar next-bar ${youWon ? "is-you" : ""}`} style={{ animationDelay: `${delay}s` }}>
      <div className="action-info">
        <span className="strength-label">{youWon ? "Nice hand" : "Hand over"}</span>
        <span className="strength-value">{headline}</span>
      </div>
      <div className="action-buttons">
        <button className="btn btn-ghost next-btn" onClick={onReview}>
          Review <kbd>R</kbd>
        </button>
        {!gameOver && (
          <button className="btn btn-primary next-btn" onClick={onNextHand}>
            Next hand <kbd>Space</kbd>
          </button>
        )}
      </div>
    </div>
  );
}
