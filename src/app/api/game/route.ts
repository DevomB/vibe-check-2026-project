import { randomBytes } from "node:crypto";
import { LeanProcess } from "@/lean/process";
import type { LeanCommand } from "@/lean/protocol";

/**
 * The bridge between the browser and the Lean game program. Lean decides the game state;
 * this endpoint supplies private random seeds and reveals them only after game over.
 * One game program runs per server: a local, single-player app.
 */

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Kept on globalThis so that hot reloading in development does not start a second program.
const holder = globalThis as typeof globalThis & { __leanProcess?: LeanProcess };

function engine(): LeanProcess {
  if (!holder.__leanProcess?.alive) holder.__leanProcess = new LeanProcess();
  return holder.__leanProcess;
}

/** A whole number of chips, a slider value or a hand number. */
function isCount(x: unknown): x is number {
  return Number.isSafeInteger(x) && (x as number) >= 0;
}

/**
 * Accept only the commands the program understands, with well-formed fields. Whether a
 * move or slider value is allowed is for Lean to decide, so in-range checks are not made here.
 */
function parseCommand(body: unknown): LeanCommand | null {
  if (typeof body !== "object" || body === null) return null;
  const b = body as Record<string, unknown>;
  switch (b.cmd) {
    case "new_game":
      if (!isCount(b.risk) || !isCount(b.bluff_pct)) return null;
      const seed = b.seed === undefined || b.seed === "" ? randomBytes(8).readBigUInt64LE().toString() : b.seed;
      if (typeof seed !== "string" || !/^\d{1,20}$/.test(seed)) return null;
      return { cmd: "new_game", seed, risk: b.risk, bluff_pct: b.bluff_pct };
    case "act":
      if (b.action === "fold" || b.action === "check" || b.action === "call") return { cmd: "act", action: b.action };
      if ((b.action === "bet" || b.action === "raise") && isCount(b.amount)) return { cmd: "act", action: b.action, amount: b.amount };
      return null;
    case "review":
      return isCount(b.hand) ? { cmd: "review", hand: b.hand } : null;
    case "next_hand":
    case "state":
      return { cmd: b.cmd };
    default:
      return null;
  }
}

export async function POST(request: Request): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad JSON", state: null }, { status: 400 });
  }
  const command = parseCommand(body);
  if (!command) return Response.json({ error: "unknown or malformed command", state: null }, { status: 400 });
  try {
    // A program that stopped took its game with it; a new program has no game until new_game.
    const lost = holder.__leanProcess !== undefined && !holder.__leanProcess.alive;
    const reply = await engine().send(command);
    if (lost && command.cmd !== "new_game" && "error" in reply) {
      return Response.json({ error: "The game engine stopped and this game was lost. Please start a new game.", state: null });
    }
    // One seed determines future hands too, so a hand ending must not reveal it.
    if (reply.state && reply.state.status !== "gameOver") reply.state.seed = null;
    return Response.json(reply);
  } catch (e) {
    return Response.json({ error: e instanceof Error ? e.message : String(e), state: null }, { status: 500 });
  }
}
