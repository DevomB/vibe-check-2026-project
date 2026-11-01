import { useCallback, useEffect, useRef, useState } from "react";
import type { Action, DealtHand, HandState, LegalActions, Session } from "@/lib/table";
import type { ApiCommand, LeanCommand, LeanEvent, LeanReview, MysteryReveal, ReviewDecision, RouteReply, RouteState } from "@/lean/protocol";
import { type Challenge, atRiverDecision } from "@/lib/challenges";
import { cardText, chips } from "@/lib/format";
import { CUSTOM_BOT, HUMAN_COLOR, botFor } from "@/lib/roster";

/**
 * Runs a game against the Lean game program. Every rule decision (dealing, which moves are
 * legal, the bot's moves, who wins, the review grades) is made in Lean and arrives through `/api/game`.
 * This file only sends the human's clicks and turns Lean's replies into what the table
 * components draw (types in `@/lib/table`). Hand names and the winning five cards come from
 * Lean too (`handName`, `bestCards`). The TypeScript prototype in src/engine is not used here.
 */

/** Heads-up table rules, fixed for the whole game. They are set in Lean (Spec/Basics.lean). */
export const TABLE = { startingStack: 500, smallBlind: 5, bigBlind: 10 } as const;

export interface GameSettings {
  /** The bot's one setting: its appetite for risk, 0 to 100 (50 is the ideal). Lean derives the rest. */
  risk: number;
  /** Game seed to replay; null deals a new random game. */
  seed: bigint | null;
  fast: boolean;
  /**
   * A Mystery opponent: the server picks Risk and the seed, and hides them until the player
   * guesses. `risk` and `seed` above are then not sent; they only keep the setup screen's
   * slider for next time.
   */
  mystery: boolean;
}

/**
 * What kind of game this is. The kinds never mix: starting any game sets exactly one.
 * - normal: the player set Risk (or picked a named opponent).
 * - practice: a rehearsed hand from `@/lib/challenges`, loaded up to its river decision.
 * - mystery: the server picked the bot's settings and hides them; `reveal` is null until the
 *   player's guess is in. `handsBeforeReveal` counts the hands finished when the guess went in:
 *   the player decided those without knowing the bot's Risk.
 */
export type GameMode =
  | { kind: "normal" }
  | { kind: "practice"; challenge: Challenge }
  | { kind: "mystery"; reveal: MysteryReveal | null; handsBeforeReveal?: number };

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
  mode: GameMode;
  /** Known for an entered replay, or revealed by the server once the game ends. */
  seed: bigint | null;
  /** Seat 0 is the human, seat 1 the bot. Same numbering as Lean's players. */
  players: Player[];
  /** Lean's latest reply, as the route passes it on (an unrevealed Mystery game has no `sliders`). */
  lean: RouteState;
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
  /** Lean's events for the current hand so far, in order. The review's move list is built from them. */
  handEvents: LeanEvent[];
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

/** Lean's grades for one finished hand: the moves it graded, in order. Empty when it graded none. */
export interface HandGrades {
  hand: number;
  decisions: ReviewDecision[];
}

declare global {
  interface Window {
    /** The current game's hand history. Read it in the browser console, e.g. `copy(__holdemLog.join("\n"))`. */
    __holdemLog?: string[];
  }
}

export const HUMAN_SEAT = 0;
const BOT_SEAT = 1;
/** The bot's name and color in a Mystery game: the same for every hidden setting, so they give nothing away. */
const MYSTERY_BOT = { name: "Mystery bot", color: CUSTOM_BOT.color } as const;
/** Oldest lines are dropped beyond this, so a very long session can't grow without bound. */
const LOG_LIMIT = 5000;

/** No reply from the game server: it is stopped or restarting, or it sent a page that is not a reply. */
class NoReplyError extends Error {
  constructor() {
    super("The game server did not send a reply. Check that it is still running, then try again.");
  }
}

/** Send one command through the game server. Throws a NoReplyError if no reply comes back. */
async function sendToLean(command: ApiCommand): Promise<RouteReply> {
  try {
    const response = await fetch("/api/game", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(command),
    });
    return (await response.json()) as RouteReply;
  } catch {
    // The browser's own message ("Failed to fetch") tells the player nothing.
    throw new NoReplyError();
  }
}

/** The message for a request that failed outside Lean: no reply from the server, or a fault in this page. */
function failureText(e: unknown): string {
  if (e instanceof NoReplyError) return e.message;
  return `Something went wrong in this page: ${e instanceof Error ? e.message : String(e)}`;
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
function toHandState(s: RouteState, names: string[]): HandState {
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
    // Hand names and best cards come from Lean (game.lean.players); none are computed here.
    winnings: [...s.result.winnings],
  };
  return {
    players,
    button: s.button,
    board: s.board,
    street: s.street,
    toAct: s.toAct,
    currentBet: s.currentBet,
    minRaise: s.minRaise,
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
export function describeEvents(events: readonly LeanEvent[], names: string[], startBet: number): string[] {
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
function withReply(
  base: Omit<Game, "lean" | "session" | "dealt" | "legal" | "botLine" | "boardBefore" | "handEvents" | "lost" | "peeked">,
  previous: Game | null,
  s: RouteState,
): Game {
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
    // A reply without events (Peek turned on or off, a Mystery reveal) keeps the bot's last move.
    botLine: !newHand && s.events.length === 0 ? previous.botLine : lastBotLine(s.events, lines),
    log: appendLog(base.log, [...header, ...lines]),
    handEvents: newHand ? s.events : previous.handEvents.concat(s.events),
    stats,
    lost: null,
    peeked: false,
  };
}

/** The game with the bot's cards hidden again, after "Peek at bot's cards" was turned off. */
function withoutBotCards(g: Game): Game {
  const [human, bot] = g.lean.players;
  const lean: RouteState = { ...g.lean, players: [human, { ...bot, cards: null }] };
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

/** How many hands of the game are over. */
function handsFinished(g: Game): number {
  return g.lean.result !== null ? g.lean.hand : g.lean.hand - 1;
}

/** True while a Mystery bot is hidden: the server keeps the reviews until the guess. */
function reviewsHidden(g: Game): boolean {
  return g.mode.kind === "mystery" && g.mode.reveal === null;
}

/** Runs a table against the Lean game program: sends the human's moves and shows Lean's replies, which include the bot's moves. */
export function useGame() {
  const [game, setGame] = useState<Game | null>(null);
  const [error, setError] = useState<string | null>(null);
  /** True from sending a human move until Lean's reply is shown: the bot is "thinking". */
  const [thinking, setThinking] = useState(false);
  /** The review of the finished hand, once asked for. */
  const [review, setReview] = useState<LeanReview | null>(null);
  /** The practice challenge being loaded, until its river decision is on the table. */
  const [loading, setLoading] = useState<Challenge | null>(null);
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
  /** Lean's grades for each finished hand, asked for in the background for the result bar and Game Over. */
  const [grades, setGrades] = useState<HandGrades[]>([]);
  /** Hands of this game whose grades were asked for, so each is asked for once. */
  const gradesAsked = useRef(new Set<number>());
  /** The game (its `generation`) whose grading loop is running, or null. */
  const grading = useRef<number | null>(null);

  const markPeeked = useCallback((s: RouteState) => {
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
  const request = useCallback(async (command: ApiCommand, make: (s: RouteState) => Game, pause?: (s: RouteState) => number) => {
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
      if (gen === generation.current) setError(failureText(e));
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

  const resetGrades = useCallback(() => {
    setGrades([]);
    gradesAsked.current = new Set();
  }, []);

  /**
   * Ask Lean for the review of every finished hand not yet asked for, one at a time. Lean answers
   * commands in order, so a burst of reviews (all the hands before a Mystery reveal) would hold
   * up the player's next move and could run past the server's reply timeout. This does not use
   * `busy`, so Next hand never waits for it here.
   */
  const gradeFinishedHands = useCallback(async () => {
    const gen = generation.current;
    if (grading.current === gen) return;
    grading.current = gen;
    try {
      for (;;) {
        const g = gameRef.current;
        if (gen !== generation.current || !g || g.lost !== null || reviewsHidden(g)) return;
        let hand = 1;
        while (gradesAsked.current.has(hand)) hand++;
        if (hand > handsFinished(g)) return;
        gradesAsked.current.add(hand);
        const reply = await sendToLean({ cmd: "review", hand });
        if (gen !== generation.current) return;
        if ("ok" in reply && reply.review) {
          const graded: HandGrades = { hand, decisions: reply.review.decisions.filter((d) => d.label !== null) };
          setGrades((gs) => [...gs, graded].sort((a, b) => a.hand - b.hand));
        }
      }
    } catch {
      // That hand shows no grade. The Review button still says what went wrong.
    } finally {
      if (grading.current === gen) grading.current = null;
    }
  }, []);

  // Grade each hand once it is over; in a Mystery game, once the bot is revealed.
  const finishedCount = game && game.lost === null && !reviewsHidden(game) ? handsFinished(game) : 0;
  useEffect(() => {
    if (finishedCount > 0) void gradeFinishedHands();
  }, [finishedCount, gradeFinishedHands]);

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
      setLoading(null);
      resetPeek();
      resetGrades();
      const players: Player[] = [
        { name: "You", color: HUMAN_COLOR },
        // A preset's name would tell the hidden Risk, so a Mystery bot gets a plain one.
        settings.mystery ? MYSTERY_BOT : botFor(settings.risk),
      ];
      // A Mystery game's seed is private (the server picks it), so none is kept here.
      const seed = settings.mystery ? null : settings.seed;
      const mode: GameMode = settings.mystery ? { kind: "mystery", reveal: null } : { kind: "normal" };
      const base = { settings, mode, seed, players, log: [], stats: { handsPlayed: 0, handsWon: 0, biggestPot: 0 } };
      const command: ApiCommand = settings.mystery
        ? { cmd: "new_game", mystery: true }
        : { cmd: "new_game", seed: seed?.toString() ?? "", risk: settings.risk };
      void request(command, (s) => withReply(base, null, s));
    },
    [request, resetPeek, resetGrades],
  );

  /**
   * Start a practice challenge: a new game with the spot's seed and Risk, then its moves
   * through the normal `act` command, without the bot's "thinking" pauses. The table appears
   * only once Lean's reply is the spot's river decision; if it is not, the challenge stops
   * with an error instead of going on from a different spot.
   */
  const startChallenge = useCallback(
    async (challenge: Challenge, fast: boolean) => {
      generation.current++;
      const gen = generation.current;
      busy.current = true;
      setThinking(false);
      setReview(null);
      setError(null);
      resetPeek();
      resetGrades();
      setGame(null);
      setLoading(challenge);
      const settings: GameSettings = { risk: challenge.risk, seed: BigInt(challenge.seed), fast, mystery: false };
      const mode: GameMode = { kind: "practice", challenge };
      const players: Player[] = [{ name: "You", color: HUMAN_COLOR }, botFor(challenge.risk)];
      const base = { settings, mode, seed: settings.seed, players, log: [], stats: { handsPlayed: 0, handsWon: 0, biggestPot: 0 } };
      let g: Game | null = null;
      try {
        const commands: LeanCommand[] = [
          { cmd: "new_game", seed: challenge.seed, risk: challenge.risk },
          ...challenge.moves.map((m): LeanCommand => ({ cmd: "act", ...m })),
        ];
        for (const command of commands) {
          const reply = await sendToLean(command);
          if (gen !== generation.current) return;
          if (!("ok" in reply)) {
            setError(`The practice hand could not be loaded: ${reply.error}`);
            return;
          }
          g = withReply(g ?? base, g, reply.state);
        }
        if (!g || !atRiverDecision(g.lean)) {
          setError(`"${challenge.title}" did not play out as recorded, so it was stopped before its river decision.`);
          return;
        }
        setGame(g);
      } catch (e) {
        if (gen === generation.current) setError(failureText(e));
      } finally {
        if (gen === generation.current) {
          setLoading(null);
          release();
        }
      }
    },
    [release, resetPeek, resetGrades],
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
      const reply = (await response.json()) as RouteReply;
      if (gen !== generation.current || gameRef.current?.lean.hand !== hand) return;
      if ("ok" in reply && reply.review) {
        setError(null);
        setReview(reply.review);
      } else if ("ok" in reply && reply.reviewDeferred) {
        setError("The review opens after you guess the Mystery bot's settings.");
      } else if ("ok" in reply) {
        setError("The game engine sent no review.");
      } else {
        failed(reply);
      }
    } catch (e) {
      if (gen === generation.current) setError(failureText(e));
    } finally {
      if (gen === generation.current) release();
    }
  }, [failed, release]);

  const closeReview = useCallback(() => setReview(null), []);

  /**
   * Send the player's guess at the Mystery bot's Risk. On success the game shows everything
   * again: the reply has the real Risk and the full state. Returns the server's refusal, or null.
   */
  const reveal = useCallback(
    async (risk: number): Promise<string | null> => {
      const g = gameRef.current;
      if (!g || g.lost !== null || g.mode.kind !== "mystery" || g.mode.reveal !== null) return "There is no Mystery bot to reveal.";
      if (busy.current) return "Wait for the table to finish, then try again.";
      busy.current = true;
      const gen = generation.current;
      const asked = peekRef.current;
      try {
        const command: ApiCommand = { cmd: "reveal", risk };
        const reply = await sendToLean(asked ? { ...command, peek: true } : command);
        if (gen !== generation.current) return null;
        if (!("ok" in reply)) {
          // A refused guess is shown in the guess panel; only a lost game changes the table.
          if (reply.lost) failed(reply);
          return reply.error;
        }
        if (!reply.reveal) return "The server sent no reveal.";
        const now = gameRef.current ?? g;
        const handsBeforeReveal = reply.state.status === "playing" ? reply.state.hand - 1 : reply.state.hand;
        const mode: GameMode = { kind: "mystery", reveal: reply.reveal, handsBeforeReveal };
        const shown = withReply({ ...now, mode }, now, reply.state);
        setError(null);
        setGame(withPeek(shown, asked, peekRef.current));
        return null;
      } catch (e) {
        return failureText(e);
      } finally {
        if (gen === generation.current) release();
      }
    },
    [failed, release],
  );

  const quit = useCallback(() => {
    generation.current++;
    busy.current = false;
    setThinking(false);
    setReview(null);
    setError(null);
    setLoading(null);
    resetPeek();
    resetGrades();
    setGame(null);
  }, [resetPeek, resetGrades]);

  // The hand history isn't shown on screen; expose it for testing.
  const log = game?.log;
  useEffect(() => {
    window.__holdemLog = log ?? [];
  }, [log]);

  return { game, error, thinking, review, loading, grades, peek, peekedHands, setPeek, start, startChallenge, humanAct, nextHand, openReview, closeReview, reveal, quit };
}
