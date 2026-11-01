import { existsSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { leanBinaryPath } from "@/lean/process";
import type { LeanReply } from "@/lean/protocol";
import { POST } from "./route";

/**
 * Plays through the `/api/game` handler exactly as the browser does (build the Lean
 * program first with `make lean`). Checks that the bridge passes good commands on and
 * turns away malformed ones before they reach Lean.
 */

async function post(body: unknown): Promise<{ status: number; reply: LeanReply }> {
  const res = await POST(new Request("http://localhost/api/game", { method: "POST", body: JSON.stringify(body) }));
  return { status: res.status, reply: (await res.json()) as LeanReply };
}

describe("/api/game input checks", () => {
  it.each([
    ["no command", {}],
    ["the removed bot command", { cmd: "bot" }],
    ["a new game without sliders", { cmd: "new_game", seed: "42" }],
    ["a slider that is not a whole number", { cmd: "new_game", seed: "42", risk: 50.5, bluff_pct: 33 }],
    ["a negative slider", { cmd: "new_game", seed: "42", risk: -1, bluff_pct: 33 }],
    ["a seed that is not digits", { cmd: "new_game", seed: "abc", risk: 50, bluff_pct: 33 }],
    ["a raise without an amount", { cmd: "act", action: "raise" }],
    ["a bet without an amount", { cmd: "act", action: "bet" }],
    ["a review without a hand", { cmd: "review" }],
  ])("turns away %s", async (_name, body) => {
    const { status, reply } = await post(body);
    expect(status).toBe(400);
    expect("error" in reply).toBe(true);
  });
});

describe.skipIf(!existsSync(leanBinaryPath()))("/api/game with the Lean program", () => {
  it("accepts bet as a street-total raise", { timeout: 30_000 }, async () => {
    const start = await post({ cmd: "new_game", seed: "42", risk: 50, bluff_pct: 33 });
    if (!("ok" in start.reply)) throw new Error(start.reply.error);
    const { status, reply } = await post({ cmd: "act", action: "bet", amount: 20 });
    expect(status).toBe(200);
    expect("ok" in reply).toBe(true);
  });

  it("plays a hand to the end by checking or calling, then reviews it", { timeout: 30_000 }, async () => {
    let { reply } = await post({ cmd: "new_game", seed: "2026", risk: 50, bluff_pct: 33 });
    if (!("ok" in reply)) throw new Error(reply.error);
    let s = reply.state;
    expect(s.sliders).toEqual({ risk: 50, bluffPct: 33 });
    for (let guard = 0; s.status === "playing" && guard < 50; guard++) {
      ({ reply } = await post({ cmd: "act", action: s.legal!.check ? "check" : "call" }));
      if (!("ok" in reply)) throw new Error(reply.error);
      s = reply.state;
    }
    expect(s.status).not.toBe("playing");
    expect(s.botReasons).not.toBeNull();

    ({ reply } = await post({ cmd: "review", hand: s.hand }));
    if (!("ok" in reply)) throw new Error(reply.error);
    expect(reply.review?.hand).toBe(s.hand);
    expect(reply.review?.decisions.length).toBeGreaterThan(0);
  });

  it("passes slider values out of range to Lean, which rejects them", async () => {
    const { status, reply } = await post({ cmd: "new_game", seed: "1", risk: 101, bluff_pct: 33 });
    expect(status).toBe(200);
    expect(reply).toMatchObject({ error: "risk must be 0-100" });
  });
});
