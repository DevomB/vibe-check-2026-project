import { describe, expect, it } from "vitest";
import { buildPots, splitPot } from "./pots";

describe("buildPots", () => {
  it("makes one pot when everyone put in the same", () => {
    expect(buildPots([100, 100, 100], [false, false, false])).toEqual([{ amount: 300, eligible: [0, 1, 2] }]);
  });

  it("makes a main pot and a side pot when one player is all-in for less", () => {
    expect(buildPots([50, 200, 200], [false, false, false])).toEqual([
      { amount: 150, eligible: [0, 1, 2] },
      { amount: 300, eligible: [1, 2] },
    ]);
  });

  it("handles three different all-in amounts", () => {
    expect(buildPots([30, 80, 150, 150], [false, false, false, false])).toEqual([
      { amount: 120, eligible: [0, 1, 2, 3] },
      { amount: 150, eligible: [1, 2, 3] },
      { amount: 140, eligible: [2, 3] },
    ]);
  });

  it("counts folded chips but does not let folded players win", () => {
    const pots = buildPots([60, 100, 100], [true, false, false]);
    expect(pots).toEqual([{ amount: 260, eligible: [1, 2] }]);
  });

  it("puts a folded player's chips into the pots they reached", () => {
    // Seat 0 folded after putting in 80; seat 1 is all-in for 50.
    const pots = buildPots([80, 50, 200], [true, false, false]);
    expect(pots).toEqual([
      { amount: 150, eligible: [1, 2] },
      { amount: 180, eligible: [2] },
    ]);
    expect(pots.reduce((s, p) => s + p.amount, 0)).toBe(330);
  });

  it("never loses chips", () => {
    const contributed = [10, 0, 75, 75, 300, 20];
    const folded = [true, true, false, false, false, true];
    const total = buildPots(contributed, folded).reduce((s, p) => s + p.amount, 0);
    expect(total).toBe(contributed.reduce((a, b) => a + b, 0));
  });
});

describe("splitPot", () => {
  it("splits evenly", () => {
    expect([...splitPot(100, [1, 3], 0, 4)].sort()).toEqual([
      [1, 50],
      [3, 50],
    ]);
  });

  it("gives the odd chip to the winner closest to the left of the button", () => {
    // Button at 2: seat 3 is first left, then 0, then 1.
    const shares = splitPot(101, [1, 3], 2, 4);
    expect(shares.get(3)).toBe(51);
    expect(shares.get(1)).toBe(50);
    const three = splitPot(100, [0, 1, 2], 0, 3);
    expect(three.get(1)).toBe(34);
    expect(three.get(2)).toBe(33);
    expect(three.get(0)).toBe(33);
  });
});
