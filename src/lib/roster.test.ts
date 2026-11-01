import { describe, expect, it } from "vitest";
import { BLUFF_PCT_MAX, RISK_MAX } from "@/lean/protocol";
import { CUSTOM_BOT, OPPONENTS, botFor, presetFor } from "./roster";

describe("named opponents", () => {
  it("each has slider values the Lean bot accepts", () => {
    for (const o of OPPONENTS) {
      expect(Number.isInteger(o.risk) && o.risk >= 0 && o.risk <= RISK_MAX).toBe(true);
      expect(Number.isInteger(o.bluffPct) && o.bluffPct >= 0 && o.bluffPct <= BLUFF_PCT_MAX).toBe(true);
    }
  });

  it("have different names and different slider values", () => {
    expect(new Set(OPPONENTS.map((o) => o.name)).size).toBe(OPPONENTS.length);
    expect(new Set(OPPONENTS.map((o) => `${o.risk}/${o.bluffPct}`)).size).toBe(OPPONENTS.length);
  });

  it("are found by their slider values, and other values give the custom bot", () => {
    for (const o of OPPONENTS) {
      expect(presetFor(o.risk, o.bluffPct)).toBe(o);
      expect(botFor(o.risk, o.bluffPct)).toEqual({ name: o.name, color: o.color });
    }
    expect(presetFor(51, 33)).toBeUndefined();
    expect(botFor(51, 33)).toEqual(CUSTOM_BOT);
  });

  it("the default sliders (Risk 50, Bluff 33%) are Mia", () => {
    expect(presetFor(50, 33)?.name).toBe("Mia");
  });
});
