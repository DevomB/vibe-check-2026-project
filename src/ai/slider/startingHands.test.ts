import { describe, expect, it } from "vitest";
import { fullDeck } from "../../engine/cards";
import { type Counts, total } from "./counts";
import { PREFLOP_SOURCE, preflopCounts } from "./preflopTable";
import { STARTING_HANDS, exampleCards, simulateStartingHand, startingHand } from "./startingHands";

const percent = (c: Counts) => (100 * (2 * c.win + c.tie)) / (2 * total(c));
const tableEntry = (name: string) => preflopCounts(exampleCards(name));

describe("starting hands", () => {
  it("lists 13 pairs, 78 suited and 78 offsuit hands, each once", () => {
    expect(new Set(STARTING_HANDS).size).toBe(169);
    expect(STARTING_HANDS.filter((n) => n.length === 2)).toHaveLength(13);
    expect(STARTING_HANDS.filter((n) => n.endsWith("s"))).toHaveLength(78);
    expect(STARTING_HANDS.filter((n) => n.endsWith("o"))).toHaveLength(78);
    expect(STARTING_HANDS.slice(0, 4)).toEqual(["AA", "AKs", "AKo", "AQs"]);
    expect(STARTING_HANDS.at(-1)).toBe("22");
  });

  it("names two cards by their kind of starting hand", () => {
    expect(startingHand(["Kd", "As"])).toBe("AKo");
    expect(startingHand(["2s", "Ts"])).toBe("T2s");
    expect(startingHand(["7h", "7c"])).toBe("77");
  });

  it("sorts all 1,326 two-card hands into the 169 kinds: 6 per pair, 4 per suited, 12 per offsuit", () => {
    const deck = fullDeck();
    const seen = new Map<string, number>();
    for (let i = 0; i < deck.length; i++) {
      for (let j = i + 1; j < deck.length; j++) {
        const name = startingHand([deck[i]!, deck[j]!]);
        seen.set(name, (seen.get(name) ?? 0) + 1);
      }
    }
    expect([...seen.keys()].sort()).toEqual([...STARTING_HANDS].sort());
    for (const [name, n] of seen) expect(n).toBe(name.length === 2 ? 6 : name.endsWith("s") ? 4 : 12);
  });

  it("gives example cards of the right kind", () => {
    for (const name of STARTING_HANDS) expect(startingHand(exampleCards(name))).toBe(name);
  });
});

describe("preflop table (data/preflop.json)", () => {
  it("gives the same counts for every suit choice of one kind", () => {
    expect(preflopCounts(["Ah", "Kh"])).toEqual(preflopCounts(["As", "Ks"]));
    expect(preflopCounts(["Ah", "Kd"])).toEqual(tableEntry("AKo"));
  });

  it("is rebuilt exactly by the generator from its recorded seed and sample count", () => {
    for (const name of ["AA", "T9s", "22"]) {
      const index = STARTING_HANDS.indexOf(name);
      expect(simulateStartingHand(index, PREFLOP_SOURCE.samplesPerHand, PREFLOP_SOURCE.seed)).toEqual(tableEntry(name));
    }
  }, 30_000);

  it("matches well-known win chances against a random hand, within 1%", () => {
    const known: [string, number][] = [
      ["AA", 85.2],
      ["KK", 82.4],
      ["AKs", 67.0],
      ["AKo", 65.3],
    ];
    for (const [name, expected] of known) expect(Math.abs(percent(tableEntry(name)) - expected)).toBeLessThan(1);
  });

  it("ranks bigger pairs above smaller ones, and suited hands above the same cards offsuit", () => {
    const pairs = STARTING_HANDS.filter((n) => n.length === 2).map((n) => percent(tableEntry(n)));
    for (let i = 1; i < pairs.length; i++) expect(pairs[i]!).toBeLessThan(pairs[i - 1]!);
    for (const name of STARTING_HANDS.filter((n) => n.endsWith("s"))) {
      expect(percent(tableEntry(name))).toBeGreaterThan(percent(tableEntry(name.slice(0, 2) + "o")));
    }
  });
});
