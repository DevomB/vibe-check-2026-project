import type { Card, Rng } from "./cards";
import { type HandConfig, type HandState, startHand } from "./game";

/** A seat at the table that lasts across hands. */
export interface Seat {
  id: string;
  name: string;
  stack: number;
}

/** A table playing hand after hand. */
export interface Session {
  seats: Seat[];
  /** Index into `seats` of the dealer button for the last hand dealt (-1 before the first). */
  button: number;
  handNumber: number;
  config: HandConfig;
}

export interface DealtHand {
  hand: HandState;
  /** `seatOf[i]` is the session seat of hand player i (busted seats are skipped). */
  seatOf: number[];
}

export function createSession(seats: Seat[], config: HandConfig): Session {
  if (seats.some((s) => !Number.isSafeInteger(s.stack) || s.stack < 0) || !Number.isSafeInteger(seats.reduce((sum, s) => sum + s.stack, 0))) {
    throw new Error("Session stacks and their total must be non-negative safe integers");
  }
  return { seats: seats.map((s) => ({ ...s })), button: -1, handNumber: 0, config: { ...config } };
}

/** Seats that still have chips. */
export function activeSeats(session: Session): number[] {
  return session.seats.flatMap((s, i) => (s.stack > 0 ? [i] : []));
}

/** Moves the button to the next seat with chips and deals a hand to everyone with chips.
 * `order`, if given, is the deck in dealing order (see `startHand`). */
export function dealNextHand(session: Session, rng: Rng, order?: readonly Card[]): { session: Session; dealt: DealtHand } {
  const active = activeSeats(session);
  if (active.length < 2) throw new Error("Need at least two players with chips");
  const n = session.seats.length;
  let button = session.button;
  do button = (button + 1) % n;
  while (session.seats[button]!.stack <= 0);

  const hand = startHand(
    active.map((i) => session.seats[i]!),
    active.indexOf(button),
    session.config,
    rng,
    order,
  );
  return {
    session: { ...session, button, handNumber: session.handNumber + 1 },
    dealt: { hand, seatOf: active },
  };
}

/** Copies the finished hand's stacks back to the session's seats. */
export function settleHand(session: Session, dealt: DealtHand): Session {
  if (!dealt.hand.result) throw new Error("The hand is not finished");
  const seats = session.seats.map((s) => ({ ...s }));
  for (const [i, p] of dealt.hand.players.entries()) seats[dealt.seatOf[i]!]!.stack = p.stack;
  return { ...session, seats };
}
