import { KuhnProcess, parseKuhnCommand } from "@/lean/kuhn";

/**
 * The bridge between the Kuhn poker page and the Lean program `kuhn-serve`. Each POST carries
 * one command; its reply is passed back unchanged. One program runs per server.
 */

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Kept on globalThis so hot reloading in development does not start a second program.
const holder = globalThis as typeof globalThis & { __kuhnProcess?: KuhnProcess };

function engine(): KuhnProcess {
  if (!holder.__kuhnProcess?.alive) holder.__kuhnProcess = new KuhnProcess();
  return holder.__kuhnProcess;
}

export async function POST(request: Request): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad JSON", state: null }, { status: 400 });
  }
  const command = parseKuhnCommand(body);
  if (!command) return Response.json({ error: "unknown or malformed command", state: null }, { status: 400 });
  try {
    return Response.json(await engine().send(command));
  } catch (e) {
    return Response.json({ error: e instanceof Error ? e.message : String(e), state: null }, { status: 500 });
  }
}
