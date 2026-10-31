import { describe, expect, it } from "vitest";
import { type Card, seededRng } from "../engine/cards";
import { type HandState, applyAction, legalActions, startHand } from "../engine/game";
import { PERSONALITIES, type PersonalityKey, chooseAction } from "./bot";
import { estimateEquity } from "./equity";

const KEYS = Object.keys(PERSONALITIES) as PersonalityKey[];
const CONFIG = { smallBlind: 5, bigBlind: 10 };

describe("estimateEquity", () => {
  const unusedRng = () => { throw new Error("randomness consumed"); };

  it.each([NaN, Infinity, 0, -1, 0.5])("rejects invalid sample count %s before drawing", (iterations) => {
    expect(() => estimateEquity(["As", "Ah"], [], 1, iterations, unusedRng)).toThrow(/iterations/);
  });

  it.each([NaN, Infinity, -1, 0.5])("rejects invalid opponent count %s before drawing", (opponents) => {
    expect(() => estimateEquity(["As", "Ah"], [], opponents, 1, unusedRng)).toThrow(/opponents/);
  });

  it.each([
    [["As"], []],
    [["As", "As"], []],
    [["As", "Ah"], ["As", "2c", "3d"]],
    [["As", "Ah"], ["2c", "3d", "4h", "5s", "6c", "7d"]],
  ])("rejects invalid known cards before drawing", (hole, board) => {
    expect(() => estimateEquity(hole as Card[], board as Card[], 1, 1, unusedRng)).toThrow(/cards|hole|board/);
  });
  it("gives pocket aces about 85% against one random hand", () => {
    const eq = estimateEquity(["As", "Ah"], [], 1, 20000, seededRng(1));
    expect(eq).toBeGreaterThan(0.82);
    expect(eq).toBeLessThan(0.88);
  });

  it("rates 7-2 offsuit well below aces", () => {
    const rng = seededRng(2);
    const aces = estimateEquity(["As", "Ah"], [], 3, 3000, rng);
    const junk = estimateEquity(["7c", "2d"], [], 3, 3000, rng);
    expect(junk).toBeLessThan(aces - 0.3);
  });

  it("gives a made royal flush on the river 100%", () => {
    const board: Card[] = ["Ks", "Qs", "Js", "Ts", "2d"];
    expect(estimateEquity(["As", "3c"], board, 5, 500, seededRng(3))).toBe(1);
  });

  it("splits a board that plays for everyone", () => {
    const board: Card[] = ["As", "Ks", "Qs", "Js", "Ts"];
    expect(estimateEquity(["2c", "3d"], board, 1, 500, seededRng(4))).toBeCloseTo(0.5, 10);
  });

  it("is fast enough for a decision against five opponents", () => {
    const rng = seededRng(5);
    estimateEquity(["Kd", "Qd"], ["2s", "7h", "Jd"], 5, 400, rng); // warm-up
    const start = performance.now();
    estimateEquity(["Kd", "Qd"], ["2s", "7h", "Jd"], 5, 400, rng);
    expect(performance.now() - start).toBeLessThan(50);
  });
});

function sumStacks(state: HandState) {
  return state.players.reduce((sum, p) => sum + p.stack + p.totalBet, 0);
}

describe("chooseAction", () => {
  it("does not count an uncallable overbet as money a short stack can win", () => {
    const state = applyAction(startHand(
      [{ id: "a", name: "A", stack: 1000 }, { id: "b", name: "B", stack: 100 }],
      0, CONFIG, seededRng(1),
    ), { type: "raise", to: 1000 });
    state.players[1]!.hole = ["7c", "2d"];
    const action = chooseAction(state, 1, { label: "Neutral", looseness: 0, aggression: 0, bluff: 0 }, seededRng(7), { iterations: 2000 });
    expect(action).toEqual({ type: "fold" });
  });
  it("plays hundreds of full hands with only legal actions and no lost chips", () => {
    const rng = seededRng(42);
    for (let h = 0; h < 300; h++) {
      const n = 2 + Math.floor(rng() * 5);
      const seats = Array.from({ length: n }, (_, i) => ({ id: `p${i}`, name: `P${i}`, stack: 20 + Math.floor(rng() * 1000) }));
      const styles = seats.map(() => PERSONALITIES[KEYS[Math.floor(rng() * KEYS.length)]!]);
      const chips = seats.reduce((sum, s) => sum + s.stack, 0);

      let state = startHand(seats, Math.floor(rng() * n), CONFIG, rng);
      let steps = 0;
      while (state.toAct !== null) {
        const seat = state.toAct;
        const legal = legalActions(state);
        const action = chooseAction(state, seat, styles[seat]!, rng, { iterations: 40 });
        if (action.type === "check") expect(legal.check).toBe(true);
        if (action.type === "call") expect(legal.call).toBeGreaterThan(0);
        if (action.type === "fold") expect(legal.check).toBe(false); // never fold when checking is free
        if (action.type === "raise") {
          expect(legal.raise).not.toBeNull();
          expect(Number.isInteger(action.to)).toBe(true);
          expect(action.to).toBeGreaterThanOrEqual(legal.raise!.min);
          expect(action.to).toBeLessThanOrEqual(legal.raise!.max);
        }
        state = applyAction(state, action);
        // Mid-hand, chips are either behind or in the pot.
        if (state.result === null) expect(sumStacks(state)).toBe(chips);
        expect(++steps).toBeLessThan(200);
      }
      expect(state.result).not.toBeNull();
      expect(state.players.reduce((sum, p) => sum + p.stack, 0)).toBe(chips);
    }
    // 300 simulated hands take a few seconds; on a busy machine that passes the 5 s default.
  }, 30_000);

  it("does not change the state it is given", () => {
    const state = startHand(
      [
        { id: "a", name: "A", stack: 500 },
        { id: "b", name: "B", stack: 500 },
        { id: "c", name: "C", stack: 500 },
      ],
      0,
      CONFIG,
      seededRng(7),
    );
    const before = structuredClone(state);
    chooseAction(state, state.toAct!, PERSONALITIES.maniac, seededRng(8), { iterations: 50 });
    expect(state).toEqual(before);
  });

  it("decides only from what its seat can see", () => {
    const state = startHand(
      [
        { id: "a", name: "A", stack: 500 },
        { id: "b", name: "B", stack: 500 },
        { id: "c", name: "C", stack: 500 },
      ],
      0,
      CONFIG,
      seededRng(9),
    );
    const seat = state.toAct!;
    // Same public view and own cards, but different hidden cards for everyone else.
    const other = structuredClone(state);
    const hidden = new Set<Card>([...state.players[seat]!.hole, ...state.board]);
    const spare = state.deck.filter((c) => !hidden.has(c)).reverse();
    for (const [j, p] of other.players.entries()) if (j !== seat) p.hole = [spare.pop()!, spare.pop()!];
    other.deck = spare;

    for (const key of KEYS) {
      const a = chooseAction(state, seat, PERSONALITIES[key], seededRng(10), { iterations: 60 });
      const b = chooseAction(other, seat, PERSONALITIES[key], seededRng(10), { iterations: 60 });
      expect(b).toEqual(a);
    }
  });

  it("raises or calls with the nuts and folds hopeless hands to a big bet", () => {
    const base = startHand(
      [
        { id: "a", name: "A", stack: 1000 },
        { id: "b", name: "B", stack: 1000 },
      ],
      0,
      CONFIG,
      seededRng(11),
    );
    // Button (seat 0) shoves preflop; seat 1 must respond.
    const shoved = applyAction(base, { type: "raise", to: 1000 });
    const nuts = structuredClone(shoved);
    nuts.players[1]!.hole = ["As", "Ad"];
    const junk = structuredClone(shoved);
    junk.players[1]!.hole = ["7c", "2d"];
    for (const key of KEYS) {
      expect(chooseAction(nuts, 1, PERSONALITIES[key], seededRng(12), { iterations: 300 }).type).toBe("call");
    }
    expect(chooseAction(junk, 1, PERSONALITIES.rock, seededRng(13), { iterations: 300 }).type).toBe("fold");
  });

  it("throws when it is not that seat's turn", () => {
    const state = startHand(
      [
        { id: "a", name: "A", stack: 100 },
        { id: "b", name: "B", stack: 100 },
      ],
      0,
      CONFIG,
      seededRng(14),
    );
    const notMe = (state.toAct! + 1) % 2;
    expect(() => chooseAction(state, notMe, PERSONALITIES.pro, seededRng(15))).toThrow();
  });
});
