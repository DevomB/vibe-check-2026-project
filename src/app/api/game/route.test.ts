import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { type LeanProcess, leanBinaryPath } from "@/lean/process";
import type { ApiReply, LeanReview, LeanState } from "@/lean/protocol";
import { POST } from "./route";

/**
 * Plays through the `/api/game` handler exactly as the browser does (build the Lean
 * program first with `make lean`). Checks that the bridge passes good commands on and
 * turns away malformed ones before they reach Lean.
 */

async function post(body: unknown): Promise<{ status: number; reply: ApiReply }> {
  const res = await POST(new Request("http://localhost/api/game", { method: "POST", body: JSON.stringify(body) }));
  return { status: res.status, reply: (await res.json()) as ApiReply };
}

/** The route keeps its game program here (see route.ts). */
const holder = globalThis as typeof globalThis & { __leanProcess?: LeanProcess };

/** Stop the route's game program, so the next request starts a new one. */
function stopProgram(): void {
  holder.__leanProcess?.kill();
  holder.__leanProcess = undefined;
}

const ENGINE_STOPPED = { error: "The game engine stopped. Start a new game.", state: null, lost: true };

/** SKIP_LEAN=1 skips the tests that need the built Lean program. Without it, a missing program fails them. */
const skipLean = process.env.SKIP_LEAN === "1";

describe("/api/game input checks", () => {
  it.each([
    ["no command", {}],
    ["the removed bot command", { cmd: "bot" }],
    ["a new game without a Risk", { cmd: "new_game", seed: "42" }],
    ["a Risk that is not a whole number", { cmd: "new_game", seed: "42", risk: 50.5 }],
    ["a negative Risk", { cmd: "new_game", seed: "42", risk: -1 }],
    ["a new game with the old Bluff setting", { cmd: "new_game", seed: "42", risk: 50, bluff_pct: 33 }],
    ["a seed that is not digits", { cmd: "new_game", seed: "abc", risk: 50 }],
    ["a raise without an amount", { cmd: "act", action: "raise" }],
    ["a bet without an amount", { cmd: "act", action: "bet" }],
    ["a review without a hand", { cmd: "review" }],
    ["a peek that is a string", { cmd: "state", peek: "yes" }],
    ["a peek that is a number", { cmd: "act", action: "call", peek: 1 }],
    ["a peek that is null", { cmd: "new_game", seed: "42", risk: 50, peek: null }],
  ])("turns away %s", async (_name, body) => {
    const { status, reply } = await post(body);
    expect(status).toBe(400);
    expect("error" in reply).toBe(true);
  });
});

describe("/api/game when the game program fails", () => {
  const saved = { bin: process.env.POKER_BIN, timeout: process.env.POKER_REPLY_TIMEOUT_MS };
  const restore = (key: string, value: string | undefined) => (value === undefined ? delete process.env[key] : (process.env[key] = value));
  afterEach(() => {
    stopProgram();
    restore("POKER_BIN", saved.bin);
    restore("POKER_REPLY_TIMEOUT_MS", saved.timeout);
  });
  /** Use a stand-in program from src/lean/__fixtures__ instead of the Lean one. */
  const useStandIn = (file: string) => {
    stopProgram();
    process.env.POKER_BIN = path.join(process.cwd(), "src", "lean", "__fixtures__", file);
  };

  it("reports a lost game when the program stops, on that request and every later one", async () => {
    useStandIn("exits-at-once.mjs");
    const first = await post({ cmd: "new_game", seed: "1", risk: 0 });
    expect(first.status).toBe(503);
    expect(first.reply).toEqual(ENGINE_STOPPED);
    for (const body of [{ cmd: "act", action: "check" }, { cmd: "state" }, { cmd: "review", hand: 1 }]) {
      const later = await post(body);
      expect(later.reply, JSON.stringify(body)).toEqual(ENGINE_STOPPED);
    }
  });

  it("stops a program that never answers, and reports a lost game", async () => {
    useStandIn("never-answers.mjs");
    process.env.POKER_REPLY_TIMEOUT_MS = "300";
    const { status, reply } = await post({ cmd: "new_game", seed: "1", risk: 0 });
    expect(status).toBe(503);
    expect(reply).toEqual(ENGINE_STOPPED);
  });
});

describe.skipIf(skipLean)("/api/game with the Lean program", () => {
  it("finds the built Lean program", () => {
    const bin = leanBinaryPath();
    expect(existsSync(bin), `No Lean game program at ${bin}. Build it with "cd engine && lake build", or set SKIP_LEAN=1.`).toBe(true);
  });

  it.each([undefined, ""])("keeps a server-generated seed private through hand end (%s)", async (seed) => {
    const start = await post({ cmd: "new_game", seed, risk: 0 });
    if (!("ok" in start.reply)) throw new Error(start.reply.error);
    expect(start.reply.state.seed).toBeNull();
    const illegal = await post({ cmd: "act", action: "check" });
    expect("error" in illegal.reply).toBe(true);
    expect(illegal.reply.state?.seed).toBeNull();
    const folded = await post({ cmd: "act", action: "fold" });
    if (!("ok" in folded.reply)) throw new Error(folded.reply.error);
    expect(folded.reply.state.status).toBe("handOver");
    expect(folded.reply.state.seed).toBeNull();
    const review = await post({ cmd: "review", hand: folded.reply.state.hand });
    expect("ok" in review.reply).toBe(true);
    expect(review.reply.state?.seed).toBeNull();
  });

  it("reveals a finished game's seed and replays its cards", async () => {
    const finishes: ApiReply[] = [];
    // At Risk 100 the bot calls the all-in with seed 1's cards, and loses: game over at once.
    for (let attempt = 0; attempt < 2; attempt++) {
      const start = await post({ cmd: "new_game", seed: "1", risk: 100 });
      if (!("ok" in start.reply)) throw new Error(start.reply.error);
      expect(start.reply.state.seed).toBeNull();
      const { reply } = await post({ cmd: "act", action: "raise", amount: 500 });
      if (!("ok" in reply)) throw new Error(reply.error);
      expect(reply.state.status).toBe("gameOver");
      expect(reply.state.seed).toBe("1");
      finishes.push(reply);
    }
    expect(finishes[1]).toEqual(finishes[0]);
  });

  it("accepts bet as a street-total raise", { timeout: 30_000 }, async () => {
    const start = await post({ cmd: "new_game", seed: "42", risk: 50 });
    if (!("ok" in start.reply)) throw new Error(start.reply.error);
    const { status, reply } = await post({ cmd: "act", action: "bet", amount: 20 });
    expect(status).toBe(200);
    expect("ok" in reply).toBe(true);
  });

  it("plays a hand to the end by checking or calling, then reviews it", { timeout: 30_000 }, async () => {
    let { reply } = await post({ cmd: "new_game", seed: "2026", risk: 50 });
    if (!("ok" in reply)) throw new Error(reply.error);
    let s = reply.state;
    expect(s.sliders.risk).toBe(50);
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
    expect(reply.review?.bot_reasons).toEqual(s.botReasons);
  });

  it("adds the replay record: turn mode, engine build and server checkout", async () => {
    let serverCommit = "unknown";
    try {
      serverCommit = execFileSync("git", ["rev-parse", "--short", "HEAD"], { encoding: "utf8" }).trim();
    } catch {}
    const commit = /^([0-9a-f]{4,40}|unknown)$/;
    const start = await post({ cmd: "new_game", seed: "1", risk: 100 });
    if (!("ok" in start.reply)) throw new Error(start.reply.error);
    expect(start.reply.state.turnMode).toBe("exact");
    expect(start.reply.state.engineCommit).toMatch(commit);
    expect(start.reply.state.serverCommit).toBe(serverCommit);
    const illegal = await post({ cmd: "act", action: "check" });
    expect(illegal.reply.state).toMatchObject({ turnMode: "exact", serverCommit });
    const { reply } = await post({ cmd: "act", action: "raise", amount: 500 });
    if (!("ok" in reply)) throw new Error(reply.error);
    expect(reply.state.status).toBe("gameOver");
    expect(reply.state).toMatchObject({ seed: "1", sliders: { risk: 100 }, turnMode: "exact", serverCommit });
    expect(reply.state.engineCommit).toBe(start.reply.state.engineCommit);
  });

  it("hides the bot's cards mid-hand, and shows them only when a command asks to peek", async () => {
    const start = await post({ cmd: "new_game", seed: "7", risk: 50 });
    if (!("ok" in start.reply)) throw new Error(start.reply.error);
    expect(start.reply.state.status).toBe("playing");
    expect(start.reply.state.players[1].cards).toBeNull();
    const peeked = await post({ cmd: "state", peek: true });
    if (!("ok" in peeked.reply)) throw new Error(peeked.reply.error);
    expect(peeked.reply.state.players[1].cards).toHaveLength(2);
    for (const card of peeked.reply.state.players[1].cards!) expect(card).toMatch(/^[2-9TJQKA][cdhs]$/);
    // The seed and the bot's reasons stay hidden.
    expect(peeked.reply.state.seed).toBeNull();
    expect(peeked.reply.state.botReasons).toBeNull();
    const plain = await post({ cmd: "state", peek: false });
    if (!("ok" in plain.reply)) throw new Error(plain.reply.error);
    expect(plain.reply.state.players[1].cards).toBeNull();
  });

  it("changes nothing else by peeking: the same seed and moves give the same game", { timeout: 120_000 }, async () => {
    /** Two hands of check/call from seed 2026, with every command peeking or none. */
    async function play(peek: boolean): Promise<{ states: LeanState[]; reviews: (LeanReview | undefined)[] }> {
      const extra = peek ? { peek: true } : {};
      const states: LeanState[] = [];
      const reviews: (LeanReview | undefined)[] = [];
      const send = async (body: object) => {
        const { reply } = await post({ ...body, ...extra });
        if (!("ok" in reply)) throw new Error(reply.error);
        states.push(reply.state);
        return reply;
      };
      let s = (await send({ cmd: "new_game", seed: "2026", risk: 50 })).state;
      for (let hand = 0; hand < 2 && s.status !== "gameOver"; hand++) {
        for (let guard = 0; s.status === "playing" && guard < 50; guard++) {
          await send({ cmd: "state" });
          s = (await send({ cmd: "act", action: s.legal!.check ? "check" : "call" })).state;
        }
        reviews.push((await send({ cmd: "review", hand: s.hand })).review);
        if (s.status === "handOver") s = (await send({ cmd: "next_hand" })).state;
      }
      return { states, reviews };
    }
    const hideBotCards = (s: LeanState) => ({ ...s, players: [s.players[0], { ...s.players[1], cards: null }] });
    const plain = await play(false);
    const peeked = await play(true);
    expect(peeked.states.map(hideBotCards)).toEqual(plain.states.map(hideBotCards));
    expect(peeked.reviews).toEqual(plain.reviews);
    // Mid-hand, only the peeking game showed the bot's cards.
    const midHand = (states: LeanState[]) => states.filter((s) => s.status === "playing");
    expect(midHand(plain.states).every((s) => s.players[1].cards === null)).toBe(true);
    expect(midHand(peeked.states).every((s) => s.players[1].cards?.length === 2)).toBe(true);
  });

  it("passes a Risk out of range to Lean, which rejects it", async () => {
    const { status, reply } = await post({ cmd: "new_game", seed: "1", risk: 101 });
    expect(status).toBe(200);
    expect(reply).toMatchObject({ error: "risk must be 0-100" });
  });

  it("keeps the game after a malformed request", async () => {
    const start = await post({ cmd: "new_game", seed: "9", risk: 50 });
    if (!("ok" in start.reply)) throw new Error(start.reply.error);
    const bad = await post({ cmd: "act", action: "raise" });
    expect(bad.status).toBe(400);
    expect(bad.reply).toEqual({ error: "unknown or malformed command", state: null });
    const after = await post({ cmd: "state" });
    if (!("ok" in after.reply)) throw new Error(after.reply.error);
    expect(after.reply.state).toEqual({ ...start.reply.state, events: [] });
  });

  it("reports a game lost to a crash on every later request, until a new game", async () => {
    const start = await post({ cmd: "new_game", seed: "9", risk: 50 });
    if (!("ok" in start.reply)) throw new Error(start.reply.error);
    const crashed = holder.__leanProcess!;
    crashed.kill();
    await vi.waitFor(() => expect(crashed.alive).toBe(false));
    for (const body of [{ cmd: "act", action: "call" }, { cmd: "state" }, { cmd: "next_hand" }, { cmd: "review", hand: 1 }]) {
      const { status, reply } = await post(body);
      expect(status, JSON.stringify(body)).toBe(410);
      expect(reply, JSON.stringify(body)).toEqual(ENGINE_STOPPED);
    }
    const again = await post({ cmd: "new_game", seed: "9", risk: 50 });
    expect("ok" in again.reply).toBe(true);
  });
});
