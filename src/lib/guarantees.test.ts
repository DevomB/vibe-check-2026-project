import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { GUARANTEES, TRUSTED, guaranteeById } from "./guarantees";

/** The theorems Comparator checks: the drawer names these and only these. */
const comparator = JSON.parse(readFileSync(new URL("../../engine/comparator.json", import.meta.url), "utf8")) as {
  theorem_names: string[];
};

describe("the guarantees in the Proofs drawer", () => {
  it.each(GUARANTEES.flatMap((g) => g.theorems.map((t) => [g.id, t] as const)))("%s names %s, which Comparator checks", (_id, name) => {
    expect(comparator.theorem_names).toContain(name);
  });

  it.each(comparator.theorem_names)("names %s, which Comparator checks, in some entry", (name) => {
    expect(GUARANTEES.flatMap((g) => g.theorems)).toContain(name);
  });

  it("has one entry per guarantee, T1 to T9 with T7b, in order", () => {
    expect(GUARANTEES.map((g) => `${g.code} ${g.id}`)).toEqual([
      "T1 chips",
      "T2 cards",
      "T3 legal",
      "T4 risk",
      "T5 review",
      "T6 equity",
      "T7 bluff",
      "T7b bluffcatcher",
      "T8 hindsight",
      "T9 ends",
    ]);
  });

  it("gives every entry its words, theorems, assumptions and limits", () => {
    for (const g of GUARANTEES) {
      expect(g.says.length, g.id).toBeGreaterThan(0);
      expect(g.theorems.length, g.id).toBeGreaterThan(0);
      expect(g.assumes.length, g.id).toBeGreaterThan(0);
      expect(g.limits.length, g.id).toBeGreaterThan(0);
    }
    expect(TRUSTED.length).toBeGreaterThan(0);
  });

  it("names each theorem once", () => {
    const names = GUARANTEES.flatMap((g) => g.theorems);
    expect(new Set(names).size).toBe(names.length);
  });

  it("opens at the ids the review links use", () => {
    expect(guaranteeById("review")?.code).toBe("T5");
    expect(guaranteeById("bluff")?.code).toBe("T7");
    expect(guaranteeById("risk")?.code).toBe("T4");
    expect(guaranteeById("hindsight")?.code).toBe("T8");
    expect(guaranteeById("nope")).toBeUndefined();
  });
});
