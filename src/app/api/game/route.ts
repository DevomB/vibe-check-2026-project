import { LeanProcess } from "@/lean/process";
import type { LeanCommand } from "@/lean/protocol";

/**
 * The bridge between the browser and the Lean game program. Each POST carries one command;
 * it is passed to the program and its reply is returned unchanged. One game program runs
 * per server, so there is one game at a time (a local, single-player app).
 */

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Kept on globalThis so that hot reloading in development does not start a second program.
const holder = globalThis as typeof globalThis & { __leanProcess?: LeanProcess };

function engine(): LeanProcess {
  if (!holder.__leanProcess?.alive) holder.__leanProcess = new LeanProcess();
  return holder.__leanProcess;
}

/** Accept only the commands the program understands, with well-formed fields. */
function parseCommand(body: unknown): LeanCommand | null {
  if (typeof body !== "object" || body === null) return null;
  const b = body as Record<string, unknown>;
  switch (b.cmd) {
    case "new_game":
      return typeof b.seed === "string" && /^\d{1,20}$/.test(b.seed) ? { cmd: "new_game", seed: b.seed } : null;
    case "act":
      if (b.action === "fold" || b.action === "check" || b.action === "call") return { cmd: "act", action: b.action };
      if (b.action === "raise" && Number.isSafeInteger(b.amount) && (b.amount as number) >= 0) {
        return { cmd: "act", action: "raise", amount: b.amount as number };
      }
      return null;
    case "bot":
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
    return Response.json(await engine().send(command));
  } catch (e) {
    return Response.json({ error: e instanceof Error ? e.message : String(e), state: null }, { status: 500 });
  }
}
