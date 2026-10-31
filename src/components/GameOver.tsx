import { chips } from "@/lib/format";
import type { Stats } from "@/hooks/useGame";

interface Props {
  won: boolean;
  stats: Stats;
  /** Seconds to wait so the last hand's result can be seen first. */
  delay: number;
  onAgain: () => void;
  onLobby: () => void;
}

export function GameOver({ won, stats, delay, onAgain, onLobby }: Props) {
  return (
    <div className="modal-backdrop" style={{ animationDelay: `${delay}s` }}>
      <div className="modal game-over" role="dialog" aria-label="Game over">
        <div className="game-over-icon">{won ? "🏆" : "♠"}</div>
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
            <span>biggest pot</span>
          </div>
        </div>
        <div className="modal-actions">
          <button className="btn btn-primary" onClick={onAgain}>
            Play again
          </button>
          <button className="btn btn-ghost" onClick={onLobby}>
            Change table
          </button>
        </div>
      </div>
    </div>
  );
}
