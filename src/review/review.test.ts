import { describe, expect, it } from "vitest";
import { type Card, fullDeck, seededRng, shuffle } from "../engine/cards";
import { evaluate } from "../engine/evaluator";
import { REVIEW_LABELS, type RiverSpot, botRiverRange, callStakes, labelFor, reviewRiverDecision, toNumber } from "./review";
import { riverBettingSet } from "./riverStrategy";

const cards = (s: string) => s.split(" ") as Card[];
const key = (h: { cards: readonly Card[] }) => h.cards.join(" ");
/** No pair and no flush is possible. King-Ten makes the best hand, a king-high straight. */
const BOARD = cards("2c 7d Js Qh 9s");
/** A royal flush on the board: every hand plays the board, so every hand ties. */
const ROYAL = cards("As Ks Qs Js Ts");

/** The spot after the pot held `before` chips and the bot bet `bet` into it. */
function spot(board: Card[], hole: string, before: number, bet: number, more: Partial<RiverSpot> = {}): RiverSpot {
  return { board, hole: cards(hole), pot: before + bet, toCall: bet, stack: 500, bigBlind: 10, bluffPct: 33, ...more };
}

/** Random spots, the same ones on every run. */
function randomSpots(count: number, seed: number): RiverSpot[] {
  const rng = seededRng(seed);
  const upTo = (n: number) => Math.floor(rng() * n);
  return Array.from({ length: count }, () => {
    const deck = shuffle(fullDeck(), rng);
    const before = 20 + upTo(400);
    const bet = 10 + upTo(400);
    return { board: deck.slice(0, 5), hole: deck.slice(5, 7), pot: before + bet, toCall: bet, stack: 1 + upTo(500), bigBlind: 10, bluffPct: upTo(61) };
  });
}

describe("labelFor", () => {
  it.each([
    [0, 1, "Best"],
    [1, 1000, "Good"],
    [499, 1000, "Good"],
    [1, 2, "Inaccuracy"],
    [1999, 1000, "Inaccuracy"],
    [2, 1, "Mistake"],
    [4999, 1000, "Mistake"],
    [5, 1, "Blunder"],
    [100, 1, "Blunder"],
  ])("losing %i/%i big blinds is %s", (num, den, label) => {
    expect(labelFor({ num, den })).toBe(label);
  });

  it("only gets worse as the loss grows", () => {
    let worst = 0;
    for (let num = 0; num <= 200; num++) {
      const rank = REVIEW_LABELS.indexOf(labelFor({ num, den: 20 }));
      expect(rank).toBeGreaterThanOrEqual(worst);
      worst = rank;
    }
    expect(worst).toBe(REVIEW_LABELS.indexOf("Blunder"));
  });

  it("rejects a negative loss", () => {
    expect(() => labelFor({ num: -1, den: 10 })).toThrow();
  });
});

describe("reviewRiverDecision", () => {
  // On the royal board every hand ties, so a call always gets back half of the pot before the bet:
  // calling is worth before / 2 chips, which is what a fold gives up.
  it.each([
    [8, "Good"], // 0.4 big blinds
    [10, "Inaccuracy"], // 0.5
    [38, "Inaccuracy"], // 1.9
    [40, "Mistake"], // 2
    [98, "Mistake"], // 4.9
    [100, "Blunder"], // 5
  ])("folding a sure split of a %i-chip pot is %s", (before, label) => {
    const s = spot(ROYAL, "2c 3d", before, 50);
    const fold = reviewRiverDecision(s, "fold");
    expect(fold.label).toBe(label);
    expect(toNumber(fold.lostBb)).toBeCloseTo(before / 20, 12);
    expect(toNumber(fold.worthBb.call)).toBeCloseTo(before / 20, 12);
    expect(fold.counts).toEqual({ wins: 0, ties: botRiverRange(s).length, losses: 0 });
    expect(toNumber(fold.equityHad)).toBe(0.5);
    expect(reviewRiverDecision(s, "call").label).toBe("Best");
  });

  it("finds no losses for the best hand, and ties only with the same hand", () => {
    const s = spot(BOARD, "Kh Td", 100, 100);
    const call = reviewRiverDecision(s, "call");
    // The bot's other king-ten hands: three kings times three tens.
    expect(call.counts.losses).toBe(0);
    expect(call.counts.ties).toBe(9);
    expect(call.label).toBe("Best");
    expect(reviewRiverDecision(s, "fold").label).toBe("Blunder");
  });

  it("calls a big bet with the weakest hand into a value-only range a Blunder", () => {
    const s = spot(BOARD, "4d 3c", 100, 100, { bluffPct: 0 });
    const call = reviewRiverDecision(s, "call");
    expect(call.counts.wins + call.counts.ties).toBe(0);
    expect(toNumber(call.worthBb.call)).toBe(-10); // loses the 100-chip call every time
    expect(call.label).toBe("Blunder");
    expect(toNumber(call.equityNeeded)).toBeCloseTo(1 / 3, 12);
    expect(reviewRiverDecision(s, "fold").label).toBe("Best");
  });

  it("uses the bot's board-only betting set, minus the hands that use the human's cards", () => {
    const s = spot(BOARD, "Kh Td", 100, 100);
    const { value, bluffs } = riverBettingSet(BOARD, 33);
    const all = [...value, ...bluffs];
    const expected = all.filter((h) => !h.cards.includes("Kh") && !h.cards.includes("Td"));
    expect(botRiverRange(s).map(key)).toEqual(expected.map(key));
    expect(expected.length).toBeLessThan(all.length);
    const { wins, ties, losses } = reviewRiverDecision(s, "call").counts;
    expect(wins + ties + losses).toBe(expected.length);
  });

  it("leaves out the part of the bet the human cannot match", () => {
    const s = spot(BOARD, "Kh Td", 100, 400, { stack: 150 });
    expect(callStakes(s)).toEqual({ pot: 250, cost: 150 });
    expect(reviewRiverDecision(s, "call").equityNeeded).toEqual({ num: 150, den: 400 });
  });

  it("matches a plain average of the chips won or lost against each hand the bot can hold", () => {
    for (const s of randomSpots(12, 7)) {
      const { value, bluffs } = riverBettingSet(s.board, s.bluffPct);
      const range = [...value, ...bluffs].filter((h) => !h.cards.some((c) => s.hole.includes(c)));
      const cost = Math.min(s.toCall, s.stack);
      const pot = s.pot - (s.toCall - cost);
      const mine = evaluate([...s.hole, ...s.board]).score;
      let total = 0;
      let equity = 0;
      for (const h of range) {
        const theirs = evaluate([...h.cards, ...s.board]).score;
        total += mine > theirs ? pot : mine < theirs ? -cost : (pot - cost) / 2;
        equity += mine > theirs ? 1 : mine < theirs ? 0 : 0.5;
      }
      const verdict = reviewRiverDecision(s, "call");
      expect(toNumber(verdict.worthBb.call) * s.bigBlind).toBeCloseTo(total / range.length, 9);
      expect(toNumber(verdict.equityHad)).toBeCloseTo(equity / range.length, 12);
      expect(toNumber(verdict.worthBb.fold)).toBe(0);
    }
  });

  it("calls a choice Best exactly when it loses nothing, and the better choice is always Best", () => {
    for (const s of randomSpots(12, 11)) {
      const call = reviewRiverDecision(s, "call");
      const fold = reviewRiverDecision(s, "fold");
      for (const v of [call, fold]) {
        expect(v.lostBb.num).toBeGreaterThanOrEqual(0);
        expect(v.label === "Best").toBe(v.lostBb.num === 0);
      }
      const callWorth = toNumber(call.worthBb.call);
      expect(callWorth >= 0 ? call.label : fold.label).toBe("Best");
      if (callWorth > 0) expect(fold.label).not.toBe("Best");
      if (callWorth < 0) expect(call.label).not.toBe("Best");
    }
  });

  it("rejects spots that cannot happen", () => {
    expect(() => reviewRiverDecision(spot(BOARD, "Kh 2c", 100, 100), "call")).toThrow(); // hole card on the board
    expect(() => reviewRiverDecision(spot(BOARD, "Kh Td", 100, 100, { bluffPct: 61 }), "call")).toThrow();
    expect(() => reviewRiverDecision({ ...spot(BOARD, "Kh Td", 100, 100), pot: 50 }, "call")).toThrow(); // pot without the bet
    expect(() => reviewRiverDecision(spot(BOARD, "Kh Td", 100, 100, { stack: 1.5 }), "call")).toThrow();
  });
});

describe("no hindsight", () => {
  it("gives the same verdict whatever cards the bot really holds", () => {
    // A pair of jacks beats the bot's bluffs and loses to most of its value hands.
    const s = spot(BOARD, "Jh Tc", 100, 100);
    const mine = evaluate([...s.hole, ...s.board]).score;
    const range = botRiverRange(s);
    const outcomes = new Set<string>();

    for (const choice of ["call", "fold"] as const) {
      const expected = reviewRiverDecision(s, choice);
      // A saved hand record also holds the bot's real cards; the review must not use them.
      for (let i = 0; i < range.length; i += 7) {
        const bot = range[i]!;
        const record = { ...s, botCards: bot.cards };
        expect(reviewRiverDecision(record, choice)).toEqual(expected);
        outcomes.add(mine > bot.score ? "human wins" : mine < bot.score ? "bot wins" : "split");
      }
    }
    // The showdown result changed from hand to hand, but the verdict did not.
    expect(outcomes).toContain("human wins");
    expect(outcomes).toContain("bot wins");
  });
});
