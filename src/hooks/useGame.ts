import { useCallback, useEffect, useRef, useState } from "react";
import { type Action, type DealtHand, type HandState, type LegalActions, type Session, evaluate, randomGameSeed } from "@/engine";
import type { LeanCommand, LeanEvent, LeanReply, LeanState } from "@/lean/protocol";
import { cardText, chips } from "@/lib/format";
import { HUMAN_COLOR, PLAYABLE_OPPONENTS, type Opponent } from "@/lib/roster";

/**
 * Runs a game against the Lean game program. Every rule decision (dealing, which moves are
 * legal, the bot's moves, who wins) is made in Lean and arrives through `/api/game`.
 * This file only sends the human's clicks and turns Lean's replies into what the table
 * components draw. The TypeScript engine is used only for its types and to name the
 * hands at showdown ("Two Pair, Kings and Fives"), which is display only.
 */

/** Heads-up table rules, fixed for the whole game. They are set in Lean (Spec/Basics.lean). */
export const TABLE = { startingStack: 500, smallBlind: 5, bigBlind: 10 } as const;

export interface GameSettings {
  /** Index into PLAYABLE_OPPONENTS of the AI player. */
  opponent: number;
  /** Game seed to replay; null deals a new random game. */
  seed: bigint | null;
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
  /** Every hand's cards follow from this seed, in the Lean engine. */
  seed: bigint;
  /** Seat 0 is the human, seat 1 the bot. Same numbering as Lean's players. */
  players: Player[];
  /** Lean's latest reply. */
  lean: LeanState;
  /** Lean's reply, in the shape the table components draw. */
  session: Session;
  dealt: DealtHand;
  /** The human's moves, from Lean. Null when it is not the human's turn. */
  legal: LegalActions | null;
  /** Board size before the latest reply, so the table can stagger an all-in run-out. */
  boardBefore: number;
  /** Hand history, one line per event. Not shown on screen; kept for testing and checking games afterwards. */
  log: string[];
  stats: Stats;
}

export type Status = "playing" | "handOver" | "gameOver";

declare global {
  interface Window {
    /** The current game's hand history. Read it in the browser console, e.g. `copy(__holdemLog.join("\n"))`. */
    __holdemLog?: string[];
  }
}

export const HUMAN_SEAT = 0;
const BOT_SEAT = 1;
/** Oldest lines are dropped beyond this, so a very long session can't grow without bound. */
const LOG_LIMIT = 5000;

async function sendToLean(command: LeanCommand): Promise<LeanReply> {
  const response = await fetch("/api/game", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(command),
  });
  return (await response.json()) as LeanReply;
}

/** Lean's reply as a hand the table components can draw. */
function toHandState(s: LeanState, names: string[]): HandState {
  const showdown = s.result?.showdown ?? false;
  const players = s.players.map((p, i) => ({
    id: String(i),
    name: names[i]!,
    stack: p.stack,
    // Hidden cards (the bot's, before a showdown) are drawn face down.
    hole: p.cards ?? [],
    streetBet: p.bet,
    // Lean keeps one pot for earlier rounds; each player put in half of it (bets are matched
    // before they are collected).
    totalBet: p.bet + s.pot / 2,
    folded: p.folded,
    allIn: p.allIn,
    hasActed: false,
    mayRaise: true,
    lastAction: p.lastAction,
  }));
  const result = s.result && {
    showdown,
    pots: [
      {
        amount: s.result.winnings[0] + s.result.winnings[1],
        eligible: players.flatMap((p, i) => (p.folded ? [] : [i])),
        winners: s.result.winnings.flatMap((w, i) => (w > 0 ? [i] : [])),
      },
    ],
    winnings: [...s.result.winnings],
    // Hand names for display only; Lean already decided the winner.
    hands: s.players.map((p) => (showdown && p.cards ? evaluate([...p.cards, ...s.board]) : null)),
  };
  return {
    config: { smallBlind: TABLE.smallBlind, bigBlind: TABLE.bigBlind },
    players,
    button: s.button,
    smallBlindSeat: s.button,
    bigBlindSeat: 1 - s.button,
    deck: [],
    board: s.board,
    street: s.street,
    toAct: s.toAct,
    currentBet: s.currentBet,
    minRaise: s.minRaise,
    events: [],
    result,
  };
}

function streetName(street: string) {
  return street[0]!.toUpperCase() + street.slice(1);
}

/** Turns Lean's events into readable log lines. */
function describeEvents(events: readonly LeanEvent[], names: string[]): string[] {
  return events.map((e): string => {
    const name = "player" in e ? names[e.player]! : "";
    const verb = (base: string) => (name === "You" ? base : `${base}s`);
    switch (e.type) {
      case "blind":
        return `${name} ${verb("post")} the ${e.kind} blind (${chips(e.amount)})`;
      case "street":
        return `${streetName(e.street)}  ${e.cards.map(cardText).join(" ")}`;
      case "win":
        return `${name} ${verb("win")} ${chips(e.amount)}`;
      case "action": {
        const allIn = e.allIn ? " (all-in)" : "";
        if (e.action === "raise") return `${name} ${verb("raise")} to ${chips(e.to ?? 0)}${allIn}`;
        if (e.action === "call") return `${name} ${verb("call")} ${chips(e.amount)}${allIn}`;
        return `${name} ${verb(e.action)}`;
      }
    }
  });
}

function appendLog(log: string[], entries: string[]): string[] {
  const next = log.concat(entries);
  return next.length > LOG_LIMIT ? next.slice(next.length - LOG_LIMIT) : next;
}

/** The game after a reply from Lean. `previous` is null for a new game. */
function withReply(base: Omit<Game, "lean" | "session" | "dealt" | "legal" | "boardBefore">, previous: Game | null, s: LeanState): Game {
  const names = base.players.map((p) => p.name);
  const newHand = !previous || previous.lean.hand !== s.hand;
  const header = newHand ? [`Hand #${s.hand}`] : [];
  // Count the hand once, when its result first arrives.
  const justEnded = s.result !== null && (newHand || previous.lean.result === null);
  const won = s.result?.winnings[HUMAN_SEAT] ?? 0;
  const stats = justEnded
    ? {
        handsPlayed: base.stats.handsPlayed + 1,
        handsWon: base.stats.handsWon + (won > 0 ? 1 : 0),
        biggestPot: Math.max(base.stats.biggestPot, won),
      }
    : base.stats;
  return {
    ...base,
    lean: s,
    session: {
      seats: s.players.map((p, i) => ({ id: String(i), name: names[i]!, stack: p.stack })),
      button: s.button,
      handNumber: s.hand,
      config: { smallBlind: TABLE.smallBlind, bigBlind: TABLE.bigBlind },
    },
    dealt: { hand: toHandState(s, names), seatOf: [HUMAN_SEAT, BOT_SEAT] },
    legal: s.legal,
    boardBefore: newHand ? 0 : previous.lean.board.length,
    log: appendLog(base.log, [...header, ...describeEvents(s.events, names)]),
    stats,
  };
}

export function gameStatus(game: Game): Status {
  return game.lean.status;
}

/** Runs a table against the Lean game program: deals hands, asks Lean for the bot's moves after a short pause, and sends the human's moves. */
export function useGame() {
  const [game, setGame] = useState<Game | null>(null);
  const [error, setError] = useState<string | null>(null);
  const gameRef = useRef(game);
  gameRef.current = game;
  // One request at a time; replies to an abandoned game are ignored.
  const busy = useRef(false);
  const generation = useRef(0);

  /** Send a command and apply Lean's reply. `make` builds the next game from the reply. */
  const request = useCallback(async (command: LeanCommand, make: (s: LeanState) => Game) => {
    if (busy.current) return;
    busy.current = true;
    const gen = generation.current;
    try {
      const reply = await sendToLean(command);
      if (gen !== generation.current) return;
      if ("ok" in reply) {
        setError(null);
        setGame(make(reply.state));
      } else {
        setError(reply.error);
      }
    } catch (e) {
      if (gen === generation.current) setError(`Could not reach the game engine: ${e instanceof Error ? e.message : String(e)}`);
    } finally {
      busy.current = false;
    }
  }, []);

  const start = useCallback(
    (settings: GameSettings) => {
      generation.current++;
      busy.current = false;
      const opponent = PLAYABLE_OPPONENTS[settings.opponent] ?? PLAYABLE_OPPONENTS[0]!;
      const players: Player[] = [
        { name: "You", color: HUMAN_COLOR, opponent: null },
        { name: opponent.name, color: opponent.color, opponent },
      ];
      const seed = settings.seed ?? randomGameSeed();
      const base = { settings, seed, players, log: [], stats: { handsPlayed: 0, handsWon: 0, biggestPot: 0 } };
      void request({ cmd: "new_game", seed: seed.toString() }, (s) => withReply(base, null, s));
    },
    [request],
  );

  const humanAct = useCallback(
    (action: Action) => {
      const g = gameRef.current;
      if (!g || g.lean.toAct !== HUMAN_SEAT || g.lean.status !== "playing") return;
      const command: LeanCommand = action.type === "raise" ? { cmd: "act", action: "raise", amount: action.to } : { cmd: "act", action: action.type };
      void request(command, (s) => withReply(g, g, s));
    },
    [request],
  );

  const nextHand = useCallback(() => {
    const g = gameRef.current;
    if (!g || g.lean.status !== "handOver") return;
    void request({ cmd: "next_hand" }, (s) => withReply(g, g, s));
  }, [request]);

  const quit = useCallback(() => {
    generation.current++;
    busy.current = false;
    setError(null);
    setGame(null);
  }, []);

  // The hand history isn't shown on screen; expose it for testing.
  const log = game?.log;
  useEffect(() => {
    window.__holdemLog = log ?? [];
  }, [log]);

  // The bot's turn: wait a moment so the table feels alive, then ask Lean for its move.
  const lean = game?.lean;
  useEffect(() => {
    const g = gameRef.current;
    if (!g || !lean || lean.status !== "playing" || lean.toAct !== BOT_SEAT) return;
    const newStreet = g.boardBefore !== lean.board.length;
    const base = g.settings.fast ? 350 : 800;
    const delay = base + Math.random() * base * 0.6 + (newStreet ? base * 0.6 : 0);
    const timer = window.setTimeout(() => {
      const current = gameRef.current;
      if (!current || current.lean !== lean) return;
      void request({ cmd: "bot" }, (s) => withReply(current, current, s));
    }, delay);
    return () => window.clearTimeout(timer);
  }, [lean, request]);

  return { game, error, start, humanAct, nextHand, quit };
}
