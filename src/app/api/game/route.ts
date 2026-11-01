import { execFileSync } from "node:child_process";
import { randomBytes, randomInt } from "node:crypto";
import { EngineStoppedError, LeanProcess } from "@/lean/process";
import {
  type ApiReply,
  type LeanCommand,
  type LeanReply,
  type LeanState,
  type MysteryReveal,
  RISK_MAX,
  type RouteReply,
  type RouteState,
} from "@/lean/protocol";

/**
 * The bridge between the browser and the Lean game program. Lean decides the game state;
 * this endpoint supplies private random seeds and reveals them only after game over.
 * One game program runs per server: a local, single-player app.
 *
 * Mystery games (MVP §10, S9): the route also picks the bot's Risk at random, the way it picks
 * a private seed, and hides it (and what Lean derives from it) from every reply until the
 * player has guessed.
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

/**
 * A Mystery game's hidden settings. They belong to one program's game: when that program
 * stops, the game is gone, and so is the secret.
 */
interface MysterySecret {
  engine: LeanProcess;
  risk: number;
  /** Set by the reveal. After it, nothing is hidden. */
  reveal: MysteryReveal | null;
}

// Kept on globalThis so that hot reloading in development does not start a second program.
const holder = globalThis as typeof globalThis & { __leanProcess?: LeanProcess; __mystery?: MysterySecret };

function engine(): LeanProcess {
  if (!holder.__leanProcess?.alive) holder.__leanProcess = new LeanProcess();
  return holder.__leanProcess;
}

/** The current game's Mystery secret, or null if the current game is not a Mystery game. */
function currentMystery(): MysterySecret | null {
  const m = holder.__mystery;
  // The program that held that game stopped or was replaced: the game, and its secret, are gone.
  if (m && (m.engine !== holder.__leanProcess || !m.engine.alive)) holder.__mystery = undefined;
  return holder.__mystery ?? null;
}

/** The current game is a Mystery game that has not been revealed yet. */
function settingsHidden(): boolean {
  return currentMystery()?.reveal === null;
}

/** A Mystery game may be revealed after this many finished hands, or at game over. */
const REVEAL_AFTER_HANDS = 3;

/** A whole number of chips, a slider value or a hand number. */
function isCount(x: unknown): x is number {
  return Number.isSafeInteger(x) && (x as number) >= 0;
}

/** A private, server-generated 64-bit seed, as digits. */
function privateSeed(): string {
  return randomBytes(8).readBigUInt64LE().toString();
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
      // The bot has one setting, Risk. A Bluff value is from the old two-slider protocol:
      // turning it away (see `BLUFF_REMOVED`) is better than silently playing a different bot.
      if (!isCount(b.risk) || b.bluff_pct !== undefined) return null;
      const seed = b.seed === undefined || b.seed === "" ? privateSeed() : b.seed;
      if (typeof seed !== "string" || !/^\d{1,20}$/.test(seed)) return null;
      return { cmd: "new_game", seed, risk: b.risk };
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

/** A request the route handles: a command for Lean, the start of a Mystery game, or a reveal. */
type RouteRequest =
  | { kind: "lean"; command: LeanCommand }
  | { kind: "mystery"; peek: boolean }
  | { kind: "reveal"; risk: number; peek: boolean };

/**
 * Lean's commands as `parseCommand` reads them, plus the two Mystery requests the route
 * answers itself. A guess must be a whole number in Risk's range; the route checks that,
 * because Lean never sees it.
 */
function parseRequest(body: unknown): RouteRequest | null {
  if (typeof body !== "object" || body === null) return null;
  const b = body as Record<string, unknown>;
  if (b.peek !== undefined && typeof b.peek !== "boolean") return null;
  const peek = b.peek === true;
  if (b.cmd === "new_game" && b.mystery !== undefined) {
    // A Mystery game picks its own seed and Risk. Sending either is a mistake, and an entered
    // seed would let the player replay the game to find the hidden Risk.
    const seedSent = b.seed !== undefined && b.seed !== "";
    if (b.mystery !== true || seedSent || b.risk !== undefined || b.bluff_pct !== undefined) return null;
    return { kind: "mystery", peek };
  }
  if (b.cmd === "reveal") {
    if (!isCount(b.risk) || b.risk > RISK_MAX || b.bluff_pct !== undefined) return null;
    return { kind: "reveal", risk: b.risk, peek };
  }
  const command = parseCommand(body);
  return command && { kind: "lean", command };
}

const message = (e: unknown) => (e instanceof Error ? e.message : String(e));

/** Lean's own words for a `new_game` that still sends the old Bluff slider. */
const BLUFF_REMOVED = "bluff_pct was removed; Risk sets both";

/** Why a request was turned away before Lean saw it. */
function refusal(body: unknown): string {
  const b = typeof body === "object" && body !== null ? (body as Record<string, unknown>) : {};
  return (b.cmd === "new_game" || b.cmd === "reveal") && b.bluff_pct !== undefined ? BLUFF_REMOVED : "unknown or malformed command";
}

/** A program that stopped or hung took its game with it. The browser must offer a new game. */
function gameLost(status: number): Response {
  holder.__mystery = undefined;
  return Response.json({ error: "The game engine stopped. Start a new game.", state: null, lost: true } satisfies ApiReply, { status });
}

/**
 * A state the browser may see. Seeds stay private until game over. In an unrevealed Mystery
 * game, the bot's settings and its reasons (which quote them) are removed, and the seed stays
 * hidden even at game over: with the seed and the moves, replaying the game at each setting
 * would find the hidden ones.
 */
function publicState(s: LeanState): RouteState {
  // One seed determines future hands too, so a hand ending must not reveal it.
  if (s.status !== "gameOver") s.seed = null;
  s.serverCommit = SERVER_COMMIT;
  if (!settingsHidden()) return s;
  const hidden: RouteState = { ...s, seed: null };
  delete hidden.sliders;
  delete hidden.botReasons;
  return hidden;
}

/** Lean's reply as the browser may see it (see `publicState`). */
function publicReply(reply: LeanReply): RouteReply {
  if ("error" in reply) return { error: reply.error, state: reply.state && publicState(reply.state) };
  const state = publicState(reply.state);
  if (!reply.review) return { ok: true, state };
  // Every number in a review (labels, worths, equities) comes from the bot's river betting set,
  // whose bluff share Lean derives from Risk, and its reasons quote the settings. So the whole
  // review waits for the reveal.
  return settingsHidden() ? { ok: true, state, reviewDeferred: true } : { ok: true, state, review: reply.review };
}

/** Hands already finished: those before the current one, and the current one once it is over. */
function finishedHands(s: LeanState): number {
  return s.status === "playing" ? s.hand - 1 : s.hand;
}

/**
 * The player's guess at a Mystery bot's Risk. It is accepted once per game, after 3 finished
 * hands or at game over. The reply has the real Risk, how far off the guess was, and the full
 * state, whose `sliders` now show what Lean derived from that Risk.
 */
async function reveal(lean: LeanProcess, guess: { risk: number; peek: boolean }): Promise<Response> {
  const turnedAway = (error: string, state: RouteState | null = null) => Response.json({ error, state } satisfies RouteReply, { status: 400 });
  const m = currentMystery();
  if (!m) return turnedAway("There is no Mystery game to reveal.");
  if (m.reveal) return turnedAway("This Mystery bot was already revealed.");
  let reply: LeanReply;
  try {
    reply = await lean.send(guess.peek ? { cmd: "state", peek: true } : { cmd: "state" });
  } catch (e) {
    if (e instanceof EngineStoppedError) return gameLost(503);
    return Response.json({ error: message(e), state: null } satisfies ApiReply, { status: 500 });
  }
  if ("error" in reply) return gameLost(410);
  // A new game may have started while this request waited; its state must not be shown here.
  if (currentMystery() !== m) return turnedAway("This game was replaced by a newer one.");
  // Another guess may have been accepted while this one waited. Only the first one counts.
  if (m.reveal) return turnedAway("This Mystery bot was already revealed.");
  const done = finishedHands(reply.state);
  if (reply.state.status !== "gameOver" && done < REVEAL_AFTER_HANDS) {
    return turnedAway(`Play ${REVEAL_AFTER_HANDS} hands before you guess (${done} finished so far).`, publicState(reply.state));
  }
  m.reveal = { risk: m.risk, guess: guess.risk, off: Math.abs(guess.risk - m.risk) };
  return Response.json({ ok: true, state: publicState(reply.state), reveal: m.reveal } satisfies RouteReply);
}

export async function POST(request: Request): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad JSON", state: null } satisfies ApiReply, { status: 400 });
  }
  const parsed = parseRequest(body);
  // Turned away before Lean sees it: the game, if any, is unchanged.
  if (!parsed) return Response.json({ error: refusal(body), state: null } satisfies ApiReply, { status: 400 });
  let lean: LeanProcess;
  try {
    lean = engine();
  } catch (e) {
    // The program could not start at all (for example, it was never built).
    holder.__mystery = undefined;
    return Response.json({ error: message(e), state: null, lost: true } satisfies ApiReply, { status: 500 });
  }
  if (parsed.kind === "reveal") return reveal(lean, parsed);
  let command: LeanCommand;
  let picked: { risk: number } | null = null;
  if (parsed.kind === "lean") {
    command = parsed.command;
  } else {
    // A Mystery game: the route picks Risk at random, like the private seed.
    picked = { risk: randomInt(RISK_MAX + 1) };
    command = { cmd: "new_game", seed: privateSeed(), risk: picked.risk, ...(parsed.peek ? { peek: true } : {}) };
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
  // An accepted new game replaces the old game and its secret. A rejected one keeps both.
  if (command.cmd === "new_game" && "ok" in reply) holder.__mystery = picked ? { engine: lean, ...picked, reveal: null } : undefined;
  return Response.json(publicReply(reply));
}
