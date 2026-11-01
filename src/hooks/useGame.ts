import { useCallback, useEffect, useRef, useState } from "react";
import { type Action, type DealtHand, type HandState, type LegalActions, type Session } from "@/engine";
import type { ApiReply, LeanCommand, LeanEvent, LeanReview, LeanState } from "@/lean/protocol";
import { cardText, chips } from "@/lib/format";
import { HUMAN_COLOR, botFor } from "@/lib/roster";

/**
 * Runs a game against the Lean game program. Every rule decision (dealing, which moves are
 * legal, the bot's moves, who wins, the review grades) is made in Lean and arrives through `/api/game`.
 * This file only sends the human's clicks and turns Lean's replies into what the table
 * components draw. The TypeScript engine is used only for its types; hand names and the
 * winning five cards come from Lean too (`handName`, `bestCards`).
 */

/** Heads-up table rules, fixed for the whole game. They are set in Lean (Spec/Basics.lean). */
export const TABLE = { startingStack: 500, smallBlind: 5, bigBlind: 10 } as const;

export interface GameSettings {
  /** How heavily the bot weighs a lost chip when deciding to call, 0 to 100. */
  risk: number;
  /** Target bluff share in the bot's defined river betting range, 0 to 60 (percent). */
  bluffPct: number;
  /** Game seed to replay; null deals a new random game. */
  seed: bigint | null;
  fast: boolean;
}

export interface Player {
  name: string;
  color: string;
}

export interface Stats {
  handsPlayed: number;
  handsWon: number;
  biggestPot: number;
}

export interface Game {
  settings: GameSettings;
  /** Known for an entered replay, or revealed by the server once the game ends. */
  seed: bigint | null;
  /** Seat 0 is the human, seat 1 the bot. Same numbering as Lean's players. */
  players: Player[];
  /** Lean's latest reply. */
  lean: LeanState;
  /** Lean's reply, in the shape the table components draw. */
  session: Session;
  dealt: DealtHand;
  /** The human's moves, from Lean. Null when it is not the human's turn. */
  legal: LegalActions | null;
  /** The bot's last move in the latest reply, in generic words ("Bot raises to 60"). Null if it did not move. */
  botLine: string | null;
  /** Board size before the latest reply, so the table can stagger an all-in run-out. */
  boardBefore: number;
  /** Hand history, one line per event. Not shown on screen; kept for testing and checking games afterwards. */
  log: string[];
  stats: Stats;
  /**
   * Why the game is gone (the engine stopped, hung or restarted), or null while it is live.
   * A lost game shows only this message and a way back to the setup screen.
   */
  lost: string | null;
  /**
   * True when the latest reply was asked for with "Peek at bot's cards" on. The bot's cards it
   * shows before a showdown are there only because of the peek, so the table marks them.
   */
  peeked: boolean;
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

async function sendToLean(command: LeanCommand): Promise<ApiReply> {
  const response = await fetch("/api/game", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(command),
  });
  return (await response.json()) as ApiReply;
}

/** How long the bot "thinks" before its moves appear, in milliseconds. Display only: Lean already chose the moves. */
function thinkTime(fast: boolean, newStreet: boolean): number {
  const base = fast ? 350 : 800;
  return base + Math.random() * base * 0.6 + (newStreet ? base * 0.6 : 0);
}

function botMoved(events: readonly LeanEvent[]): boolean {
  return events.some((e) => e.type === "action" && e.player === BOT_SEAT);
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
    // Hand names and best cards come from Lean (game.lean.players); none are computed here.
    hands: s.players.map(() => null),
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

/**
 * Turns Lean's events into readable log lines. `startBet` is the round's highest bet before
 * these events, so the first chips of a round read as a bet ("Bot bets 40"), not a raise.
 */
function describeEvents(events: readonly LeanEvent[], names: string[], startBet: number): string[] {
  let roundBet = startBet;
  return events.map((e): string => {
    const name = "player" in e ? names[e.player]! : "";
    const verb = (base: string) => (name === "You" ? base : `${base}s`);
    switch (e.type) {
      case "blind":
        roundBet = Math.max(roundBet, e.amount);
        return `${name} ${verb("post")} the ${e.kind} blind (${chips(e.amount)})`;
      case "street":
        roundBet = 0;
        return `${streetName(e.street)}  ${e.cards.map(cardText).join(" ")}`;
      case "win":
        return `${name} ${verb("win")} ${chips(e.amount)}`;
      case "action": {
        const allIn = e.allIn ? " (all-in)" : "";
        if (e.action === "raise") {
          const opening = roundBet === 0;
          roundBet = e.to ?? roundBet;
          return opening ? `${name} ${verb("bet")} ${chips(e.to ?? 0)}${allIn}` : `${name} ${verb("raise")} to ${chips(e.to ?? 0)}${allIn}`;
        }
        if (e.action === "call") return `${name} ${verb("call")} ${chips(e.amount)}${allIn}`;
        return `${name} ${verb(e.action)}`;
      }
    }
  });
}

/** The line for the bot's last move among `events`; `lines` are the events' descriptions, in order. */
function lastBotLine(events: readonly LeanEvent[], lines: string[]): string | null {
  for (let i = events.length - 1; i >= 0; i--) {
    const e = events[i]!;
    if (e.type === "action" && e.player === BOT_SEAT) return lines[i]!;
  }
  return null;
}

function appendLog(log: string[], entries: string[]): string[] {
  const next = log.concat(entries);
  return next.length > LOG_LIMIT ? next.slice(next.length - LOG_LIMIT) : next;
}

/** The game after a reply from Lean. `previous` is null for a new game. */
function withReply(base: Omit<Game, "lean" | "session" | "dealt" | "legal" | "botLine" | "boardBefore" | "lost" | "peeked">, previous: Game | null, s: LeanState): Game {
  const names = base.players.map((p) => p.name);
  const newHand = !previous || previous.lean.hand !== s.hand;
  const header = newHand ? [`Hand #${s.hand}`] : [];
  const lines = describeEvents(s.events, names, newHand ? 0 : previous.lean.currentBet);
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
    seed: s.seed === null ? base.seed : BigInt(s.seed),
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
    botLine: lastBotLine(s.events, lines),
    log: appendLog(base.log, [...header, ...lines]),
    stats,
    lost: null,
    peeked: false,
  };
}

/** The game with the bot's cards hidden again, after "Peek at bot's cards" was turned off. */
function withoutBotCards(g: Game): Game {
  const [human, bot] = g.lean.players;
  const lean: LeanState = { ...g.lean, players: [human, { ...bot, cards: null }] };
  const players = g.dealt.hand.players.map((p, i) => (i === BOT_SEAT ? { ...p, hole: [] } : p));
  return { ...g, lean, dealt: { ...g.dealt, hand: { ...g.dealt.hand, players } }, peeked: false };
}

/**
 * A game built from a reply, with the peek toggle applied. `asked`: the command asked to peek.
 * `on`: the toggle now. If it was turned off while the reply was on its way, the bot's cards
 * the reply carries are dropped.
 */
function withPeek(g: Game, asked: boolean, on: boolean): Game {
  return asked && !on ? withoutBotCards(g) : { ...g, peeked: asked };
}

export function gameStatus(game: Game): Status {
  return game.lean.status;
}

/** Runs a table against the Lean game program: sends the human's moves and shows Lean's replies, which include the bot's moves. */
export function useGame() {
  const [game, setGame] = useState<Game | null>(null);
  const [error, setError] = useState<string | null>(null);
  /** True from sending a human move until Lean's reply is shown: the bot is "thinking". */
  const [thinking, setThinking] = useState(false);
  /** The review of the finished hand, once asked for. */
  const [review, setReview] = useState<LeanReview | null>(null);
  /** "Peek at bot's cards": off by default, and off again at the start of every game. */
  const [peek, setPeekState] = useState(false);
  const peekRef = useRef(false);
  /** Hands during which the peek toggle was on while the hand was played. The review marks them. */
  const [peekedHands, setPeekedHands] = useState<number[]>([]);
  const gameRef = useRef(game);
  gameRef.current = game;
  // One request at a time; replies to an abandoned game are ignored.
  const busy = useRef(false);
  const generation = useRef(0);
  /** A refresh of the table (after the peek toggle changed) waits for the request on its way. */
  const refreshPending = useRef(false);
  const refreshRef = useRef<() => void>(() => {});

  const markPeeked = useCallback((s: LeanState) => {
    if (s.status === "playing") setPeekedHands((hands) => (hands.includes(s.hand) ? hands : [...hands, s.hand]));
  }, []);

  /** The request on its way is done: allow the next one, and run a refresh that was waiting. */
  const release = useCallback(() => {
    busy.current = false;
    if (refreshPending.current) {
      refreshPending.current = false;
      refreshRef.current();
    }
  }, []);

  /** Show an error reply. If it says the game is gone, the table offers only a new game. */
  const failed = useCallback((reply: { error: string; lost?: true }) => {
    if (reply.lost && gameRef.current) {
      setError(null);
      setReview(null);
      setGame((g) => g && { ...g, lost: reply.error });
    } else {
      setError(reply.error);
    }
  }, []);

  /** Send a command and apply Lean's reply. `make` builds the next game from the reply.
   * With `pause` (the human's moves), the human cannot act from the moment the move is sent,
   * and a reply in which the bot moved is held back until the bot has "thought" that long,
   * counting the time Lean took. */
  const request = useCallback(async (command: LeanCommand, make: (s: LeanState) => Game, pause?: (s: LeanState) => number) => {
    if (busy.current) return;
    busy.current = true;
    const gen = generation.current;
    const sent = Date.now();
    const asked = peekRef.current;
    if (pause) setThinking(true);
    try {
      const reply = await sendToLean(asked ? { ...command, peek: true } : command);
      if (gen !== generation.current) return;
      if ("ok" in reply) {
        setError(null);
        const wait = pause && botMoved(reply.state.events) ? pause(reply.state) - (Date.now() - sent) : 0;
        if (wait > 0) {
          await new Promise((resolve) => window.setTimeout(resolve, wait));
          if (gen !== generation.current) return;
        }
        setGame(withPeek(make(reply.state), asked, peekRef.current));
        if (peekRef.current) markPeeked(reply.state);
      } else {
        failed(reply);
      }
    } catch (e) {
      if (gen === generation.current) setError(`Could not reach the game engine: ${e instanceof Error ? e.message : String(e)}`);
    } finally {
      if (gen === generation.current) {
        setThinking(false);
        release();
      }
    }
  }, [failed, markPeeked, release]);

  /** Ask Lean for the table again, with or without the bot's cards. It changes nothing in the game. */
  const refresh = useCallback(() => {
    const g = gameRef.current;
    if (!g || g.lost !== null) return;
    if (busy.current) {
      refreshPending.current = true;
      return;
    }
    void request({ cmd: "state" }, (s) => {
      const now = gameRef.current ?? g;
      return withReply(now, now, s);
    });
  }, [request]);
  refreshRef.current = refresh;

  /** Turn "Peek at bot's cards" on or off. Turning it off hides cards already shown, at once. */
  const setPeek = useCallback(
    (on: boolean) => {
      peekRef.current = on;
      setPeekState(on);
      const g = gameRef.current;
      if (!g || g.lost !== null) return;
      if (on) markPeeked(g.lean);
      else if (g.peeked) {
        const hidden = withoutBotCards(g);
        gameRef.current = hidden;
        setGame(hidden);
      }
      refresh();
    },
    [markPeeked, refresh],
  );

  const resetPeek = useCallback(() => {
    peekRef.current = false;
    setPeekState(false);
    setPeekedHands([]);
    refreshPending.current = false;
  }, []);

  const start = useCallback(
    (settings: GameSettings) => {
      generation.current++;
      busy.current = false;
      setThinking(false);
      setReview(null);
      resetPeek();
      const players: Player[] = [
        { name: "You", color: HUMAN_COLOR },
        botFor(settings.risk, settings.bluffPct),
      ];
      const seed = settings.seed;
      const base = { settings, seed, players, log: [], stats: { handsPlayed: 0, handsWon: 0, biggestPot: 0 } };
      void request({ cmd: "new_game", seed: seed?.toString() ?? "", risk: settings.risk, bluff_pct: settings.bluffPct }, (s) =>
        withReply(base, null, s),
      );
    },
    [request, resetPeek],
  );

  const humanAct = useCallback(
    (action: Action) => {
      const g = gameRef.current;
      if (!g || g.lost !== null || g.lean.toAct !== HUMAN_SEAT || g.lean.status !== "playing") return;
      const command: LeanCommand = action.type === "raise" ? { cmd: "act", action: "raise", amount: action.to } : { cmd: "act", action: action.type };
      void request(
        command,
        (s) => withReply(g, g, s),
        (s) => thinkTime(g.settings.fast, s.board.length !== g.lean.board.length),
      );
    },
    [request],
  );

  const nextHand = useCallback(() => {
    const g = gameRef.current;
    if (!g || g.lost !== null || g.lean.status !== "handOver") return;
    setReview(null);
    void request({ cmd: "next_hand" }, (s) => withReply(g, g, s));
  }, [request]);

  /** Ask Lean to grade the finished hand. A review changes nothing in the game. */
  const openReview = useCallback(async () => {
    const g = gameRef.current;
    if (!g || g.lost !== null || g.lean.status === "playing" || busy.current) return;
    const hand = g.lean.hand;
    const gen = generation.current;
    // Hold other commands (like Next Hand) until the review is back, so it cannot open over a new hand.
    busy.current = true;
    try {
      const response = await fetch("/api/game", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ cmd: "review", hand } satisfies LeanCommand),
      });
      const reply = (await response.json()) as ApiReply;
      if (gen !== generation.current || gameRef.current?.lean.hand !== hand) return;
      if ("ok" in reply && reply.review) {
        setError(null);
        setReview(reply.review);
      } else if ("ok" in reply) {
        setError("The game engine sent no review.");
      } else {
        failed(reply);
      }
    } catch (e) {
      if (gen === generation.current) setError(`Could not reach the game engine: ${e instanceof Error ? e.message : String(e)}`);
    } finally {
      if (gen === generation.current) release();
    }
  }, [failed, release]);

  const closeReview = useCallback(() => setReview(null), []);

  const quit = useCallback(() => {
    generation.current++;
    busy.current = false;
    setThinking(false);
    setReview(null);
    setError(null);
    resetPeek();
    setGame(null);
  }, [resetPeek]);

  // The hand history isn't shown on screen; expose it for testing.
  const log = game?.log;
  useEffect(() => {
    window.__holdemLog = log ?? [];
  }, [log]);

  return { game, error, thinking, review, peek, peekedHands, setPeek, start, humanAct, nextHand, openReview, closeReview, quit };
}
