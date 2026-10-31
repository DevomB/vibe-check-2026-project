import { describe, expect, it } from "vitest";
import { type Card, isCard } from "./cards";
import { HandCategory, compareHands, evaluate } from "./evaluator";

const h = (s: string) => evaluate(s.split(" ") as Card[]);

describe("evaluate", () => {
  it.each(["As As Kd Qh Jc", "1s 2d 3h 4c 5s"])("rejects impossible cards: %s", (cards) => {
    expect(() => h(cards)).toThrow();
  });

  it.each([null, undefined, 23, {}, "", "10s", "as"])("rejects non-card value %j", (value) => {
    expect(isCard(value as string)).toBe(false);
  });
  it.each([
    ["As Ks Qs Js Ts 2d 3c", HandCategory.StraightFlush, "Royal Flush"],
    ["9h 8h 7h 6h 5h Ad Ac", HandCategory.StraightFlush, "Straight Flush, Nine high"],
    ["Kd Kc Kh Ks 2d 3c 9s", HandCategory.FourOfAKind, "Four of a Kind, Kings"],
    ["Kd Kc Kh 5s 5d 3c 9s", HandCategory.FullHouse, "Full House, Kings full of Fives"],
    ["Ah 9h 7h 4h 2h Kd Qc", HandCategory.Flush, "Flush, Ace high"],
    ["Td 9c 8h 7s 6d 2c 2s", HandCategory.Straight, "Straight, Ten high"],
    ["7d 7c 7h As Kd 3c 2s", HandCategory.ThreeOfAKind, "Three of a Kind, Sevens"],
    ["Ad Ac 8h 8s Kd 3c 2s", HandCategory.TwoPair, "Two Pair, Aces and Eights"],
    ["Jd Jc 8h 6s Kd 3c 2s", HandCategory.Pair, "Pair of Jacks"],
    ["Ad Jc 8h 6s Kd 3c 2s", HandCategory.HighCard, "High Card, Ace"],
  ])("%s is %s (%s)", (cards, category, name) => {
    const v = h(cards);
    expect(v.category).toBe(category);
    expect(v.name).toBe(name);
  });

  it("ranks the categories in order", () => {
    const ladder = [
      "Ad Jc 8h 6s Kd 3c 2s",
      "Jd Jc 8h 6s Kd 3c 2s",
      "Ad Ac 8h 8s Kd 3c 2s",
      "7d 7c 7h As Kd 3c 2s",
      "Td 9c 8h 7s 6d 2c 2s",
      "Ah 9h 7h 4h 2h Kd Qc",
      "Kd Kc Kh 5s 5d 3c 9s",
      "Kd Kc Kh Ks 2d 3c 9s",
      "9h 8h 7h 6h 5h Ad Ac",
    ].map(h);
    for (let i = 1; i < ladder.length; i++) expect(compareHands(ladder[i]!, ladder[i - 1]!)).toBeGreaterThan(0);
  });

  it("uses kickers to break ties", () => {
    expect(compareHands(h("Ad Ac Kh 9s 7d 3c 2s"), h("Ah As Qh Js 7d 3c 2s"))).toBeGreaterThan(0);
    expect(compareHands(h("Ad Ac Kh Qs 7d 3c 2s"), h("Ah As Kc Qd 6d 3c 2s"))).toBeGreaterThan(0);
    expect(compareHands(h("8d 8c 5h 5s Ad 3c 2s"), h("8h 8s 5c 5d Kd 3c 2s"))).toBeGreaterThan(0);
    expect(compareHands(h("Ad Kc 9h 7s 5d 3c 2s"), h("Ah Kd 9c 7d 4d 3c 2s"))).toBeGreaterThan(0);
  });

  it("finds the wheel (A-2-3-4-5) as a five-high straight", () => {
    const wheel = h("Ad 2c 3h 4s 5d Kc 9s");
    expect(wheel.category).toBe(HandCategory.Straight);
    expect(wheel.name).toBe("Straight, Five high");
    expect(compareHands(h("2d 3c 4h 5s 6d Kc 9s"), wheel)).toBeGreaterThan(0);
  });

  it("finds the steel wheel", () => {
    const v = h("Ah 2h 3h 4h 5h Kd Kc");
    expect(v.category).toBe(HandCategory.StraightFlush);
    expect(v.name).toBe("Straight Flush, Five high");
    expect(compareHands(h("2h 3h 4h 5h 6h Kd Kc"), v)).toBeGreaterThan(0);
  });

  it("finds the ace-high straight, and prefers the highest run", () => {
    const v = h("Ad Kc Qh Js Td 9c 8s");
    expect(v.name).toBe("Straight, Ace high");
    expect(v.best.length).toBe(5);
  });

  it("prefers a flush to a straight", () => {
    const v = h("9h 8h 7c 6h 5d 2h Ah");
    expect(v.category).toBe(HandCategory.Flush);
  });

  it("makes a full house from two sets of three, with the best pair", () => {
    const v = h("Kd Kc Kh 5s 5d 5c 9s");
    expect(v.category).toBe(HandCategory.FullHouse);
    expect(v.name).toBe("Full House, Kings full of Fives");
    const w = h("Kd Kc Kh 5s 5d 9c 9s");
    expect(w.name).toBe("Full House, Kings full of Nines");
    expect(compareHands(w, v)).toBeGreaterThan(0);
  });

  it("picks the best two of three pairs and the best kicker", () => {
    const v = h("Qd Qc 7h 7s 4d 4c 2s");
    expect(v.name).toBe("Two Pair, Queens and Sevens");
    // The kicker is the 4 from the third pair, beating a lone 3.
    expect(compareHands(v, h("Qh Qs 7c 7d 3d 2c 2h"))).toBeGreaterThan(0);
    expect(v.best.map((c) => c[0])).toEqual(["Q", "Q", "7", "7", "4"]);
  });

  it("takes the quads kicker from the remaining cards", () => {
    const v = h("9d 9c 9h 9s Kd Kc As");
    expect(v.best[4]).toBe("As");
    expect(compareHands(v, h("9d 9c 9h 9s Kd Kc Qs"))).toBeGreaterThan(0);
  });

  it("scores equal hands equally (the board plays)", () => {
    const board = "As Ks Qd Jc Th";
    expect(compareHands(h(`${board} 2c 3d`), h(`${board} 4c 5d`))).toBe(0);
  });

  it("returns five distinct best cards taken from the input", () => {
    for (const s of ["Kd Kc Kh 5s 5d 5c 9s", "Ad 2c 3h 4s 5d Kc 9s", "9h 8h 7c 6h 5d 2h Ah", "Qd Qc 7h 7s 4d 4c 2s"]) {
      const input = s.split(" ");
      const v = h(s);
      expect(v.best.length).toBe(5);
      expect(new Set(v.best).size).toBe(5);
      for (const c of v.best) expect(input).toContain(c);
    }
  });

  it("works with exactly five cards", () => {
    expect(h("2c 3c 4c 5c 7d").category).toBe(HandCategory.HighCard);
  });

  it("rejects too few or too many cards", () => {
    expect(() => h("2c 3c 4c 5c")).toThrow();
    expect(() => h("2c 3c 4c 5c 7d 8d 9d Td")).toThrow();
  });
});
