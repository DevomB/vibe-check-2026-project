import { describe, expect, it } from "vitest";
import { type Rng, seededRng } from "./cards";
import { type Action, type HandState, applyAction, legalActions } from "./game";
import { activeSeats, createSession, dealNextHand, settleHand } from "./session";

/** Picks a random legal action, with raises of random legal size. */
function randomAction(state: HandState, rng: Rng): Action {
  const legal = legalActions(state);
  const options: Action[] = [];
  if (legal.check) options.push({ type: "check" }, { type: "check" });
  if (legal.call > 0) options.push({ type: "call" }, { type: "call" }, { type: "fold" });
  if (legal.raise) {
    const { min, max } = legal.raise;
    const to = rng() < 0.2 ? max : min + Math.floor(rng() * (max - min + 1));
    options.push({ type: "raise", to });
  }
  if (rng() < 0.05) options.push({ type: "fold" });
  return options[Math.floor(rng() * options.length)]!;
}

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

/** Checked after every action; plain asserts keep thousands of hands fast. */
function checkInvariants(s: HandState, chipsInHand: number) {
  const onTable = s.players.reduce((sum, p) => sum + p.stack + (s.result ? 0 : p.totalBet), 0);
  assert(onTable === chipsInHand, `chips changed: ${onTable} vs ${chipsInHand}`);
  for (const p of s.players) {
    assert(p.stack >= 0 && p.streetBet >= 0, "negative chips");
    assert(!(p.folded && p.allIn), "folded and all-in");
    if (!s.result && !p.folded) assert(p.allIn === (p.stack === 0), "all-in flag out of sync with stack");
  }
  if (s.toAct !== null) {
    const p = s.players[s.toAct]!;
    assert(!p.folded && !p.allIn, "toAct cannot bet");
    assert(p.streetBet < s.currentBet || !p.hasActed, "toAct has nothing to do");
    assert(s.result === null, "result set while someone is to act");
  } else {
    assert(s.result !== null, "nobody to act but no result");
  }
}

describe("random play", () => {
  it("keeps every rule invariant across thousands of hands", () => {
    const rng = seededRng(2026);
    let hands = 0;
    let showdowns = 0;
    for (let trial = 0; trial < 600; trial++) {
      const n = 2 + Math.floor(rng() * 8);
      const seats = Array.from({ length: n }, (_, i) => ({
        id: `p${i}`,
        name: `P${i}`,
        stack: 1 + Math.floor(rng() * 2000),
      }));
      const bigBlind = 2 * (1 + Math.floor(rng() * 25));
      let session = createSession(seats, { smallBlind: bigBlind / 2, bigBlind });
      const sessionChips = seats.reduce((sum, s) => sum + s.stack, 0);

      for (let k = 0; k < 6 && activeSeats(session).length >= 2; k++) {
        const { session: next, dealt } = dealNextHand(session, rng);
        session = next;
        let hand = dealt.hand;
        const chipsInHand = dealt.seatOf.reduce((sum, i) => sum + session.seats[i]!.stack, 0);
        checkInvariants(hand, chipsInHand);

        let steps = 0;
        while (hand.toAct !== null) {
          hand = applyAction(hand, randomAction(hand, rng));
          checkInvariants(hand, chipsInHand);
          assert(++steps < 200, "hand did not end");
        }

        const result = hand.result!;
        expect(result.winnings.reduce((a, b) => a + b, 0)).toBe(hand.players.reduce((sum, p) => sum + p.totalBet, 0));
        expect(result.pots.reduce((sum, pot) => sum + pot.amount, 0)).toBe(result.winnings.reduce((a, b) => a + b, 0));
        if (result.showdown) {
          showdowns++;
          expect(hand.board.length).toBe(5);
          expect(hand.street).toBe("showdown");
          for (const pot of result.pots) {
            expect(pot.winners.length).toBeGreaterThan(0);
            for (const w of pot.winners) expect(pot.eligible).toContain(w);
          }
        } else {
          expect(hand.players.filter((p) => !p.folded).length).toBe(1);
        }
        // No card is dealt twice.
        const cards = [...hand.board, ...hand.players.flatMap((p) => p.hole), ...hand.deck];
        expect(new Set(cards).size).toBe(cards.length);

        session = settleHand(session, { ...dealt, hand });
        expect(session.seats.reduce((sum, s) => sum + s.stack, 0)).toBe(sessionChips);
        hands++;
      }
    }
    expect(hands).toBeGreaterThan(2000);
    expect(showdowns).toBeGreaterThan(200);
  }, 30_000);

  it("moves the button to the next seat with chips", () => {
    const rng = seededRng(7);
    let session = createSession(
      [
        { id: "a", name: "A", stack: 100 },
        { id: "b", name: "B", stack: 0 },
        { id: "c", name: "C", stack: 100 },
        { id: "d", name: "D", stack: 100 },
      ],
      { smallBlind: 1, bigBlind: 2 },
    );
    const buttons: number[] = [];
    for (let k = 0; k < 4; k++) {
      const { session: next, dealt } = dealNextHand(session, rng);
      buttons.push(next.button);
      expect(dealt.seatOf).toEqual([0, 2, 3]);
      expect(dealt.hand.players[dealt.hand.button]!.id).toBe(next.seats[next.button]!.id);
      session = next;
    }
    expect(buttons).toEqual([0, 2, 3, 0]);
  });
});
