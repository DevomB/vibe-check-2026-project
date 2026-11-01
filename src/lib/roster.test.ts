import { describe, expect, it } from "vitest";
import { RISK_MAX } from "@/lean/protocol";
import { CUSTOM_BOT, OPPONENTS, botFor, presetFor } from "./roster";

describe("named opponents", () => {
  it("each has a Risk the Lean bot accepts", () => {
    for (const o of OPPONENTS) {
      expect(Number.isInteger(o.risk) && o.risk >= 0 && o.risk <= RISK_MAX).toBe(true);
    }
  });

  it("are the Risk ladder, from most careful to wildest", () => {
    expect(OPPONENTS.map((o) => `${o.name} ${o.risk} ${o.tier}`)).toEqual([
      "Ivy 0 Rock",
      "Rook 25 Tight",
      "Dex 40 Solid",
      "Mia 50 Ideal",
      "Vex 100 Maniac",
    ]);
  });

  it("have different names and different Risk values", () => {
    expect(new Set(OPPONENTS.map((o) => o.name)).size).toBe(OPPONENTS.length);
    expect(new Set(OPPONENTS.map((o) => o.risk)).size).toBe(OPPONENTS.length);
  });

  it("are found by their Risk, and other values give the custom bot", () => {
    for (const o of OPPONENTS) {
      expect(presetFor(o.risk)).toBe(o);
      expect(botFor(o.risk)).toEqual({ name: o.name, color: o.color });
    }
    expect(presetFor(51)).toBeUndefined();
    expect(botFor(51)).toEqual(CUSTOM_BOT);
  });

  it("the default Risk, 50, is Mia", () => {
    expect(presetFor(50)?.name).toBe("Mia");
  });
});
