import { describe, expect, it, vi } from "vitest";
import type { LeanProcess } from "@/lean/process";
import type { RouteReply, RouteState } from "@/lean/protocol";
import { POST } from "./route";

/**
 * Mystery games through the `/api/game` handler: the route picks the bot's settings, hides them
 * (and everything that would give them away) from every reply until a valid reveal, and then
 * shows everything again. Normal games must not change.
 */

async function post(body: unknown): Promise<{ status: number; reply: RouteReply }> {
  const res = await POST(new Request("http://localhost/api/game", { method: "POST", body: JSON.stringify(body) }));
  return { status: res.status, reply: (await res.json()) as RouteReply };
}

/** Send a command that must be accepted, and return its state. */
async function ok(body: unknown): Promise<{ state: RouteState; reply: RouteReply }> {
  const { status, reply } = await post(body);
  if (!("ok" in reply)) throw new Error(`${JSON.stringify(body)} was rejected (${status}): ${reply.error}`);
  return { state: reply.state, reply };
}

/** The route keeps its game program here (see route.ts). */
const holder = globalThis as typeof globalThis & { __leanProcess?: LeanProcess };

/** Keys whose values depend on the hidden settings: the sliders, the bot's reasons, and the review. */
const SECRET_KEYS = ["sliders", "botReasons", "bot_reasons", "review", "label", "worth_bb", "equity_had", "equity_needed", "range", "risk_explorer"];

/** A reply from an unrevealed Mystery game: nothing in it may tell the settings or the seed. */
function expectHidden(reply: RouteReply): void {
  const text = JSON.stringify(reply);
  for (const key of SECRET_KEYS) expect(text, `"${key}" in ${text.slice(0, 200)}`).not.toContain(`"${key}"`);
  // The bot's reasons say "at Risk 50" or "at Bluff 33%"; no such text may appear anywhere.
  expect(text).not.toMatch(/\b(Risk|Bluff)\s*\d/);
  if (reply.state) {
    expect("sliders" in reply.state).toBe(false);
    expect("botReasons" in reply.state).toBe(false);
    expect(reply.state.seed).toBeNull();
  }
}

/**
 * Play the current hand to its end by checking or calling, poking at every disclosure path on
 * the way (state, peek, an illegal move, a review mid-hand and after). Every reply goes to `seen`.
 */
async function playHand(seen: RouteReply[]): Promise<RouteState> {
  const send = async (body: unknown) => {
    const { reply } = await post(body);
    seen.push(reply);
    return reply;
  };
  let reply = await send({ cmd: "state" });
  if (!("ok" in reply)) throw new Error(reply.error);
  let s = reply.state;
  const hand = s.hand;
  await send({ cmd: "state", peek: true });
  await send({ cmd: "review", hand });
  for (let guard = 0; s.status === "playing" && guard < 50; guard++) {
    // An illegal move gets an error that carries the unchanged state.
    await send({ cmd: "act", action: s.legal!.check ? "call" : "check" });
    reply = await send({ cmd: "act", action: s.legal!.check ? "check" : "call" });
    if (!("ok" in reply)) throw new Error(reply.error);
    s = reply.state;
  }
  reply = await send({ cmd: "review", hand });
  expect(reply).toMatchObject({ ok: true, reviewDeferred: true });
  return s;
}

/** From the current hand, go on to the next one. */
async function nextHand(seen: RouteReply[]): Promise<RouteState> {
  const { reply } = await post({ cmd: "next_hand" });
  seen.push(reply);
  if (!("ok" in reply)) throw new Error(reply.error);
  return reply.state;
}

describe.skipIf(process.env.SKIP_LEAN === "1")("Mystery games through /api/game", () => {
  it("hides the settings until a valid reveal after 3 hands, then shows everything", { timeout: 240_000 }, async () => {
    const seen: RouteReply[] = [];
    const start = await post({ cmd: "new_game", mystery: true });
    seen.push(start.reply);
    expect(start.status).toBe(200);

    let s = await playHand(seen);
    if (s.status === "handOver") s = await nextHand(seen);
    s = await playHand(seen);

    // Two hands finished: too early to guess.
    if (s.status !== "gameOver") {
      const early = await post({ cmd: "reveal", risk: 50, bluff_pct: 30 });
      seen.push(early.reply);
      expect(early.status).toBe(400);
      expect(early.reply).toMatchObject({ error: "Play 3 hands before you guess (2 finished so far)." });
      expect(early.reply.state).not.toBeNull();
      s = await nextHand(seen);
      s = await playHand(seen);
    }
    for (const reply of seen) expectHidden(reply);

    // Bad guesses are turned away, and still nothing is shown.
    for (const bad of [
      { risk: 101, bluff_pct: 30 },
      { risk: 50, bluff_pct: 61 },
      { risk: -1, bluff_pct: 30 },
      { risk: 50.5, bluff_pct: 30 },
      { risk: "50", bluff_pct: 30 },
      { bluff_pct: 30 },
      { risk: 50 },
    ]) {
      const { status, reply } = await post({ cmd: "reveal", ...bad });
      expect(status, JSON.stringify(bad)).toBe(400);
      expectHidden(reply);
    }
    expectHidden((await ok({ cmd: "state" })).reply);

    // A good guess: the real settings, the guess, how far off it was, and the full state.
    const { status, reply } = await post({ cmd: "reveal", risk: 40, bluff_pct: 20 });
    expect(status).toBe(200);
    if (!("ok" in reply) || !reply.reveal) throw new Error(JSON.stringify(reply));
    const r = reply.reveal;
    expect(r.risk).toBeGreaterThanOrEqual(0);
    expect(r.risk).toBeLessThanOrEqual(100);
    expect(r.bluff_pct).toBeGreaterThanOrEqual(0);
    expect(r.bluff_pct).toBeLessThanOrEqual(60);
    expect(r.guess).toEqual({ risk: 40, bluff_pct: 20 });
    expect(r.off).toEqual({ risk: Math.abs(40 - r.risk), bluff_pct: Math.abs(20 - r.bluff_pct) });
    expect(reply.state.sliders).toEqual({ risk: r.risk, bluffPct: r.bluff_pct });
    expect(reply.state.botReasons).not.toBeNull();

    // After the reveal nothing is hidden: the review and the reasons are back.
    const after = await ok({ cmd: "review", hand: reply.state.hand });
    expect(after.reply).not.toHaveProperty("reviewDeferred");
    if (!("ok" in after.reply) || !after.reply.review) throw new Error("no review after the reveal");
    expect(after.reply.review.decisions.length).toBeGreaterThan(0);
    expect(after.reply.review.bot_reasons).toEqual(reply.state.botReasons);
    expect(after.state.sliders).toEqual({ risk: r.risk, bluffPct: r.bluff_pct });

    // One guess per game.
    const again = await post({ cmd: "reveal", risk: r.risk, bluff_pct: r.bluff_pct });
    expect(again.status).toBe(400);
    expect(again.reply).toMatchObject({ error: "This Mystery bot was already revealed." });
  });

  it("keeps the seed hidden at game over until the reveal, which game over allows at once", { timeout: 240_000 }, async () => {
    let { state: s } = await ok({ cmd: "new_game", mystery: true });
    // Go all-in whenever raising is allowed, so the game ends in a few hands.
    for (let guard = 0; s.status !== "gameOver" && guard < 400; guard++) {
      const body =
        s.status === "handOver"
          ? { cmd: "next_hand" }
          : s.legal!.raise
            ? { cmd: "act", action: "raise", amount: s.legal!.raise.max }
            : { cmd: "act", action: s.legal!.check ? "check" : "call" };
      const next = await ok(body);
      expectHidden(next.reply);
      s = next.state;
    }
    expect(s.status).toBe("gameOver");
    expect(s.seed).toBeNull();
    expectHidden((await ok({ cmd: "review", hand: s.hand })).reply);

    const { reply } = await ok({ cmd: "reveal", risk: 0, bluff_pct: 0 });
    if (!("ok" in reply) || !reply.reveal) throw new Error("no reveal");
    expect(reply.state.seed).toMatch(/^\d{1,20}$/);
    expect(reply.state.sliders).toEqual({ risk: reply.reveal.risk, bluffPct: reply.reveal.bluff_pct });
  });

  it("turns away a Mystery game sent with a seed or sliders", async () => {
    for (const bad of [
      { mystery: true, seed: "42" },
      { mystery: true, risk: 50 },
      { mystery: true, bluff_pct: 30 },
      { mystery: true, seed: "42", risk: 50, bluff_pct: 30 },
      { mystery: false, seed: "42", risk: 50, bluff_pct: 30 },
      { mystery: "yes" },
    ]) {
      const { status } = await post({ cmd: "new_game", ...bad });
      expect(status, JSON.stringify(bad)).toBe(400);
    }
    // An empty seed is the same as none.
    expectHidden((await ok({ cmd: "new_game", mystery: true, seed: "" })).reply);
  });

  it("turns away a reveal outside a Mystery game", async () => {
    await ok({ cmd: "new_game", seed: "5", risk: 50, bluff_pct: 33 });
    const { status, reply } = await post({ cmd: "reveal", risk: 50, bluff_pct: 33 });
    expect(status).toBe(400);
    expect(reply).toEqual({ error: "There is no Mystery game to reveal.", state: null });
  });

  it("drops the secret when a new game replaces it, but not when a new game is rejected", async () => {
    expectHidden((await ok({ cmd: "new_game", mystery: true })).reply);
    // Lean rejects this new game and keeps the Mystery game, which stays hidden.
    const rejected = await post({ cmd: "new_game", seed: "1", risk: 101, bluff_pct: 33 });
    expect(rejected.reply).toMatchObject({ error: "risk must be 0-100" });
    expectHidden(rejected.reply);
    expectHidden((await ok({ cmd: "state" })).reply);

    // An accepted normal game replaces it: its sliders are shown, and there is nothing to reveal.
    const normal = await ok({ cmd: "new_game", seed: "1", risk: 20, bluff_pct: 10 });
    expect(normal.state.sliders).toEqual({ risk: 20, bluffPct: 10 });
    expect((await post({ cmd: "reveal", risk: 20, bluff_pct: 10 })).status).toBe(400);
  });

  it("drops the secret when the engine is lost", async () => {
    expectHidden((await ok({ cmd: "new_game", mystery: true })).reply);
    const crashed = holder.__leanProcess!;
    crashed.kill();
    await vi.waitFor(() => expect(crashed.alive).toBe(false));
    const guess = await post({ cmd: "reveal", risk: 50, bluff_pct: 30 });
    expect(guess.status).toBe(400);
    expect(guess.reply).toEqual({ error: "There is no Mystery game to reveal.", state: null });
    expect((await post({ cmd: "state" })).reply).toMatchObject({ lost: true, state: null });
    const normal = await ok({ cmd: "new_game", seed: "3", risk: 60, bluff_pct: 0 });
    expect(normal.state.sliders).toEqual({ risk: 60, bluffPct: 0 });
  });

  it("leaves normal games as they were: sliders, reasons, reviews and the game-over seed", { timeout: 120_000 }, async () => {
    let { state: s } = await ok({ cmd: "new_game", seed: "2026", risk: 50, bluff_pct: 33 });
    expect(s.sliders).toEqual({ risk: 50, bluffPct: 33 });
    expect(s.seed).toBeNull();
    for (let guard = 0; s.status === "playing" && guard < 50; guard++) {
      ({ state: s } = await ok({ cmd: "act", action: s.legal!.check ? "check" : "call" }));
    }
    expect(s.botReasons).not.toBeNull();
    const { reply } = await ok({ cmd: "review", hand: s.hand });
    expect(reply).not.toHaveProperty("reviewDeferred");
    if (!("ok" in reply) || !reply.review) throw new Error("no review");
    expect(reply.review.bot_reasons).toEqual(s.botReasons);

    await ok({ cmd: "new_game", seed: "1", risk: 0, bluff_pct: 0 });
    const end = await ok({ cmd: "act", action: "raise", amount: 500 });
    expect(end.state).toMatchObject({ status: "gameOver", seed: "1", sliders: { risk: 0, bluffPct: 0 } });
  });
});
