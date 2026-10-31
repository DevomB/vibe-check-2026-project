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
 * Runs the Lean game program and talks to it one line at a time. Replies come back in the
 * order commands were sent, so each command simply waits for the next reply line.
 * Server-side only.
 */
export class LeanProcess {
  private readonly child: ChildProcessWithoutNullStreams;
  private readonly waiting: { resolve: (r: LeanReply) => void; reject: (e: Error) => void }[] = [];
  private exited = false;

  constructor(binary = leanBinaryPath()) {
    // Local app: Makefile builds the binary separately. A standalone package must include it explicitly.
    if (!existsSync(/* turbopackIgnore: true */ binary)) throw new Error(`Lean game program not found at ${binary}. Run "make lean" (or "cd engine && lake build") first.`);
    this.child = spawn(/* turbopackIgnore: true */ binary, [], { stdio: ["pipe", "pipe", "pipe"] });
    createInterface({ input: this.child.stdout }).on("line", (line) => {
      const next = this.waiting.shift();
      if (!next) return;
      try {
        next.resolve(JSON.parse(line) as LeanReply);
      } catch {
        next.reject(new Error(`Unreadable reply from the Lean program: ${line.slice(0, 200)}`));
      }
    });
    this.child.stderr.on("data", (d: Buffer) => console.error(`[lean] ${d.toString().trimEnd()}`));
    this.child.on("exit", (code) => {
      this.exited = true;
      for (const w of this.waiting.splice(0)) w.reject(new Error(`The Lean program stopped (exit code ${code})`));
    });
    this.child.on("error", (e) => {
      this.exited = true;
      for (const w of this.waiting.splice(0)) w.reject(e);
    });
  }

  get alive(): boolean {
    return !this.exited;
  }

  send(command: LeanCommand): Promise<LeanReply> {
    if (this.exited) return Promise.reject(new Error("The Lean program has stopped"));
    return new Promise((resolve, reject) => {
      this.waiting.push({ resolve, reject });
      this.child.stdin.write(`${JSON.stringify(command)}\n`);
    });
  }

  close(): void {
    this.child.stdin.end();
  }
}
