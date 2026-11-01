import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

/**
 * The browser runs on Lean's replies, not on the TypeScript prototype (MVP §15). So the code
 * that ships to the browser, and the bridge, import nothing from src/engine, src/ai or
 * src/review. Tests may: the prototype is a test reference.
 */

const SHIPPED = ["app", "components", "hooks", "lib", "lean"];
const PROTOTYPE_IMPORT = /from\s+["'](@\/|(\.\.?\/)+)(engine|ai|review)(\/[^"']*)?["']/;

function sourceFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const file = path.join(dir, e.name);
    if (e.isDirectory()) return sourceFiles(file);
    return /\.tsx?$/.test(e.name) && !/\.test\.tsx?$/.test(e.name) ? [file] : [];
  });
}

describe("shipped code and the TypeScript prototype", () => {
  it("imports nothing from src/engine, src/ai or src/review", () => {
    const src = path.join(process.cwd(), "src");
    const offenders = SHIPPED.flatMap((d) => sourceFiles(path.join(src, d))).flatMap((file) =>
      readFileSync(file, "utf8")
        .split(/\r?\n/)
        .flatMap((line, i) => (PROTOTYPE_IMPORT.test(line) ? [`${path.relative(src, file)}:${i + 1}: ${line.trim()}`] : [])),
    );
    expect(offenders).toEqual([]);
  });
});
