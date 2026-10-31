import { type Card, type Rng, fullDeck, shuffle } from "./cards";
import { type HandValue, evaluate } from "./evaluator";
import { buildPots, splitPot } from "./pots";

/** One no-limit Texas Hold'em hand, as a pure state machine. */

export type Street = "preflop" | "flop" | "turn" | "river" | "showdown";

export interface HandConfig {
  smallBlind: number;
  bigBlind: number;
}

export interface SeatInput {
  id: string;
  name: string;
  stack: number;
}

export interface PlayerState {
  id: string;
  name: string;
  /** Chips not yet in the pot. */
  stack: number;
  hole: Card[];
  /** Chips put in on the current street. */
  streetBet: number;
  /** Chips put in during the whole hand. */
  totalBet: number;
  folded: boolean;
  allIn: boolean;
  /** Acted since the street began or since the last full raise. */
  hasActed: boolean;
  /** False once a short all-in raise reaches a player who had already acted: they may only call or fold. */
  mayRaise: boolean;
  /** Short label of the player's latest move this street, for display ("Check", "Raise to 60", ...). */
  lastAction: string | null;
}

export type Action =
  | { type: "fold" }
  | { type: "check" }
  | { type: "call" }
  /** Bet (when nobody has bet this street) or raise. `to` is the player's total bet for the street. */
  | { type: "raise"; to: number };

export interface LegalActions {
  fold: boolean;
  check: boolean;
  /** Chips needed to call; 0 when there is nothing to call. */
  call: number;
  /** Allowed bet/raise totals for this street, or null if the player cannot raise. */
  raise: { min: number; max: number } | null;
}

export type HandEvent =
  | { type: "blind"; seat: number; amount: number; kind: "small" | "big" }
  | { type: "action"; seat: number; action: Action; amount: number; allIn: boolean }
  | { type: "street"; street: Street; cards: Card[] }
  | { type: "return"; seat: number; amount: number }
  | { type: "win"; seat: number; amount: number; hand: string | null };

export interface PotResult {
  amount: number;
  eligible: number[];
  winners: number[];
}

export interface HandResult {
  /** True if two or more players reached the end and showed their cards. */
  showdown: boolean;
  pots: PotResult[];
  /** Chips won by each seat (0 for losers). */
  winnings: number[];
  /** Each seat's best hand at showdown; null if folded or there was no showdown. */
  hands: (HandValue | null)[];
}

export interface HandState {
  config: HandConfig;
  players: PlayerState[];
  button: number;
  smallBlindSeat: number;
  bigBlindSeat: number;
  deck: Card[];
  board: Card[];
  street: Street;
  /** Seat whose turn it is; null once the hand is over. */
  toAct: number | null;
  /** Highest street bet that others must match. */
  currentBet: number;
  /** Minimum size of the next raise increment. */
  minRaise: number;
  events: HandEvent[];
  result: HandResult | null;
}

export class IllegalActionError extends Error {}

const NEXT_STREET: Record<Exclude<Street, "river" | "showdown">, { street: Street; cards: number }> = {
  preflop: { street: "flop", cards: 3 },
  flop: { street: "turn", cards: 1 },
  turn: { street: "river", cards: 1 },
};

/** Deals a new hand. `seats` are in table order and must all have chips; `button` indexes into them. */
export function startHand(seats: readonly SeatInput[], button: number, config: HandConfig, rng: Rng): HandState {
  const n = seats.length;
  if (n < 2) throw new Error("A hand needs at least two players");
  if (seats.some((s) => s.stack <= 0)) throw new Error("Every seat dealt in must have chips");
  if (button < 0 || button >= n) throw new Error("Button out of range");

  const deck = shuffle(fullDeck(), rng);
  const players: PlayerState[] = seats.map((s) => ({
    id: s.id,
    name: s.name,
    stack: s.stack,
    hole: [],
    streetBet: 0,
    totalBet: 0,
    folded: false,
    allIn: false,
    hasActed: false,
    mayRaise: true,
    lastAction: null,
  }));
  // Two rounds of one card each, starting left of the button.
  for (let round = 0; round < 2; round++) {
    for (let k = 1; k <= n; k++) players[(button + k) % n]!.hole.push(deck.pop()!);
  }

  // Heads-up, the button posts the small blind and acts first before the flop.
  const smallBlindSeat = n === 2 ? button : (button + 1) % n;
  const bigBlindSeat = (smallBlindSeat + 1) % n;

  const state: HandState = {
    config,
    players,
    button,
    smallBlindSeat,
    bigBlindSeat,
    deck,
    board: [],
    street: "preflop",
    toAct: null,
    currentBet: 0,
    minRaise: config.bigBlind,
    events: [],
    result: null,
  };

  postBlind(state, smallBlindSeat, config.smallBlind, "small");
  postBlind(state, bigBlindSeat, config.bigBlind, "big");
  state.currentBet = Math.max(...players.map((p) => p.streetBet));

  state.toAct = findNextToAct(state, bigBlindSeat);
  if (state.toAct === null) finishStreet(state);
  return state;
}

function postBlind(state: HandState, seat: number, amount: number, kind: "small" | "big") {
  const p = state.players[seat]!;
  const paid = putChips(p, amount);
  p.lastAction = kind === "small" ? "SB" : "BB";
  state.events.push({ type: "blind", seat, amount: paid, kind });
}

/** Moves up to `amount` chips from the player's stack into the pot; returns what was paid. */
function putChips(p: PlayerState, amount: number): number {
  const paid = Math.min(amount, p.stack);
  p.stack -= paid;
  p.streetBet += paid;
  p.totalBet += paid;
  if (p.stack === 0) p.allIn = true;
  return paid;
}

function canStillBet(p: PlayerState) {
  return !p.folded && !p.allIn;
}

function needsAction(state: HandState, seat: number): boolean {
  const p = state.players[seat]!;
  if (!canStillBet(p)) return false;
  if (p.streetBet < state.currentBet) return true;
  if (p.hasActed) return false;
  // Bet is matched but the player has not acted: they only need to if someone could answer a raise.
  return state.players.some((q, j) => j !== seat && canStillBet(q));
}

function findNextToAct(state: HandState, after: number): number | null {
  const n = state.players.length;
  for (let k = 1; k <= n; k++) {
    const seat = (after + k) % n;
    if (needsAction(state, seat)) return seat;
  }
  return null;
}

/** What the player whose turn it is may do. */
export function legalActions(state: HandState): LegalActions {
  if (state.toAct === null) return { fold: false, check: false, call: 0, raise: null };
  const p = state.players[state.toAct]!;
  const toCall = Math.min(state.currentBet - p.streetBet, p.stack);
  const opponentCanRespond = state.players.some((q, j) => j !== state.toAct && canStillBet(q));
  const canRaise = p.mayRaise && opponentCanRespond && p.stack > state.currentBet - p.streetBet;
  const max = p.streetBet + p.stack;
  return {
    fold: true,
    check: toCall === 0,
    call: toCall,
    raise: canRaise ? { min: Math.min(state.currentBet + state.minRaise, max), max } : null,
  };
}

/** Applies the current player's action and returns the new state. Throws IllegalActionError if not allowed. */
export function applyAction(state: HandState, action: Action): HandState {
  if (state.toAct === null) throw new IllegalActionError("The hand is over");
  const s = structuredClone(state);
  const seat = s.toAct!;
  const p = s.players[seat]!;
  const legal = legalActions(s);
  let paid = 0;

  switch (action.type) {
    case "fold":
      p.folded = true;
      p.lastAction = "Fold";
      break;
    case "check":
      if (!legal.check) throw new IllegalActionError("Cannot check: there is a bet to call");
      p.lastAction = "Check";
      break;
    case "call":
      if (legal.call === 0) throw new IllegalActionError("Nothing to call");
      paid = putChips(p, legal.call);
      p.lastAction = p.allIn ? "All-in" : "Call";
      break;
    case "raise": {
      if (!legal.raise) throw new IllegalActionError("Cannot raise now");
      const { to } = action;
      if (!Number.isInteger(to) || to < legal.raise.min || to > legal.raise.max) {
        throw new IllegalActionError(`Raise must be between ${legal.raise.min} and ${legal.raise.max}`);
      }
      const wasBet = s.currentBet === 0;
      const increment = to - s.currentBet;
      paid = putChips(p, to - p.streetBet);
      if (increment >= s.minRaise) {
        // A full raise reopens the betting for everyone.
        s.minRaise = increment;
        for (const [j, q] of s.players.entries()) {
          if (j !== seat && canStillBet(q)) {
            q.hasActed = false;
            q.mayRaise = true;
          }
        }
      } else {
        // A short all-in raise: others must respond, but those who already acted may not re-raise.
        for (const [j, q] of s.players.entries()) {
          if (j !== seat && canStillBet(q)) {
            q.mayRaise = q.mayRaise && !q.hasActed;
            q.hasActed = false;
          }
        }
      }
      s.currentBet = to;
      p.lastAction = p.allIn ? "All-in" : wasBet ? `Bet ${to}` : `Raise to ${to}`;
      break;
    }
  }

  p.hasActed = true;
  s.events.push({ type: "action", seat, action, amount: paid, allIn: p.allIn });

  if (s.players.filter((q) => !q.folded).length === 1) {
    awardUncontested(s);
    return s;
  }
  s.toAct = findNextToAct(s, seat);
  if (s.toAct === null) finishStreet(s);
  return s;
}

/** If one player bet more than anyone else could match, give back the unmatched part. */
function returnUncalledBet(s: HandState) {
  const bets = s.players.map((p) => p.streetBet);
  const top = Math.max(...bets);
  const seat = bets.indexOf(top);
  const second = Math.max(0, ...bets.filter((_, j) => j !== seat));
  const refund = top - second;
  if (refund <= 0) return;
  const p = s.players[seat]!;
  p.stack += refund;
  p.streetBet -= refund;
  p.totalBet -= refund;
  p.allIn = p.stack === 0;
  s.events.push({ type: "return", seat, amount: refund });
}

/** Ends the betting round: deals the next street, or goes to showdown after the river. */
function finishStreet(s: HandState) {
  for (;;) {
    returnUncalledBet(s);
    for (const p of s.players) {
      p.streetBet = 0;
      p.hasActed = false;
      p.mayRaise = true;
      if (canStillBet(p)) p.lastAction = null;
    }
    s.currentBet = 0;
    s.minRaise = s.config.bigBlind;

    if (s.street === "river" || s.street === "showdown") {
      showdown(s);
      return;
    }
    const next = NEXT_STREET[s.street];
    s.deck.pop(); // burn card
    const cards = Array.from({ length: next.cards }, () => s.deck.pop()!);
    s.board.push(...cards);
    s.street = next.street;
    s.events.push({ type: "street", street: next.street, cards });

    s.toAct = findNextToAct(s, s.button);
    if (s.toAct !== null) return;
    // Nobody can bet (everyone left is all-in): keep dealing.
  }
}

function awardUncontested(s: HandState) {
  returnUncalledBet(s);
  const winner = s.players.findIndex((p) => !p.folded);
  const amount = s.players.reduce((sum, p) => sum + p.totalBet, 0);
  s.players[winner]!.stack += amount;
  const winnings = s.players.map((_, j) => (j === winner ? amount : 0));
  s.toAct = null;
  s.result = {
    showdown: false,
    pots: [{ amount, eligible: [winner], winners: [winner] }],
    winnings,
    hands: s.players.map(() => null),
  };
  s.events.push({ type: "win", seat: winner, amount, hand: null });
}

function showdown(s: HandState) {
  s.street = "showdown";
  s.toAct = null;
  const hands = s.players.map((p) => (p.folded ? null : evaluate([...p.hole, ...s.board])));
  const pots = buildPots(
    s.players.map((p) => p.totalBet),
    s.players.map((p) => p.folded),
  );
  const winnings = s.players.map(() => 0);
  const potResults: PotResult[] = pots.map((pot) => {
    const best = Math.max(...pot.eligible.map((j) => hands[j]!.score));
    const winners = pot.eligible.filter((j) => hands[j]!.score === best);
    for (const [j, chips] of splitPot(pot.amount, winners, s.button, s.players.length)) {
      winnings[j]! += chips;
    }
    return { amount: pot.amount, eligible: pot.eligible, winners };
  });
  for (const [j, chips] of winnings.entries()) {
    if (chips > 0) {
      s.players[j]!.stack += chips;
      s.events.push({ type: "win", seat: j, amount: chips, hand: hands[j]!.name });
    }
  }
  s.result = { showdown: true, pots: potResults, winnings, hands };
}

/** All chips in the middle: earlier streets plus bets on this one. */
export function potTotal(state: HandState): number {
  return state.players.reduce((sum, p) => sum + p.totalBet, 0);
}
