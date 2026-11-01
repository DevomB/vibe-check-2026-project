import { type ChildProcessWithoutNullStreams, spawn } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import { createInterface } from "node:readline";
import type { LeanCommand, LeanReply } from "./protocol";

/** Where `lake build` puts the game program (`poker.exe` on Windows). Override with POKER_BIN. */
export function leanBinaryPath(): string {
  const name = process.platform === "win32" ? "poker.exe" : "poker";
  return process.env.POKER_BIN ?? path.join(process.cwd(), "engine", ".lake", "build", "bin", name);
}

/**
 * How long one command may wait for its reply. Replies take under a second (the slowest in the
 * 300-game fuzz run, docs/validation/integration-fuzz.json, was a review at 0.8 s), so a program
 * that is silent for 10 s is stuck: it is stopped, and the next command starts a new one. The
 * first reply may take 30 s, because Windows scans a newly built program before its first run.
 * POKER_REPLY_TIMEOUT_MS sets one limit for every reply, in milliseconds (the tests use a short one).
 */
function replyTimeoutMs(firstReply: boolean): number {
  const ms = Number(process.env.POKER_REPLY_TIMEOUT_MS);
  if (Number.isSafeInteger(ms) && ms > 0) return ms;
  return firstReply ? 30_000 : 10_000;
}

/** The program stopped, could not start, or did not answer in time. Its game is gone. */
export class EngineStoppedError extends Error {}

interface Waiting {
  resolve: (r: LeanReply) => void;
  reject: (e: Error) => void;
  timer: ReturnType<typeof setTimeout>;
}

/**
 * Runs the Lean game program and talks to it one line at a time. Replies come back in the
 * order commands were sent, so each command simply waits for the next reply line.
 * Server-side only.
 */
export class LeanProcess {
  private readonly child: ChildProcessWithoutNullStreams;
  private readonly waiting: Waiting[] = [];
  private exited = false;
  /** True once the program has sent its first reply. */
  private answered = false;

  constructor(binary = leanBinaryPath()) {
    // Local app: Makefile builds the binary separately. A standalone package must include it explicitly.
    if (!existsSync(/* turbopackIgnore: true */ binary)) throw new Error(`Lean game program not found at ${binary}. Run "make lean" (or "cd engine && lake build") first.`);
    // A .mjs file is a test stand-in for the program (src/lean/__fixtures__), run by Node.
    this.child = binary.endsWith(".mjs")
      ? spawn(process.execPath, [binary], { stdio: ["pipe", "pipe", "pipe"] })
      : spawn(/* turbopackIgnore: true */ binary, [], { stdio: ["pipe", "pipe", "pipe"] });
    const lines = createInterface({ input: this.child.stdout });
    lines.on("line", (line) => {
      let reply: LeanReply;
      try {
        reply = JSON.parse(line) as LeanReply;
      } catch {
        // A line that is not a reply would make every later reply go to the wrong command.
        // So the game is lost: stop the program, and the next command starts a new one.
        this.fail(`Unreadable reply from the Lean program: ${line.slice(0, 200)}`);
        this.child.kill();
        return;
      }
      this.answered = true;
      const next = this.waiting.shift();
      if (!next) return;
      clearTimeout(next.timer);
      next.resolve(reply);
    });
    // Output ends after the last reply line has been read, so no reply already written is lost.
    lines.on("close", () => this.fail(`The Lean program stopped (exit code ${this.child.exitCode})`));
    this.child.stderr.on("data", (d: Buffer) => console.error(`[lean] ${d.toString().trimEnd()}`));
    this.child.on("exit", () => {
      this.exited = true;
    });
    this.child.on("error", (e) => this.fail(`The Lean program failed: ${e.message}`));
    // Writing to a program that has just stopped fails here, instead of crashing the server.
    this.child.stdin.on("error", (e) => this.fail(`The Lean program stopped reading: ${e.message}`));
  }

  get alive(): boolean {
    return !this.exited;
  }

  send(command: LeanCommand): Promise<LeanReply> {
    if (this.exited) return Promise.reject(new EngineStoppedError("The Lean program has stopped"));
    const timeout = replyTimeoutMs(!this.answered);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.fail(`The Lean program did not answer within ${timeout / 1000} s, so it was stopped`);
        this.child.kill();
      }, timeout);
      this.waiting.push({ resolve, reject, timer });
      this.child.stdin.write(`${JSON.stringify(command)}\n`);
    });
  }

  close(): void {
    this.child.stdin.end();
  }

  /** Stop the program at once, the way a crash would. */
  kill(): void {
    this.child.kill();
  }

  /** The program is gone or stuck: every command still waiting fails with `message`. */
  private fail(message: string): void {
    this.exited = true;
    for (const w of this.waiting.splice(0)) {
      clearTimeout(w.timer);
      w.reject(new EngineStoppedError(message));
    }
  }
}
