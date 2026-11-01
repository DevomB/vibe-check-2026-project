import { describe, expect, it } from "vitest";
import type { ApiReply, LeanReview, LeanState } from "@/lean/protocol";
import { POST } from "./route";

/**
 * The review's river range viewer and Risk explorer, through the `/api/game` handler as the
 * browser uses it. Lean computes every number (`engine/Engine/Explain.lean`); these tests check
 * that what reaches the screen is present and consistent.
 */

async function post(body: unknown): Promise<ApiReply> {
  const res = await POST(new Request("http://localhost/api/game", { method: "POST", body: JSON.stringify(body) }));
  return (await res.json()) as ApiReply;
}

function okState(reply: ApiReply): LeanState {
  if (!("ok" in reply)) throw new Error(reply.error);
  return reply.state;
}

/** Bot moves among a reply's events. */
function botMoves(state: LeanState): number {
  return state.events.filter((e) => e.type === "action" && e.player === 1).length;
}

/**
 * Hand 1 of seed 7 at Risk 50 (caution 0, a 33% bluff share): the human raises to 30, then
 * checks or calls. The bot calls the raise, checks the flop and the turn, and bets 60 on the
 * river, and the human's call is graded. Returns the finished state, the bot's move count and
 * the review.
 */
async function playSeed7(): Promise<{ state: LeanState; moves: number; review: LeanReview }> {
  let state = okState(await post({ cmd: "new_game", seed: "7", risk: 50 }));
  let moves = botMoves(state);
  state = okState(await post({ cmd: "act", action: "raise", amount: 30 }));
  moves += botMoves(state);
  for (let guard = 0; state.status === "playing" && guard < 50; guard++) {
    state = okState(await post({ cmd: "act", action: state.legal!.check ? "check" : "call" }));
    moves += botMoves(state);
  }
  const reply = await post({ cmd: "review", hand: state.hand });
  if (!("ok" in reply) || !reply.review) throw new Error("no review");
  return { state, moves, review: reply.review };
}

/** SKIP_LEAN=1 skips these tests, which need the built Lean program. */
const skipLean = process.env.SKIP_LEAN === "1";

describe.skipIf(skipLean)("the review's range viewer and Risk explorer", () => {
  it("gives the range viewer's numbers on a graded river decision, and they add up", { timeout: 30_000 }, async () => {
    const { state, review } = await playSeed7();
    expect(state.status).not.toBe("playing");
    const graded = review.decisions.filter((d) => d.label !== null);
    expect(graded).toHaveLength(1);
    const d = graded[0]!;
    expect(d.street).toBe("river");
    const r = d.range;
    if (!r) throw new Error("the graded decision has no range");
    // Hands in the betting set, less the ones your cards block, are the hands left.
    expect(r.blocked).toBeLessThanOrEqual(r.value + r.bluffs);
    expect(r.value + r.bluffs - r.blocked).toBe(r.beat + r.tie + r.lose);
    // 30% of the 1,081 hands for value; Risk 50's 33% bluff share adds 160 bluffs (`ideal_river_set`).
    expect(r.value).toBe(324);
    expect(r.bluffs).toBe(160);
    // The grade's equity comes from the same hands: ties count half.
    expect(d.equity_had).toBeCloseTo((2 * r.beat + r.tie) / (2 * (r.beat + r.tie + r.lose)), 3);
    // Moves that are not graded have no range.
    for (const u of review.decisions.filter((x) => x.label === null)) expect(u.range).toBeUndefined();
  });

  it("has an explorer entry per bot move, and the bot's own Risk gives its own move", { timeout: 30_000 }, async () => {
    const { moves, review } = await playSeed7();
    const entries = review.risk_explorer;
    if (!entries) throw new Error("no risk_explorer");
    expect(moves).toBeGreaterThan(0);
    expect(entries).toHaveLength(moves);
    expect(entries).toHaveLength(review.bot_reasons!.length);
    for (const e of entries) {
      expect(e.risk).toBe(50);
      expect(e.actions).toHaveLength(101);
      expect(e.actions[e.risk]).toBe(e.action);
      if (e.toCall > 0) {
        // Facing a bet, never from a call or raise back to a fold as Risk goes up (T4).
        const firstGo = e.actions.findIndex((a) => a !== "Fold");
        if (firstGo >= 0) expect(e.actions.slice(firstGo).every((a) => a !== "Fold")).toBe(true);
        expect(["raises", "callsAlways", "foldsAlways", "callsFrom"]).toContain(e.effect);
      } else {
        expect(["noBet", "betsAlways", "checksAlways", "bluffsFrom", "varies"]).toContain(e.effect);
      }
      // Risk matters exactly when the move changes.
      expect(e.riskMatters).toBe(new Set(e.actions).size > 1);
      if (e.effect === "callsFrom") {
        const k = e.continuesFrom!;
        expect(e.actions[k - 1]).toBe("Fold");
        expect(e.actions[k]).toBe("Call");
        expect(e.summary).toBe(`Folds at Risk ${k === 1 ? "0" : `0-${k - 1}`}, calls at ${k}-100.`);
      }
    }
    // The bot called the raise to 30 (20 more, to win 40). At Risk 50 a call is judged on plain
    // chips, so it calls there, and at every higher Risk.
    expect(entries.map((e) => e.street)).toEqual(["preflop", "flop", "turn", "river"]);
    expect(entries[0]).toMatchObject({ action: "Call", toCall: 20, pot: 40 });
    expect(entries[0]!.continuesFrom).toBeLessThanOrEqual(50);
    // Its river bet is a value hand from the betting set: it bets at every Risk.
    expect(entries[3]).toMatchObject({ action: "Bet 60", effect: "betsAlways", riskMatters: false, continuesFrom: 0 });
  });

  it("keeps the explorer back while the hand is played", async () => {
    okState(await post({ cmd: "new_game", seed: "7", risk: 50 }));
    const mid = okState(await post({ cmd: "act", action: "raise", amount: 30 }));
    expect(mid.status).toBe("playing");
    const reply = await post({ cmd: "review", hand: mid.hand });
    if (!("ok" in reply) || !reply.review) throw new Error("no review");
    expect(reply.review.risk_explorer).toBeNull();
    expect(reply.review.bot_reasons).toBeNull();
  });
});
