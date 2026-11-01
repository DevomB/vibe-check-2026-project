import { existsSync } from "node:fs";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { type Action, type HandState, applyAction, handSeed, seededDeck, startHand } from "@/engine";
import { LeanProcess, leanBinaryPath } from "./process";
import type { LeanCommand, LeanEvent, LeanReply, LeanState } from "./protocol";

/**
 * Plays games through the real Lean game program (build it first with `make lean`).
 * Checks the rules the browser relies on, and replays every hand, with the bot moves Lean
 * reports, in the TypeScript prototype engine, which deals the same cards for a seed, to
 * check both engines agree.
 */

const TOTAL_CHIPS = 1000;
const config = { smallBlind: 5, bigBlind: 10 };
const LABELS = ["Best", "Good", "Inaccuracy", "Mistake", "Blunder"];

/** Small seeded generator for picking test moves. */
function picker(seed: number) {
  let a = seed >>> 0;
  return (n: number) => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), a | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return (((t ^ (t >>> 14)) >>> 0) % n) | 0;
  };
}

/** A random legal move for the human, from the buttons Lean offers. */
function humanMove(s: LeanState, pick: (n: number) => number): LeanCommand {
  const legal = s.legal!;
  const r = pick(20);
  if (r === 0 && legal.fold) return { cmd: "act", action: "fold" };
  if (r <= 4 && legal.raise) {
    const { min, max } = legal.raise;
    const amount = pick(4) === 0 ? max : min + pick(Math.max(1, Math.min(max - min, 60) + 1));
    return { cmd: "act", action: "raise", amount: Math.min(amount, max) };
  }
  return { cmd: "act", action: legal.check ? "check" : "call" };
}

/** The same move, for the TypeScript engine. */
function toTsAction(c: LeanCommand): Action {
  if (c.cmd !== "act") throw new Error("not a move");
  return c.action === "bet" || c.action === "raise" ? { type: "raise", to: c.amount } : { type: c.action };
}

/** Apply the moves Lean reports (the human's and the bot's) to the TypeScript engine. */
function replayEvents(h: HandState, events: LeanEvent[]): HandState {
  for (const e of events) {
    if (e.type !== "action") continue;
    expect(e.player).toBe(h.toAct);
    h = applyAction(h, e.action === "raise" ? { type: "raise", to: e.to! } : { type: e.action });
  }
  return h;
}

const botMoveCount = (events: LeanEvent[]) => events.filter((e) => e.type === "action" && e.player === 1).length;

/** SKIP_LEAN=1 skips these tests. Without it, a missing Lean program fails them. */
const skipLean = process.env.SKIP_LEAN === "1";

describe.skipIf(skipLean)("Lean game program", () => {
  let lean: LeanProcess;
  beforeAll(() => {
    lean = new LeanProcess();
  });
  afterAll(() => lean?.close());

  it("finds the built Lean program", () => {
    const bin = leanBinaryPath();
    expect(existsSync(bin), `No Lean game program at ${bin}. Build it with "cd engine && lake build", or set SKIP_LEAN=1.`).toBe(true);
  });

  async function call(c: LeanCommand): Promise<Extract<LeanReply, { ok: true }>> {
    const reply = await lean.send(c);
    if (!("ok" in reply)) throw new Error(`Lean rejected ${JSON.stringify(c)}: ${reply.error}`);
    return reply;
  }
  const send = async (c: LeanCommand): Promise<LeanState> => (await call(c)).state;
  const newGame = (seed: string, risk = 50) => send({ cmd: "new_game", seed, risk });

  it("rejects bad commands and leaves the game unchanged", async () => {
    const start = await newGame("42");
    for (const bad of [
      { cmd: "act", action: start.legal!.check ? "call" : "check" },
      { cmd: "act", action: "raise", amount: 15 },
      { cmd: "act", action: "raise", amount: 501 },
      { cmd: "bot" },
      { cmd: "next_hand" },
      { cmd: "new_game", seed: "1", risk: 101 },
      // Bluff is no longer a setting: Lean derives it from Risk.
      { cmd: "new_game", seed: "1", risk: 50, bluff_pct: 33 },
      { cmd: "review", hand: start.hand + 1 },
    ] as LeanCommand[]) {
      const reply = await lean.send(bad);
      expect("error" in reply, JSON.stringify(bad)).toBe(true);
      expect({ ...reply.state, events: [] }).toEqual({ ...start, events: [] });
    }
  });

  it("stores Risk, accepts both ends of its range, and derives the bot's settings from it", async () => {
    // The ends are the old two-slider bots the demo scenes use: Ivy and Vex.
    expect((await newGame("5", 0)).sliders).toEqual({ risk: 0, caution: 100, bluffPct: 0 });
    expect((await newGame("5", 100)).sliders).toEqual({ risk: 100, caution: 0, bluffPct: 60 });
    const s = await newGame("5", 37);
    expect(s.sliders.risk).toBe(37);
    expect(Number.isInteger(s.sliders.caution) && s.sliders.caution >= 0 && s.sliders.caution <= 100).toBe(true);
    expect(Number.isInteger(s.sliders.bluffPct) && s.sliders.bluffPct >= 0 && s.sliders.bluffPct <= 60).toBe(true);
  });

  it("keeps the bot's cards and reasons hidden until the hand is over", async () => {
    const s = await newGame("7");
    expect(s.players[0].cards).toHaveLength(2);
    expect(s.players[1].cards).toBeNull();
    expect(s.botReasons).toBeNull();
    const folded = await send({ cmd: "act", action: "fold" });
    expect(folded.result?.outcome).toBe("fold");
    expect(folded.players[1].cards).toBeNull();
    expect(folded.botReasons).toHaveLength(botMoveCount(s.events));
  });

  // The bot takes up to about a second on the turn, so this plays fewer, longer games.
  it("plays 12 random games by the rules, and agrees with the TypeScript engine", { timeout: 600_000 }, async () => {
    let hands = 0;
    for (let game = 0; game < 12; game++) {
      const pick = picker(game + 1);
      const seed = BigInt(1000 + game);
      let s = await newGame(seed.toString(), (game * 37) % 101);
      // Stacks at the start of each hand: what the previous hand ended with.
      let startStacks = [500, 500];

      for (let handGuard = 0; handGuard < 400; handGuard++) {
        // Replay this hand in the TypeScript engine from the same stacks, button and cards,
        // including any bot moves Lean made before the human's first turn.
        let ts = startHand(
          startStacks.map((stack, i) => ({ id: String(i), name: String(i), stack })),
          s.button,
          config,
          Math.random,
          seededDeck(handSeed(seed, s.hand)),
        );
        expect(s.players[0].cards).toEqual(ts.players[0]!.hole);
        ts = replayEvents(ts, s.events);
        let botMoves = botMoveCount(s.events);
        hands++;

        for (let moveGuard = 0; s.status === "playing" && moveGuard < 500; moveGuard++) {
          // Rules the screen relies on, after every reply.
          const chips = s.pot + s.players.reduce((sum, p) => sum + p.stack + p.bet, 0);
          expect(chips).toBe(TOTAL_CHIPS);
          // Lean has played the bot, so a reply in a live hand always waits for the human.
          expect(s.toAct).toBe(0);
          expect(ts.toAct).toBe(0);
          expect(s.legal).not.toBeNull();
          expect(s.players[1].cards).toBeNull();
          expect(s.botReasons).toBeNull();
          expect(s.board).toEqual(ts.board);

          const command = humanMove(s, pick);
          s = await send(command);
          expect(s.events[0]).toMatchObject({ type: "action", player: 0, action: toTsAction(command).type });
          ts = replayEvents(ts, s.events);
          botMoves += botMoveCount(s.events);
        }

        // The hand is over: both engines paid out the same way.
        expect(s.status).not.toBe("playing");
        expect(ts.result).not.toBeNull();
        expect(s.board).toEqual(ts.board);
        expect(s.players.map((p) => p.stack)).toEqual(ts.players.map((p) => p.stack));
        expect(s.result!.winnings).toEqual(ts.result!.winnings);
        expect(s.players.reduce((sum, p) => sum + p.stack, 0)).toBe(TOTAL_CHIPS);
        if (s.result!.showdown) expect(s.players[1].cards).toEqual(ts.players[1]!.hole);
        expect(s.botReasons).toHaveLength(botMoves);

        // The review changes nothing, and grades only river calls and folds.
        const { state: after, review } = await call({ cmd: "review", hand: s.hand });
        expect({ ...after, events: [] }).toEqual({ ...s, events: [] });
        expect(review?.hand).toBe(s.hand);
        for (const d of review!.decisions) {
          if (d.label === null) continue;
          expect(LABELS).toContain(d.label);
          expect(d.street).toBe("river");
          expect(["call", "fold"]).toContain(d.your_action);
          expect(d.worth_bb!.fold).toBe(0);
          expect(d.equity_had!).toBeGreaterThanOrEqual(0);
          expect(d.equity_had!).toBeLessThanOrEqual(1);
          const mine = d.your_action === "call" ? d.worth_bb!.call : d.worth_bb!.fold;
          if (d.label === "Best") expect(mine).toBe(Math.max(d.worth_bb!.call, d.worth_bb!.fold));
        }

        if (s.status === "gameOver") break;
        startStacks = s.players.map((p) => p.stack);
        s = await send({ cmd: "next_hand" });
      }
      expect(s.status).toBe("gameOver");
    }
    expect(hands).toBeGreaterThan(30);
  });
});
