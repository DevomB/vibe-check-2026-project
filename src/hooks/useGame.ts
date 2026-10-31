import { useCallback, useEffect, useRef, useState } from "react";
import { PERSONALITIES, chooseAction } from "@/ai/bot";
import {
  type Action,
  type DealtHand,
  type HandEvent,
  type Session,
  applyAction,
  createSession,
  cryptoRng,
  dealNextHand,
  settleHand,
} from "@/engine";
import { cardText, chips } from "@/lib/format";
import { HUMAN_COLOR, OPPONENTS, type Opponent } from "@/lib/roster";

export interface GameSettings {
  opponents: number;
  startingStack: number;
  smallBlind: number;
  bigBlind: number;
  fast: boolean;
}

export interface Player {
  name: string;
  color: string;
  /** null for the human. */
  opponent: Opponent | null;
}

export interface Stats {
  handsPlayed: number;
  handsWon: number;
  biggestPot: number;
}

export interface Game {
  settings: GameSettings;
  /** Indexed by session seat; seat 0 is the human. */
  players: Player[];
  session: Session;
  dealt: DealtHand;
  /** Board size before the latest action, so the table can stagger an all-in run-out. */
  boardBefore: number;
  /** Hand history, one line per event. Not shown on screen; kept for testing and checking games afterwards. */
  log: string[];
  stats: Stats;
}

export type Status = "playing" | "handOver" | "gameOver";

declare global {
  interface Window {
    /** The current game's hand history. Read it in the browser console, e.g. `copy(__holdemLog.join("
"))`. */
    __holdemLog?: string[];
  }
}

export const HUMAN_SEAT = 0;
/** Oldest lines are dropped beyond this, so a very long session can't grow without bound. */
const LOG_LIMIT = 5000;

function streetName(street: string) {
  return street[0]!.toUpperCase() + street.slice(1);
}

/** Turns engine events into readable log lines. */
function describeEvents(events: readonly HandEvent[], names: string[], startBet: number): string[] {
  let currentBet = startBet;
  return events.map((e): string => {
    const name = "seat" in e ? names[e.seat]! : "";
    const verb = (base: string) => (name === "You" ? base : `${base}s`);
    switch (e.type) {
      case "blind":
        currentBet = Math.max(currentBet, e.amount);
        return `${name} ${verb("post")} the ${e.kind} blind (${chips(e.amount)})`;
      case "street":
        currentBet = 0;
        return `${streetName(e.street)}  ${e.cards.map(cardText).join(" ")}`;
      case "return":
        return `${chips(e.amount)} uncalled returned to ${name}`;
      case "win":
        return `${name} ${verb("win")} ${chips(e.amount)}${e.hand ? ` with ${e.hand}` : ""}`;
      case "action": {
        const allIn = e.allIn ? " (all-in)" : "";
        switch (e.action.type) {
          case "fold":
            return `${name} ${verb("fold")}`;
          case "check":
            return `${name} ${verb("check")}`;
          case "call":
            return `${name} ${verb("call")} ${chips(e.amount)}${allIn}`;
          case "raise": {
            const text = currentBet === 0 ? `${verb("bet")} ${chips(e.action.to)}` : `${verb("raise")} to ${chips(e.action.to)}`;
            currentBet = e.action.to;
            return `${name} ${text}${allIn}`;
          }
        }
      }
    }
  });
}

function appendLog(log: string[], entries: string[]): string[] {
  const next = log.concat(entries);
  return next.length > LOG_LIMIT ? next.slice(next.length - LOG_LIMIT) : next;
}

function namesFor(game: Pick<Game, "players">, dealt: DealtHand) {
  return dealt.seatOf.map((seat) => game.players[seat]!.name);
}

/** Once a hand has a result, copies the stacks back to the table and updates the stats. */
function settleIfOver(game: Game): Game {
  const { hand, seatOf } = game.dealt;
  if (!hand.result) return game;
  const youIndex = seatOf.indexOf(HUMAN_SEAT);
  const won = youIndex >= 0 ? (hand.result.winnings[youIndex] ?? 0) : 0;
  const { stats } = game;
  return {
    ...game,
    session: settleHand(game.session, game.dealt),
    stats: {
      handsPlayed: stats.handsPlayed + 1,
      handsWon: stats.handsWon + (won > 0 ? 1 : 0),
      biggestPot: Math.max(stats.biggestPot, won),
    },
  };
}

function startNextHand(game: Omit<Game, "dealt" | "boardBefore">): Game {
  const { session, dealt } = dealNextHand(game.session, cryptoRng);
  const header = `Hand #${session.handNumber}`;
  const lines = describeEvents(dealt.hand.events, namesFor(game, dealt), 0);
  // A hand can end while being dealt, when the blinds put everyone all-in.
  return settleIfOver({ ...game, session, dealt, boardBefore: 0, log: appendLog(game.log, [header, ...lines]) });
}

function act(game: Game, action: Action): Game {
  const before = game.dealt.hand;
  const hand = applyAction(before, action);
  const lines = describeEvents(hand.events.slice(before.events.length), namesFor(game, game.dealt), before.currentBet);
  return settleIfOver({
    ...game,
    dealt: { ...game.dealt, hand },
    boardBefore: before.board.length,
    log: appendLog(game.log, lines),
  });
}

export function gameStatus(game: Game): Status {
  if (!game.dealt.hand.result) return "playing";
  const seats = game.session.seats;
  const humanBusted = seats[HUMAN_SEAT]!.stack === 0;
  const othersBusted = seats.every((s, i) => i === HUMAN_SEAT || s.stack === 0);
  return humanBusted || othersBusted ? "gameOver" : "handOver";
}

/** Runs a table: deals hands, lets the AI players act after a short pause, and applies the human's moves. */
export function useGame() {
  const [game, setGame] = useState<Game | null>(null);
  const gameRef = useRef(game);
  gameRef.current = game;

  const start = useCallback((settings: GameSettings) => {
    const opponents = OPPONENTS.slice(0, settings.opponents);
    const players: Player[] = [
      { name: "You", color: HUMAN_COLOR, opponent: null },
      ...opponents.map((o) => ({ name: o.name, color: o.color, opponent: o })),
    ];
    const session = createSession(
      players.map((p, i) => ({ id: String(i), name: p.name, stack: settings.startingStack })),
      { smallBlind: settings.smallBlind, bigBlind: settings.bigBlind },
    );
    setGame(startNextHand({ settings, players, session, log: [], stats: { handsPlayed: 0, handsWon: 0, biggestPot: 0 } }));
  }, []);

  const humanAct = useCallback((action: Action) => {
    const g = gameRef.current;
    if (!g) return;
    const { hand, seatOf } = g.dealt;
    if (hand.toAct === null || seatOf[hand.toAct] !== HUMAN_SEAT) return;
    setGame(act(g, action));
  }, []);

  const nextHand = useCallback(() => {
    const g = gameRef.current;
    if (!g || gameStatus(g) !== "handOver") return;
    setGame(startNextHand(g));
  }, []);

  const quit = useCallback(() => setGame(null), []);

  // The hand history isn't shown on screen; expose it for testing.
  const log = game?.log;
  useEffect(() => {
    window.__holdemLog = log ?? [];
  }, [log]);

  // AI turns: wait a moment so the table feels alive, then act.
  const hand = game?.dealt.hand;
  useEffect(() => {
    const g = gameRef.current;
    if (!g || !hand || hand.toAct === null) return;
    const seat = g.dealt.seatOf[hand.toAct]!;
    const opponent = g.players[seat]!.opponent;
    if (!opponent) return;
    const newStreet = g.boardBefore !== hand.board.length;
    const base = g.settings.fast ? 350 : 800;
    const delay = base + Math.random() * base * 0.6 + (newStreet ? base * 0.6 : 0);
    const timer = window.setTimeout(() => {
      const current = gameRef.current;
      if (!current || current.dealt.hand !== hand) return;
      const action = chooseAction(hand, hand.toAct!, PERSONALITIES[opponent.personality], cryptoRng);
      setGame(act(current, action));
    }, delay);
    return () => window.clearTimeout(timer);
  }, [hand]);

  return { game, start, humanAct, nextHand, quit };
}
