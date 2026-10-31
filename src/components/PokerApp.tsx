"use client";

import { useEffect, useState } from "react";
import { evaluate, legalActions } from "@/engine";
import { ActionBar } from "./ActionBar";
import { GameOver } from "./GameOver";
import { Lobby } from "./Lobby";
import { RulesModal } from "./RulesModal";
import { NextHandBar } from "./ResultBanner";
import { Table, resultDelay } from "./Table";
import { chips, describeStartingHand } from "@/lib/format";
import { type GameSettings, HUMAN_SEAT, gameStatus, useGame } from "@/hooks/useGame";

export function PokerApp() {
  const { game, start, humanAct, nextHand, quit } = useGame();
  const [showRules, setShowRules] = useState(false);
  const [lastSettings, setLastSettings] = useState<GameSettings | null>(null);
  const status = game ? gameStatus(game) : null;

  useEffect(() => {
    if (status !== "handOver" || showRules) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.repeat || (e.target instanceof HTMLElement && e.target.closest("button, input, textarea, select, [contenteditable]"))) return;
      if (e.key === " " || e.key === "Enter") {
        e.preventDefault();
        nextHand();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [status, showRules, nextHand]);

  const begin = (settings: GameSettings) => {
    setLastSettings(settings);
    start(settings);
  };

  const rulesModal = showRules && (
    <RulesModal onClose={() => setShowRules(false)} smallBlind={lastSettings?.smallBlind ?? 5} bigBlind={lastSettings?.bigBlind ?? 10} />
  );

  if (!game) {
    return (
      <div className="app app-lobby">
        <Lobby onStart={begin} onRules={() => setShowRules(true)} />
        {rulesModal}
      </div>
    );
  }

  const { hand, seatOf } = game.dealt;
  const youIndex = seatOf.indexOf(HUMAN_SEAT);
  const you = youIndex >= 0 ? hand.players[youIndex]! : null;
  const yourTurn = hand.toAct !== null && hand.toAct === youIndex;
  const actor = hand.toAct !== null ? game.players[seatOf[hand.toAct]!]! : null;

  let strength = "";
  if (you) {
    const shown = hand.result?.hands[youIndex];
    strength = shown ? shown.name : hand.board.length >= 3 ? evaluate([...you.hole, ...hand.board]).name : describeStartingHand(you.hole);
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
            Blinds <b>{game.settings.smallBlind}/{game.settings.bigBlind}</b>
          </span>
          <span>
            Your chips <b>{chips(you?.stack ?? game.session.seats[HUMAN_SEAT]!.stack)}</b>
          </span>
        </div>
        <div className="topbar-actions">
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
          <Table game={game} />
          {hand.result ? (
            <NextHandBar game={game} gameOver={status === "gameOver"} onNextHand={nextHand} />
          ) : (
            <ActionBar
              hand={hand}
              legal={yourTurn && !showRules ? legalActions(hand) : null}
              waiting={you?.folded ? "You folded — watching the rest" : actor ? `${actor.name} is thinking…` : ""}
              handStrength={strength}
              onAct={humanAct}
            />
          )}
        </div>
      </main>

      {status === "gameOver" && (
        <GameOver
          delay={resultDelay(game) + 1.2}
          won={game.session.seats[HUMAN_SEAT]!.stack > 0}
          stats={game.stats}
          onAgain={() => start(game.settings)}
          onLobby={quit}
        />
      )}
      {rulesModal}
    </div>
  );
}
