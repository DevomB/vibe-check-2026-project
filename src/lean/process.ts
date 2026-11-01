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
 * How long one command may wait for its reply. The bot takes up to a few seconds a reply;
 * a program that is silent this long is stuck, so it is stopped and the next command starts a new one.
 */
const REPLY_TIMEOUT_MS = 30_000;

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

  constructor(binary = leanBinaryPath()) {
    // Local app: Makefile builds the binary separately. A standalone package must include it explicitly.
    if (!existsSync(/* turbopackIgnore: true */ binary)) throw new Error(`Lean game program not found at ${binary}. Run "make lean" (or "cd engine && lake build") first.`);
    this.child = spawn(/* turbopackIgnore: true */ binary, [], { stdio: ["pipe", "pipe", "pipe"] });
    const lines = createInterface({ input: this.child.stdout });
    lines.on("line", (line) => {
      const next = this.waiting.shift();
      if (!next) return;
      clearTimeout(next.timer);
      try {
        next.resolve(JSON.parse(line) as LeanReply);
      } catch {
        next.reject(new Error(`Unreadable reply from the Lean program: ${line.slice(0, 200)}`));
      }
    });
    // Output ends after the last reply line has been read, so no reply already written is lost.
    lines.on("close", () => this.fail(new Error(`The Lean program stopped (exit code ${this.child.exitCode})`)));
    this.child.stderr.on("data", (d: Buffer) => console.error(`[lean] ${d.toString().trimEnd()}`));
    this.child.on("exit", () => {
      this.exited = true;
    });
    this.child.on("error", (e) => this.fail(e));
    // Writing to a program that has just stopped fails here, instead of crashing the server.
    this.child.stdin.on("error", (e) => this.fail(e));
  }

  get alive(): boolean {
    return !this.exited;
  }

  send(command: LeanCommand): Promise<LeanReply> {
    if (this.exited) return Promise.reject(new Error("The Lean program has stopped"));
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.fail(new Error(`The Lean program did not answer within ${REPLY_TIMEOUT_MS / 1000} s, so it was stopped`));
        this.child.kill();
      }, REPLY_TIMEOUT_MS);
      this.waiting.push({ resolve, reject, timer });
      this.child.stdin.write(`${JSON.stringify(command)}\n`);
    });
  }

  close(): void {
    this.child.stdin.end();
  }

  /** The program is gone or stuck: every command still waiting gets `e`. */
  private fail(e: Error): void {
    this.exited = true;
    for (const w of this.waiting.splice(0)) {
      clearTimeout(w.timer);
      w.reject(e);
    }
  }
}
