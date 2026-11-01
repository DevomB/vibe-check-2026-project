"use client";

import { useCallback, useEffect, useState } from "react";
import { ActionBar } from "./ActionBar";
import { GameOver } from "./GameOver";
import { Lobby } from "./Lobby";
import { ReviewModal } from "./ReviewModal";
import { RulesModal } from "./RulesModal";
import { ProofsDrawer } from "./ProofsDrawer";
import { NextHandBar } from "./ResultBanner";
import { Table, resultDelay } from "./Table";
import { chips, describeStartingHand } from "@/lib/format";
import { type GameSettings, HUMAN_SEAT, TABLE, gameStatus, useGame } from "@/hooks/useGame";

/**
 * Job 4's two optional ReviewModal props (the contract in its task file). They travel in a
 * spread: before job 4's ReviewModal declares them, TypeScript accepts them and the modal
 * ignores them; once it declares them, TypeScript checks them against these types.
 */
interface ReviewModalExtras {
  /** True while a Mystery game is not yet revealed. */
  hideSliderInfo?: boolean;
  /** Open the Proofs drawer at that guarantee ("review", "bluff" or "risk"). */
  onShowProof?: (id: string) => void;
}

export function PokerApp() {
  const { game, error, thinking, review, peek, peekedHands, setPeek, start, humanAct, nextHand, openReview, closeReview, quit } = useGame();
  const [showRules, setShowRules] = useState(false);
  /** The "What is guaranteed?" drawer: closed (null), or open at a guarantee id (or the top). */
  const [proofs, setProofs] = useState<{ focus: string | null } | null>(null);
  const closeProofs = useCallback(() => setProofs(null), []);
  // The sliders used last, so the setup screen keeps them after leaving a table.
  const [lastSettings, setLastSettings] = useState<GameSettings | undefined>(undefined);
  const status = game ? gameStatus(game) : null;
  const lost = game?.lost ?? null;

  useEffect(() => {
    if (status !== "handOver" || showRules || proofs || review || lost !== null) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.repeat || (e.target instanceof HTMLElement && e.target.closest("button, input, textarea, select, [contenteditable]"))) return;
      if (e.key === " " || e.key === "Enter") {
        e.preventDefault();
        nextHand();
      } else if (e.key === "r" || e.key === "R") {
        e.preventDefault();
        void openReview();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [status, showRules, proofs, review, lost, nextHand, openReview]);

  const begin = (settings: GameSettings) => {
    setLastSettings(settings);
    start(settings);
  };

  const rulesModal = showRules && (
    <RulesModal onClose={() => setShowRules(false)} smallBlind={TABLE.smallBlind} bigBlind={TABLE.bigBlind} />
  );

  const errorBanner = error && (
    <div className="engine-error" role="alert">
      {error}
    </div>
  );

  if (!game) {
    return (
      <div className="app app-lobby">
        <Lobby initial={lastSettings} onStart={begin} onRules={() => setShowRules(true)} />
        {errorBanner}
        {rulesModal}
      </div>
    );
  }

  const { hand, seatOf } = game.dealt;
  const replaySeed = game.seed;
  const youIndex = seatOf.indexOf(HUMAN_SEAT);
  const you = youIndex >= 0 ? hand.players[youIndex]! : null;
  // While the bot "thinks", the previous state stays on screen and the human cannot act.
  const yourTurn = !thinking && hand.toAct !== null && hand.toAct === youIndex;
  const actor = thinking ? game.players[1 - HUMAN_SEAT]! : hand.toAct !== null ? game.players[seatOf[hand.toAct]!]! : null;

  const reviewExtras: ReviewModalExtras = { hideSliderInfo: false, onShowProof: (id) => setProofs({ focus: id }) };

  let strength = "";
  if (you) {
    strength = game.lean.players[HUMAN_SEAT]!.handName ?? describeStartingHand(you.hole);
  }

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          <span className="brand-mark">♠</span>
          <span>Hold'em</span>
        </div>
        <div className="topbar-info">
          <span>
            Hand <b>#{game.session.handNumber}</b>
          </span>
          <span>
            Blinds <b>{TABLE.smallBlind}/{TABLE.bigBlind}</b>
          </span>
          <span>
            Your chips <b>{chips(you?.stack ?? game.session.seats[HUMAN_SEAT]!.stack)}</b>
          </span>
          <span title="The bot's sliders for this game">
            Bot <b>Risk {game.settings.risk} · Bluff {game.settings.bluffPct}%</b>
          </span>
          {replaySeed !== null && (
            <span title="Enter this seed in the lobby to replay the same cards">
              {status === "gameOver" ? "Seed" : "Replay seed"} <b>{replaySeed.toString()}</b>
            </span>
          )}
        </div>
        <div className="topbar-actions">
          <label
            className="peek-toggle"
            title="Show the bot's two cards during the hand. The review still grades your moves as if you could not see them."
          >
            <input type="checkbox" checked={peek} disabled={lost !== null} onChange={(e) => setPeek(e.target.checked)} />
            Peek at bot's cards
          </label>
          <button className="btn btn-ghost btn-sm" onClick={() => setProofs({ focus: null })}>
            What is guaranteed?
          </button>
          <button className="btn btn-ghost btn-sm" onClick={() => setShowRules(true)}>
            How to play
          </button>
          <button className="btn btn-ghost btn-sm" onClick={quit}>
            Leave table
          </button>
        </div>
      </header>

      <main className="layout">
        <div className="play-column">
          <Table game={game} botThinking={thinking} />
          {lost !== null ? (
            <ActionBar hand={hand} legal={null} waiting="Game lost" handStrength={strength} onAct={humanAct} />
          ) : hand.result ? (
            <NextHandBar
              game={game}
              delay={resultDelay(game)}
              gameOver={status === "gameOver"}
              onNextHand={nextHand}
              onReview={() => void openReview()}
            />
          ) : (
            <ActionBar
              hand={hand}
              legal={yourTurn && !showRules && !proofs ? game.legal : null}
              waiting={you?.folded ? "You folded — watching the rest" : actor ? `${actor.name} is thinking…` : ""}
              botMessage={thinking ? null : game.botLine}
              handStrength={strength}
              onAct={humanAct}
            />
          )}
          {errorBanner}
        </div>
      </main>

      {lost !== null && (
        <div className="modal-backdrop">
          <div className="modal game-over" role="alertdialog" aria-label="Game lost">
            <div className="game-over-icon">⚠</div>
            <h2>This game was lost</h2>
            <p className="muted">{lost}</p>
            <div className="modal-actions">
              <button className="btn btn-primary" onClick={quit}>
                New game
              </button>
            </div>
          </div>
        </div>
      )}
      {lost === null && status === "gameOver" && replaySeed !== null && (
        <GameOver
          delay={resultDelay(game) + 1.2}
          won={game.session.seats[HUMAN_SEAT]!.stack > 0}
          stats={game.stats}
          seed={replaySeed}
          replay={{
            risk: game.lean.sliders.risk,
            bluffPct: game.lean.sliders.bluffPct,
            turnMode: game.lean.turnMode,
            engineCommit: game.lean.engineCommit,
            serverCommit: game.lean.serverCommit ?? "unknown",
          }}
          onAgain={() => start({ ...game.settings, seed: null })}
          onReplay={() => start({ ...game.settings, seed: replaySeed })}
          onReview={() => void openReview()}
          onLobby={quit}
        />
      )}
      {review && (
        <ReviewModal {...reviewExtras} review={review} peeked={peekedHands.includes(review.hand)} onClose={closeReview} />
      )}
      {proofs && <ProofsDrawer focus={proofs.focus} onClose={closeProofs} />}
      {rulesModal}
    </div>
  );
}
