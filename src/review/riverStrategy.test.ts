import { describe, expect, it } from "vitest";
import { type Card, fullDeck } from "../engine/cards";
import { evaluate } from "../engine/evaluator";
import {
  MAX_BLUFF_PCT,
  bluffCount,
  cardId,
  rankRiverHands,
  riverBettingSet,
  riverCandidates,
  riverRole,
  valueCount,
} from "./riverStrategy";

const cards = (s: string) => s.split(" ") as Card[];
const key = (h: { cards: readonly Card[] }) => h.cards.join(" ");
/** No pair and no flush is possible. King-Ten makes the best hand, a king-high straight. */
const BOARD = cards("2c 7d Js Qh 9s");
/** A royal flush on the board: every hand plays the board, so every hand ties. */
const ROYAL = cards("As Ks Qs Js Ts");

describe("cardId", () => {
  it("orders cards by rank 2..A, then by suit c, d, h, s", () => {
    expect(cards("2c 2d 2h 2s 3c As").map(cardId)).toEqual([0, 1, 2, 3, 4, 51]);
    expect(new Set(fullDeck().map(cardId)).size).toBe(52);
  });
});

describe("riverCandidates", () => {
  it("lists each pair of cards not on the board once, lower card ID first", () => {
    const hands = riverCandidates(BOARD);
    expect(hands).toHaveLength(1081); // 47 cards left, 47 × 46 / 2 pairs
    expect(new Set(hands.map((h) => h.join(" "))).size).toBe(1081);
    expect(hands.filter(([a, b]) => BOARD.includes(a) || BOARD.includes(b) || cardId(a) >= cardId(b))).toEqual([]);
  });

  it("rejects a board that is not five different cards", () => {
    expect(() => riverCandidates(cards("2c 7d Js Qh"))).toThrow();
    expect(() => riverCandidates(cards("2c 7d Js Qh Qh"))).toThrow();
  });
});

describe("valueCount and bluffCount", () => {
  it("bets 324 hands for value on every river: 30% of 1,081, rounded down", () => {
    expect(valueCount(1081)).toBe(324);
  });

  it.each([
    { bluffPct: 0, bluffs: 0 },
    { bluffPct: 20, bluffs: 81 },
    { bluffPct: 33, bluffs: 160 }, // 159.58
    { bluffPct: 50, bluffs: 324 },
    { bluffPct: 60, bluffs: 486 },
  ])("Bluff $bluffPct percent gives $bluffs bluff hands next to 324 value hands", ({ bluffPct, bluffs }) => {
    expect(bluffCount(324, bluffPct)).toBe(bluffs);
  });

  it("rounds halves up", () => {
    expect(bluffCount(2, 20)).toBe(1); // 2 × 20 / 80 = 0.5
    expect(bluffCount(6, 20)).toBe(2); // 1.5
    expect(bluffCount(5, 20)).toBe(1); // 1.25
  });

  it("is values × b / (100 − b) rounded to the nearest whole hand, for every input", () => {
    const wrong: string[] = [];
    for (let v = 0; v <= 1081; v++) {
      for (let b = 0; b <= MAX_BLUFF_PCT; b++) {
        // Rounding halves up: count − v × b / (100 − b) is above −1/2 and at most 1/2. Multiply through by 2 × (100 − b).
        const gap = 2 * bluffCount(v, b) * (100 - b) - 2 * v * b;
        if (gap <= -(100 - b) || gap > 100 - b) wrong.push(`values ${v}, bluff ${b}`);
      }
    }
    expect(wrong).toEqual([]);
  });

  it("makes bluffs b% of the betting set, to within half a hand", () => {
    for (let b = 0; b <= MAX_BLUFF_PCT; b++) {
      const bluffs = bluffCount(324, b);
      // |bluffs − b% of (324 + bluffs)| ≤ 1/2, multiplied through by 200.
      expect(Math.abs(200 * bluffs - 2 * b * (324 + bluffs))).toBeLessThanOrEqual(100);
    }
  });

  it("rejects a Bluff setting that is not a whole number from 0 to 60", () => {
    expect(() => bluffCount(324, 61)).toThrow();
    expect(() => bluffCount(324, -1)).toThrow();
    expect(() => bluffCount(324, 33.5)).toThrow();
  });
});

describe("riverBettingSet", () => {
  const score = (h: readonly Card[]) => evaluate([...h, ...BOARD]).score;

  it("bets the strongest hands for value and the weakest for bluffs", () => {
    const { value, bluffs } = riverBettingSet(BOARD, 33);
    expect(value).toHaveLength(324);
    expect(bluffs).toHaveLength(160);

    const valueKeys = new Set(value.map(key));
    const bluffKeys = new Set(bluffs.map(key));
    const checked = riverCandidates(BOARD).filter((h) => !valueKeys.has(h.join(" ")) && !bluffKeys.has(h.join(" ")));
    expect(checked).toHaveLength(1081 - 324 - 160);
    const checkedScores = checked.map(score);
    expect(Math.min(...value.map((h) => score(h.cards)))).toBeGreaterThanOrEqual(Math.max(...checkedScores));
    expect(Math.max(...bluffs.map((h) => score(h.cards)))).toBeLessThanOrEqual(Math.min(...checkedScores));
  });

  it("has 324 value hands and the formula's bluff count at every Bluff setting, never overlapping", () => {
    for (let b = 0; b <= MAX_BLUFF_PCT; b++) {
      const { value, bluffs } = riverBettingSet(BOARD, b);
      expect(value).toHaveLength(324);
      expect(bluffs).toHaveLength(bluffCount(324, b));
      const valueKeys = new Set(value.map(key));
      expect(bluffs.filter((h) => valueKeys.has(key(h)))).toEqual([]);
    }
  });

  it("orders hands with equal scores by card IDs, lowest first", () => {
    const ranked = rankRiverHands(BOARD);
    for (let i = 1; i < ranked.length; i++) {
      const [prev, next] = [ranked[i - 1]!, ranked[i]!];
      expect(next.score).toBeLessThanOrEqual(prev.score);
      if (next.score === prev.score) {
        const order = cardId(prev.cards[0]) - cardId(next.cards[0]) || cardId(prev.cards[1]) - cardId(next.cards[1]);
        expect(order).toBeLessThan(0);
      }
    }
  });

  it("picks by card IDs alone when every hand ties", () => {
    const { value, bluffs } = riverBettingSet(ROYAL, 33);
    const byId = riverCandidates(ROYAL).map((h) => h.join(" "));
    expect(value.map(key)).toEqual(byId.slice(0, 324));
    expect(bluffs.map(key)).toEqual(byId.slice(-160));
    expect(value[0]!.cards).toEqual(["2c", "2d"]);
  });
});

describe("riverRole", () => {
  it("bets the best hand for value", () => {
    expect(riverRole(BOARD, 33, cards("Kh Td"))).toBe("value");
    expect(riverRole(BOARD, 0, cards("Td Kh"))).toBe("value");
  });

  it("bluffs with the weakest hand, unless Bluff is 0%", () => {
    // 4-3 makes only queen high (Q J 9 7 4). No hand on this board is weaker.
    expect(riverRole(BOARD, 33, cards("4d 3c"))).toBe("bluff");
    expect(riverRole(BOARD, 0, cards("4d 3c"))).toBe("check");
  });

  it("checks a hand in the middle", () => {
    // A pair of twos beats every high-card hand (the bottom 416) but is far from the top 324.
    expect(riverRole(BOARD, 33, cards("2d 3c"))).toBe("check");
  });

  it("rejects hole cards that repeat or are on the board", () => {
    expect(() => riverRole(BOARD, 33, cards("Kh Kh"))).toThrow();
    expect(() => riverRole(BOARD, 33, cards("Kh 2c"))).toThrow();
    expect(() => riverRole(BOARD, 33, cards("Kh"))).toThrow();
  });
});
