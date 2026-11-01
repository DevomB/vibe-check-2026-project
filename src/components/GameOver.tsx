import { chips } from "@/lib/format";
import type { HandGrades, Stats } from "@/hooks/useGame";
import { labelCounts } from "@/lib/review";
import { ReviewBadge } from "./ReviewBadge";

interface Props {
  won: boolean;
  stats: Stats;
  /** Lean's grades for the finished hands: none until they are back, and none while a Mystery bot is hidden. */
  grades?: readonly HandGrades[];
  /** Seconds to wait so the last hand's result can be seen first. */
  delay: number;
  /** The game's seed, so it can be replayed. Null while a Mystery bot is not yet revealed. */
  seed: bigint | null;
  /**
   * The rest of the replay record (MVP §5, §15). The same seed, Risk, moves and engine build
   * play the same game again. `sliders` is Lean's, and null while a Mystery bot is not yet revealed.
   */
  replay: { sliders: { risk: number; bluffPct: number } | null; turnMode: string; engineCommit: string; serverCommit: string };
  onAgain: () => void;
  onReplay: () => void;
  onReview: () => void;
  onLobby: () => void;
  /** Set while a Mystery bot is not yet revealed: open the guess panel. The review and the replay wait for the guess. */
  onGuess?: () => void;
}

/** The game's score: how many graded moves were Best or Good, and how many got each label. */
export function GradeTally({ grades }: { grades: readonly HandGrades[] }) {
  const decisions = grades.flatMap((g) => g.decisions);
  if (decisions.length === 0) return null;
  const counts = labelCounts(decisions);
  const sound = counts[0]!.count + counts[1]!.count;
  return (
    <div className="grade-tally" aria-label="Your graded moves">
      <p>
        <b>{sound}</b> of your {decisions.length} graded {decisions.length === 1 ? "move was" : "moves were"} Best or Good
      </p>
      <div className="grade-tally-counts">
        {counts.map(({ info, count }) => (
          <span key={info.key} className={count === 0 ? "muted" : undefined}>
            <ReviewBadge label={info.label} size="sm" /> {count}
          </span>
        ))}
      </div>
    </div>
  );
}

export function GameOver({ won, stats, grades = [], delay, seed, replay, onAgain, onReplay, onReview, onLobby, onGuess }: Props) {
  const hidden = "hidden until you guess";
  return (
    <div className="modal-backdrop" style={{ animationDelay: `${delay}s` }}>
      <div className="modal game-over" role="dialog" aria-label="Game over">
        <h2>{won ? "You took every chip!" : "You're out of chips"}</h2>
        <p className="muted">{won ? "The whole table is yours." : "It happens to the best of us. Deal again?"}</p>
        <div className="stats">
          <div>
            <b>{stats.handsPlayed}</b>
            <span>hands played</span>
          </div>
          <div>
            <b>{stats.handsWon}</b>
            <span>hands won</span>
          </div>
          <div>
            <b>{chips(stats.biggestPot)}</b>
            <span>biggest pot won</span>
          </div>
        </div>
        <GradeTally grades={grades} />
        <div className="modal-actions">
          {onGuess && (
            <button className="btn btn-primary" onClick={onGuess}>
              Guess the bot
            </button>
          )}
          <button className={`btn ${onGuess ? "btn-ghost" : "btn-primary"}`} onClick={onAgain}>
            New game
          </button>
          {seed !== null && (
            <button className="btn btn-ghost" onClick={onReplay}>
              Replay these cards
            </button>
          )}
          {!onGuess && (
            <button className="btn btn-ghost" onClick={onReview}>
              Review last hand
            </button>
          )}
          <button className="btn btn-ghost" onClick={onLobby}>
            Change opponent
          </button>
        </div>
        <div className="replay-record" aria-label="Replay record">
          <span>
            Seed <b>{seed === null ? hidden : seed.toString()}</b>
          </span>
          <span>
            Risk <b>{replay.sliders === null ? hidden : replay.sliders.risk}</b>
          </span>
          <span title="Set by Lean from Risk">
            Bluff share <b>{replay.sliders === null ? hidden : `${replay.sliders.bluffPct}%`}</b>
          </span>
          {/* For checking a replay against a build; folded so the player sees the seed and Risk first. */}
          <details className="replay-details">
            <summary>Replay details</summary>
            <div className="replay-details-row">
              <span>
                Turn mode <b>{replay.turnMode}</b>
              </span>
              <span title="The commit the Lean game program was built from">
                Engine build <b>{replay.engineCommit}</b>
              </span>
              <span title="The commit of the web server's checkout">
                Server checkout <b>{replay.serverCommit}</b>
              </span>
            </div>
          </details>
        </div>
      </div>
    </div>
  );
}
