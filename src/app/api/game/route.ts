import { execFileSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { EngineStoppedError, LeanProcess } from "@/lean/process";
import type { ApiReply, LeanCommand, LeanReply } from "@/lean/protocol";

/**
 * The bridge between the browser and the Lean game program. Lean decides the game state;
 * this endpoint supplies private random seeds and reveals them only after game over.
 * One game program runs per server: a local, single-player app.
 */

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * The commit of the server's checkout, read once when the server starts; "unknown" if git
 * fails. Replies carry it next to the program's own build commit (`engineCommit`), because
 * the program may have been built from other files.
 */
const SERVER_COMMIT = (() => {
  try {
    const out = execFileSync("git", ["rev-parse", "--short", "HEAD"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], timeout: 5000 });
    return out.trim() || "unknown";
  } catch {
    return "unknown";
  }
})();

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
  // Any command may ask to see the bot's cards ("Peek at bot's cards"); Lean adds them.
  if (b.peek !== undefined && typeof b.peek !== "boolean") return null;
  const command = parseGameCommand(b);
  return command && b.peek === true ? { ...command, peek: true } : command;
}

/** The command itself, apart from the peek flag. */
function parseGameCommand(b: Record<string, unknown>): LeanCommand | null {
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

const message = (e: unknown) => (e instanceof Error ? e.message : String(e));

/** A program that stopped or hung took its game with it. The browser must offer a new game. */
function gameLost(status: number): Response {
  return Response.json({ error: "The game engine stopped. Start a new game.", state: null, lost: true } satisfies ApiReply, { status });
}

export async function POST(request: Request): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad JSON", state: null } satisfies ApiReply, { status: 400 });
  }
  const command = parseCommand(body);
  // Turned away before Lean sees it: the game, if any, is unchanged.
  if (!command) return Response.json({ error: "unknown or malformed command", state: null } satisfies ApiReply, { status: 400 });
  let lean: LeanProcess;
  try {
    lean = engine();
  } catch (e) {
    // The program could not start at all (for example, it was never built).
    return Response.json({ error: message(e), state: null, lost: true } satisfies ApiReply, { status: 500 });
  }
  let reply: LeanReply;
  try {
    reply = await lean.send(command);
  } catch (e) {
    if (e instanceof EngineStoppedError) return gameLost(503);
    return Response.json({ error: message(e), state: null } satisfies ApiReply, { status: 500 });
  }
  // Lean has no game, but this command needs one: the program restarted since the game began.
  if ("error" in reply && reply.state === null && command.cmd !== "new_game") return gameLost(410);
  if (reply.state) {
    // One seed determines future hands too, so a hand ending must not reveal it.
    if (reply.state.status !== "gameOver") reply.state.seed = null;
    reply.state.serverCommit = SERVER_COMMIT;
  }
  return Response.json(reply satisfies ApiReply);
}
