import { type ChildProcessWithoutNullStreams, spawn } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import { createInterface } from "node:readline";

/**
 * The Kuhn poker page's link to the Lean program `kuhn-serve` (engine/KuhnServe.lean). Every
 * rule decision is made in Lean; this file only passes JSON lines. Server-side only.
 */

export type KuhnCard = "jack" | "queen" | "king";
export type KuhnMove = "check" | "bet" | "call" | "fold";

export type KuhnCommand = { cmd: "new_hand" } | { cmd: "move"; move: KuhnMove } | { cmd: "reset" } | { cmd: "state" };

export interface KuhnHand {
  /** 1 if you are player 1 (you act first), 2 if you are player 2. */
  yourSeat: 1 | 2;
  yourCard: KuhnCard;
  /** Only shown at a showdown. */
  botCard: KuhnCard | null;
  moves: { by: "you" | "bot"; move: KuhnMove }[];
  toAct: "you" | "bot" | null;
  /** Your allowed moves; empty when it is not your turn. */
  legal: KuhnMove[];
  over: boolean;
  showdown: boolean;
  /** Your winnings for this hand, in chips, once it is over. */
  result: number | null;
}

export interface KuhnState {
  hand: KuhnHand | null;
  /** Finished hands. */
  hands: number;
  /** Your winnings over all finished hands, in chips. */
  total: number;
}

export type KuhnReply = { ok: true; state: KuhnState } | { error: string; state: KuhnState | null };

/** Where `lake build` puts the program. Override with KUHN_BIN. */
export function kuhnBinaryPath(): string {
  const name = process.platform === "win32" ? "kuhn-serve.exe" : "kuhn-serve";
  return process.env.KUHN_BIN ?? path.join(process.cwd(), "engine", ".lake", "build", "bin", name);
}

/** Runs `kuhn-serve` and answers one command at a time, in order. */
export class KuhnProcess {
  private readonly child: ChildProcessWithoutNullStreams;
  private readonly waiting: { resolve: (r: KuhnReply) => void; reject: (e: Error) => void; timer: ReturnType<typeof setTimeout> }[] = [];
  private exited = false;

  constructor(binary = kuhnBinaryPath()) {
    if (!existsSync(binary)) throw new Error(`Kuhn program not found at ${binary}. Run "make lean" first.`);
    this.child = spawn(binary, [], { stdio: ["pipe", "pipe", "pipe"] });
    createInterface({ input: this.child.stdout }).on("line", (line) => {
      const next = this.waiting.shift();
      if (!next) return;
      clearTimeout(next.timer);
      try {
        next.resolve(JSON.parse(line) as KuhnReply);
      } catch {
        next.reject(new Error("Unreadable reply from the Kuhn program"));
      }
    });
    const stop = (e: Error) => {
      this.exited = true;
      for (const w of this.waiting.splice(0)) {
        clearTimeout(w.timer);
        w.reject(e);
      }
    };
    this.child.on("exit", (code) => stop(new Error(`The Kuhn program stopped (exit code ${code})`)));
    this.child.on("error", stop);
  }

  get alive(): boolean {
    return !this.exited;
  }

  send(command: KuhnCommand): Promise<KuhnReply> {
    if (this.exited) return Promise.reject(new Error("The Kuhn program has stopped"));
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.child.kill();
        reject(new Error("The Kuhn program did not answer"));
      }, 10_000);
      this.waiting.push({ resolve, reject, timer });
      this.child.stdin.write(`${JSON.stringify(command)}\n`);
    });
  }

  close(): void {
    this.child.stdin.end();
  }
}

/** Accept only the commands the program understands. */
export function parseKuhnCommand(body: unknown): KuhnCommand | null {
  if (typeof body !== "object" || body === null) return null;
  const b = body as Record<string, unknown>;
  switch (b.cmd) {
    case "new_hand":
    case "reset":
    case "state":
      return { cmd: b.cmd };
    case "move":
      return b.move === "check" || b.move === "bet" || b.move === "call" || b.move === "fold" ? { cmd: "move", move: b.move } : null;
    default:
      return null;
  }
}
