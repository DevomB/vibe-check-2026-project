import { chips } from "@/lib/format";
import type { Stats } from "@/hooks/useGame";

interface Props {
  won: boolean;
  stats: Stats;
  /** Seconds to wait so the last hand's result can be seen first. */
  delay: number;
  /** The game's seed, so it can be replayed. */
  seed: bigint;
  /**
   * The rest of the replay record (MVP §5, §15). The same seed, sliders, moves and engine
   * build play the same game again.
   */
  replay: { risk: number; bluffPct: number; turnMode: string; engineCommit: string; serverCommit: string };
  onAgain: () => void;
  onReplay: () => void;
  onReview: () => void;
  onLobby: () => void;
}

export function GameOver({ won, stats, delay, seed, replay, onAgain, onReplay, onReview, onLobby }: Props) {
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
            New game
          </button>
          <button className="btn btn-ghost" onClick={onReplay}>
            Replay these cards
          </button>
          <button className="btn btn-ghost" onClick={onReview}>
            Review last hand
          </button>
          <button className="btn btn-ghost" onClick={onLobby}>
            Change sliders
          </button>
        </div>
        <div className="replay-record" aria-label="Replay record">
          <span>
            Seed <b>{seed.toString()}</b>
          </span>
          <span>
            Risk <b>{replay.risk}</b>
          </span>
          <span>
            Bluff <b>{replay.bluffPct}%</b>
          </span>
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
      </div>
    </div>
  );
}
