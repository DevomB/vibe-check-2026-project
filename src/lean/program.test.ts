import { existsSync } from "node:fs";
import { afterAll, describe, expect, it } from "vitest";
import { type Action, type HandState, applyAction, handSeed, seededDeck, startHand } from "@/engine";
import { LeanProcess, leanBinaryPath } from "./process";
import type { LeanCommand, LeanState } from "./protocol";

/**
 * Plays games through the real Lean game program (build it first with `lake build`).
 * Checks the rules the browser relies on, and replays every hand in the TypeScript
 * prototype engine, which deals the same cards for a seed, to check both engines agree.
 */

const TOTAL_CHIPS = 1000;
const config = { smallBlind: 5, bigBlind: 10 };

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
  return c.action === "raise" ? { type: "raise", to: c.amount } : { type: c.action };
}

/** The bot's move as the TypeScript engine sees it: check if nothing is owed, else call. */
function botTsAction(h: HandState): Action {
  const p = h.players[h.toAct!]!;
  return h.currentBet - p.streetBet === 0 ? { type: "check" } : { type: "call" };
}

describe.skipIf(!existsSync(leanBinaryPath()))("Lean game program", () => {
  const lean = new LeanProcess();
  afterAll(() => lean.close());

  async function send(c: LeanCommand): Promise<LeanState> {
    const reply = await lean.send(c);
    if (!("ok" in reply)) throw new Error(`Lean rejected ${JSON.stringify(c)}: ${reply.error}`);
    return reply.state;
  }

  it("rejects bad commands and leaves the game unchanged", async () => {
    const start = await send({ cmd: "new_game", seed: "42" });
    for (const bad of [
      { cmd: "act", action: "check" },
      { cmd: "act", action: "raise", amount: 15 },
      { cmd: "act", action: "raise", amount: 501 },
      { cmd: "bot" },
    ] as LeanCommand[]) {
      const reply = await lean.send(bad);
      expect("error" in reply).toBe(true);
      expect({ ...reply.state, events: [] }).toEqual({ ...start, events: [] });
    }
  });

  it("keeps the bot's cards hidden until a showdown", async () => {
    const s = await send({ cmd: "new_game", seed: "7" });
    expect(s.players[0].cards).toHaveLength(2);
    expect(s.players[1].cards).toBeNull();
    const folded = await send({ cmd: "act", action: "fold" });
    expect(folded.result?.outcome).toBe("fold");
    expect(folded.players[1].cards).toBeNull();
  });

  it("plays 40 random games by the rules, and agrees with the TypeScript engine", { timeout: 60_000 }, async () => {
    let hands = 0;
    for (let game = 0; game < 40; game++) {
      const pick = picker(game + 1);
      const seed = BigInt(1000 + game);
      let s = await send({ cmd: "new_game", seed: seed.toString() });
      // Stacks at the start of each hand: what the previous hand ended with.
      let startStacks = [500, 500];

      for (let handGuard = 0; handGuard < 400; handGuard++) {
        // Replay this hand in the TypeScript engine from the same stacks, button and cards.
        let ts = startHand(
          startStacks.map((stack, i) => ({ id: String(i), name: String(i), stack })),
          s.button,
          config,
          Math.random,
          seededDeck(handSeed(seed, s.hand)),
        );
        expect(s.players[0].cards).toEqual(ts.players[0]!.hole);
        hands++;

        for (let moveGuard = 0; s.status === "playing" && moveGuard < 500; moveGuard++) {
          // Rules the screen relies on, after every reply.
          const chips = s.pot + s.players.reduce((sum, p) => sum + p.stack + p.bet, 0);
          expect(chips).toBe(TOTAL_CHIPS);
          expect(s.toAct).toBe(ts.toAct);
          expect(s.legal !== null).toBe(s.toAct === 0);
          expect(s.players[1].cards).toBeNull();

          let command: LeanCommand;
          let tsAction: Action;
          if (s.toAct === 0) {
            command = humanMove(s, pick);
            tsAction = toTsAction(command);
          } else {
            command = { cmd: "bot" };
            tsAction = botTsAction(ts);
          }
          s = await send(command);
          ts = applyAction(ts, tsAction);
          expect(s.board).toEqual(ts.board);
        }

        // The hand is over: both engines paid out the same way.
        expect(s.status).not.toBe("playing");
        expect(ts.result).not.toBeNull();
        expect(s.players.map((p) => p.stack)).toEqual(ts.players.map((p) => p.stack));
        expect(s.result!.winnings).toEqual(ts.result!.winnings);
        expect(s.players.reduce((sum, p) => sum + p.stack, 0)).toBe(TOTAL_CHIPS);
        if (s.result!.showdown) expect(s.players[1].cards).toEqual(ts.players[1]!.hole);

        if (s.status === "gameOver") break;
        startStacks = s.players.map((p) => p.stack);
        s = await send({ cmd: "next_hand" });
      }
      expect(s.status).toBe("gameOver");
    }
    expect(hands).toBeGreaterThan(100);
  });
});
