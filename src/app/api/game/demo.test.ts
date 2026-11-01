import { existsSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { leanBinaryPath } from "@/lean/process";
import type { LeanReply, LeanState } from "@/lean/protocol";
import { POST } from "./route";

/**
 * Demo scene (a) from docs/DEMO.md: the rehearsed bad river call that the pitch reviews.
 * It is replayed through the `/api/game` handler with the same request bodies as the
 * Sunday fresh-clone check. If an engine change moves the cards, the bot's moves or the
 * review's numbers, the pitch no longer matches and this test fails. Then rerun
 * `node docs/demo/find-demo-hands.mjs`, and update docs/DEMO.md, docs/PITCH.md and this
 * file together.
 */

/** Hand 1 of a new game, up to the bot's opening river bet. */
const SCENE_A_MOVES = [
  { cmd: "new_game", seed: "6", risk: 0, bluff_pct: 60 },
  { cmd: "act", action: "raise", amount: 30 },
  { cmd: "act", action: "check" },
  { cmd: "act", action: "check" },
];

async function post(body: unknown): Promise<LeanReply> {
  const res = await POST(new Request("http://localhost/api/game", { method: "POST", body: JSON.stringify(body) }));
  expect(res.status).toBe(200);
  return (await res.json()) as LeanReply;
}

/** Send each body in order; every one must be accepted. Returns the last state. */
async function play(bodies: unknown[]): Promise<LeanState> {
  let state: LeanState | null = null;
  for (const body of bodies) {
    const reply = await post(body);
    if (!("ok" in reply)) throw new Error(`${JSON.stringify(body)} was rejected: ${reply.error}`);
    state = reply.state;
  }
  return state!;
}

describe.skipIf(!existsSync(leanBinaryPath()))("demo scene (a) through /api/game", () => {
  it("reaches the bot's opening river bet with the rehearsed cards", async () => {
    const s = await play(SCENE_A_MOVES);
    expect(s).toMatchObject({ hand: 1, street: "river", status: "playing", toAct: 0, pot: 60 });
    expect(s.board).toEqual(["9s", "5d", "2c", "Ks", "3d"]);
    expect(s.players[0].cards).toEqual(["4h", "Jh"]);
    expect(s.players[1].bet).toBe(60);
    expect(s.legal?.call).toBe(60);
  });

  it("grades the call Mistake with the numbers the pitch quotes", async () => {
    const s = await play([...SCENE_A_MOVES, { cmd: "act", action: "call" }]);
    expect(s.status).toBe("handOver");
    expect(s.result).toMatchObject({ showdown: true, outcome: "player1" });
    expect(s.players[1].cards).toEqual(["6s", "4c"]);
    expect(s.players[0].stack).toBe(410);
    expect(s.botReasons?.at(-1)).toBe("Bet 60: a value hand, among the strongest 30% on this board.");

    const reply = await post({ cmd: "review", hand: 1 });
    if (!("ok" in reply)) throw new Error(reply.error);
    const decisions = reply.review!.decisions;
    // Only the river call is graded; the earlier moves show "not graded yet".
    expect(decisions.slice(0, -1).every((d) => d.label === null)).toBe(true);
    expect(decisions.at(-1)).toEqual({
      street: "river",
      your_action: "call",
      label: "Mistake",
      worth_bb: { call: -2.67, fold: 0 },
      equity_had: 0.185,
      equity_needed: 0.333,
    });
  });

  it("grades folding the same spot Best, with the same worths", async () => {
    await play([...SCENE_A_MOVES, { cmd: "act", action: "fold" }]);
    const reply = await post({ cmd: "review", hand: 1 });
    if (!("ok" in reply)) throw new Error(reply.error);
    expect(reply.review!.decisions.at(-1)).toMatchObject({ your_action: "fold", label: "Best", worth_bb: { call: -2.67, fold: 0 } });
  });
});
