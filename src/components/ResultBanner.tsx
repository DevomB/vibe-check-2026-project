import { chips } from "@/lib/format";
import type { Game, HandGrades } from "@/hooks/useGame";
import { ReviewBadge } from "./ReviewBadge";

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
  const losingHand = game.lean.result?.outcome === "player0" ? game.lean.players[1].handName
    : game.lean.result?.outcome === "player1" ? game.lean.players[0].handName : null;
  return (
    <div className={`result-badge ${youWon ? "is-you" : ""}`} style={{ animationDelay: `${delay}s` }}>
      {winners.map((w) => (
        <div key={w.name} className="result-line">
          <span className="result-who">
            {winText(w)} <strong>{chips(w.amount)}</strong>
          </span>
          <span className="result-hand">
            {w.hand && losingHand && winners.length === 1 ? `${w.hand} beats ${losingHand}` : w.hand ?? foldText}
          </span>
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
  /** True while Lean grades the hand: the Review button says "Opening…" and waits. */
  reviewOpening?: boolean;
  /** Lean's grades for this hand, once they are back; null until then, and in a hidden Mystery game. */
  grades?: HandGrades | null;
  onNextHand: () => void;
  onReview: () => void;
}

/** The hand's grades in one line: a badge per graded move, in order. */
export function HandGradeLine({ grades }: { grades: HandGrades }) {
  const n = grades.decisions.length;
  if (n === 0) return <span className="hand-grade muted">No graded move</span>;
  return (
    <span className="hand-grade" title="Lean's grade for each of your calls and folds facing a bet. Review shows why.">
      {grades.decisions.map((d, i) => (
        <ReviewBadge key={i} label={d.label!} size="sm" />
      ))}
      <span className="muted">{n === 1 ? "1 graded move" : `${n} graded moves`}</span>
    </span>
  );
}

/** Replaces the action bar between hands. The result is on the felt (`ResultBadge`), so this bar
 * holds the hand's grades, Review and Next hand. The result stays until the human clicks Next hand; nothing
 * advances on its own. */
export function NextHandBar({ delay, gameOver, reviewOpening = false, grades = null, onNextHand, onReview }: BarProps) {
  return (
    <div className="action-bar next-bar" style={{ animationDelay: `${delay}s` }}>
      <div className="action-buttons">
        {grades && <HandGradeLine grades={grades} />}
        <button className="btn btn-ghost next-btn" onClick={onReview} disabled={reviewOpening}>
          {reviewOpening ? (
            "Opening…"
          ) : (
            <>
              Review <kbd>R</kbd>
            </>
          )}
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
