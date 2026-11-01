import { describe, expect, it } from "vitest";
import { POST } from "@/app/api/game/route";
import { TABLE } from "@/hooks/useGame";
import type { ApiReply, LeanCommand, LeanReview, LeanState } from "@/lean/protocol";
import { CHALLENGES, type Challenge, atRiverDecision, practiceVerdict } from "./challenges";
import { isRiverSetGrade } from "@/lib/review";

/**
 * Replays each practice spot through the `/api/game` handler, the way the app loads it, and
 * checks that Lean still stops at the river decision and grades both answers as recorded.
 * A changed engine that moves the cards or the grades fails here.
 */

async function send(body: LeanCommand): Promise<{ state: LeanState; review?: LeanReview }> {
  const res = await POST(new Request("http://localhost/api/game", { method: "POST", body: JSON.stringify(body) }));
  const reply = (await res.json()) as ApiReply;
  if (!("ok" in reply)) throw new Error(`${JSON.stringify(body)} was rejected: ${reply.error}`);
  return reply;
}

/** The spot's game, up to its river decision. */
async function load(c: Challenge): Promise<LeanState> {
  let { state } = await send({ cmd: "new_game", seed: c.seed, risk: c.risk });
  for (const m of c.moves) ({ state } = await send({ cmd: "act", ...m }));
  return state;
}

/** Load the spot, answer `choice`, and fetch Lean's review of the hand. */
async function answer(c: Challenge, choice: "call" | "fold") {
  await load(c);
  const { state } = await send({ cmd: "act", action: choice });
  const { review } = await send({ cmd: "review", hand: 1 });
  if (!review) throw new Error("no review");
  return { state, review, graded: review.decisions.find(isRiverSetGrade) };
}

describe.skipIf(process.env.SKIP_LEAN === "1")("practice challenges through /api/game", () => {
  it.each(CHALLENGES.map((c) => [c.id, c] as const))("%s stops at the bot's opening river bet", async (_id, c) => {
    const s = await load(c);
    expect(atRiverDecision(s)).toBe(true);
    // The bot opened the river: it has bet and the human has not.
    expect(s.players[1].bet).toBeGreaterThan(0);
    expect(s.players[0].bet).toBe(0);
    expect(s.legal?.fold).toBe(true);
  });

  it.each(CHALLENGES.flatMap((c) => (["call", "fold"] as const).map((choice) => [c.id, choice, c] as const)))(
    "%s: Lean grades %s as recorded",
    { timeout: 120_000 },
    async (_id, choice, c) => {
      const { state, review, graded } = await answer(c, choice);
      expect(state.status).not.toBe("playing");
      expect(graded).toMatchObject({ street: "river", your_action: choice, label: c.labels[choice], worth_bb: c.worth_bb });
      const verdict = practiceVerdict(review, state.result);
      expect(verdict).toMatchObject({ choice, label: c.labels[choice] });
      if (choice === c.best) {
        expect(state.result).toMatchObject({ outcome: c.result_if_best.outcome, showdown: c.result_if_best.showdown });
        expect(state.players[0].stack - TABLE.startingStack).toBe(c.result_if_best.human_net_chips);
      }
      // The "right decision, unlucky result" line shows only for the spot made for it.
      expect(verdict.unlucky).toBe(c.id === "right-and-lose" && choice === "call");
    },
  );
});

describe("the practice spots", () => {
  it("records one Best answer per spot, and each spot's kind", () => {
    for (const c of CHALLENGES) {
      expect(c.labels[c.best], c.id).toBe("Best");
      expect(c.labels[c.best === "call" ? "fold" : "call"], c.id).not.toBe("Best");
    }
    const byId = Object.fromEntries(CHALLENGES.map((c) => [c.id, c]));
    expect(byId["catch-bluff"]?.best).toBe("call");
    expect(["Mistake", "Blunder"]).toContain(byId["avoid-bad-call"]?.labels.call);
    expect(byId["right-and-lose"]?.result_if_best.human_net_chips).toBeLessThan(0);
  });

  it("finds no grade when the player raises instead", () => {
    const review: LeanReview = { hand: 1, decisions: [{ street: "river", your_action: "raise", label: null, worth_bb: null, equity_had: null, equity_needed: null }], bot_reasons: null };
    expect(practiceVerdict(review, null)).toEqual({ choice: null, label: null, unlucky: false });
  });
});
