import path from "node:path";
import { describe, expect, it } from "vitest";
import { EngineStoppedError, LeanProcess } from "./process";

const standIn = (file: string) => path.join(process.cwd(), "src", "lean", "__fixtures__", file);

describe("LeanProcess", () => {
  it("stops the program after a line that is not a reply, so no later reply goes to the wrong command", async () => {
    const lean = new LeanProcess(standIn("garbled-reply.mjs"));
    await expect(lean.send({ cmd: "state" })).rejects.toBeInstanceOf(EngineStoppedError);
    expect(lean.alive).toBe(false);
    // Before the fix, this command got the first command's reply ("reply 1").
    await expect(lean.send({ cmd: "state" })).rejects.toBeInstanceOf(EngineStoppedError);
  });
});
