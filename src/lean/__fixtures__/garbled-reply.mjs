// A stand-in for the Lean game program that writes a line that is not JSON before its first
// reply, then answers every command. Used by src/lean/process.test.ts through LeanProcess.
import { createInterface } from "node:readline";

let replies = 0;
createInterface({ input: process.stdin }).on("line", () => {
  replies++;
  if (replies === 1) process.stdout.write("debug: not a reply\n");
  process.stdout.write(`${JSON.stringify({ error: `reply ${replies}`, state: null })}\n`);
});
