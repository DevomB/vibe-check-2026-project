import { describe, expect, it } from "vitest";
import { type Card, fullDeck } from "../../engine/cards";
import { type Counts, equityAtLeast, equityPercent, riverCounts, sampledCounts, total, turnCounts } from "./counts";

const share = (c: Counts) => (2 * c.win + c.tie) / (2 * total(c));

describe("riverCounts", () => {
  it("visits each of the 990 opponent hands once", () => {
    expect(total(riverCounts(["Ah", "Kd"], ["2c", "7d", "Js", "Qh", "3s"]))).toBe(990);
  });

  it("wins every time with the only royal flush", () => {
    expect(riverCounts(["As", "Ks"], ["Qs", "Js", "Ts", "2d", "3c"])).toEqual({ win: 990, tie: 0, loss: 0 });
  });

  it("ties every time when the board is the best hand", () => {
    expect(riverCounts(["2c", "3d"], ["As", "Ks", "Qs", "Js", "Ts"])).toEqual({ win: 0, tie: 990, loss: 0 });
  });

  it("rejects a wrong board size or a repeated card", () => {
    expect(() => riverCounts(["Ah", "Kd"], ["2c", "7d", "Js", "Qh"])).toThrow();
    expect(() => riverCounts(["Ah", "Kd"], ["Ah", "7d", "Js", "Qh", "3s"])).toThrow();
  });
});

describe("turnCounts", () => {
  const hole: Card[] = ["9h", "8h"];
  const board: Card[] = ["Th", "Jc", "2h", "Kd"];

  it("visits all 45,540 (opponent hand, river card) pairs", () => {
    expect(total(turnCounts(hole, board))).toBe(45_540);
  });

  it("equals the river counts added up over every possible river card", () => {
    const known = new Set<Card>([...hole, ...board]);
    const rivers = fullDeck().filter((c) => !known.has(c));
    const sum = { win: 0, tie: 0, loss: 0 };
    for (const river of rivers) {
      const c = riverCounts(hole, [...board, river]);
      sum.win += c.win;
      sum.tie += c.tie;
      sum.loss += c.loss;
    }
    expect(turnCounts(hole, board)).toEqual(sum);
  });
});

describe("sampledCounts", () => {
  it("counts exactly `samples` deals", () => {
    expect(total(sampledCounts(["Ah", "Kd"], ["2c", "7d", "Js"], 1000, 1))).toBe(1000);
  });

  it("gives the same counts for the same seed, and different counts for another seed", () => {
    const a = sampledCounts(["Ah", "Kd"], ["2c", "7d", "Js"], 1000, 7);
    expect(sampledCounts(["Ah", "Kd"], ["2c", "7d", "Js"], 1000, 7)).toEqual(a);
    expect(sampledCounts(["Ah", "Kd"], ["2c", "7d", "Js"], 1000, 8)).not.toEqual(a);
  });

  it("never loses or ties with a royal flush made on the flop", () => {
    expect(sampledCounts(["As", "Ks"], ["Qs", "Js", "Ts"], 1000, 3)).toEqual({ win: 1000, tie: 0, loss: 0 });
  });

  it("agrees with exact counting on the turn and river, within four standard errors", () => {
    const spots: [Card[], Card[]][] = [
      [["9h", "8h"], ["Th", "Jc", "2h", "Kd"]],
      [["Ah", "Kd"], ["2c", "7d", "Js", "Qh"]],
      [["5c", "5d"], ["Ac", "Kh", "Qs", "9d", "2c"]],
    ];
    const samples = 20_000;
    for (const [hole, board] of spots) {
      const exact = share(board.length === 4 ? turnCounts(hole, board) : riverCounts(hole, board));
      const estimate = share(sampledCounts(hole, board, samples, 11));
      const standardError = Math.sqrt((exact * (1 - exact)) / samples);
      expect(Math.abs(estimate - exact)).toBeLessThan(4 * standardError);
    }
  });
});

describe("equityAtLeast", () => {
  it("compares the win chance exactly, with ties counting half", () => {
    expect(equityAtLeast({ win: 3, tie: 0, loss: 1 }, 75)).toBe(true);
    expect(equityAtLeast({ win: 3, tie: 0, loss: 1 }, 76)).toBe(false);
    expect(equityAtLeast({ win: 1, tie: 1, loss: 0 }, 75)).toBe(true);
    expect(equityAtLeast({ win: 1, tie: 1, loss: 0 }, 76)).toBe(false);
    expect(equityAtLeast({ win: 2, tie: 0, loss: 1 }, 67)).toBe(false); // 66.7% is under 67%
  });

  it("rounds the win chance for display", () => {
    expect(equityPercent({ win: 2, tie: 0, loss: 1 })).toBe(67);
  });
});
