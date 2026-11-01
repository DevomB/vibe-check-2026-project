import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { CITATIONS } from "./citations";

const entries = Object.values(CITATIONS).flat();

describe("citations", () => {
  it("has at least one source per idea", () => {
    for (const [key, list] of Object.entries(CITATIONS)) {
      expect(list.length, key).toBeGreaterThan(0);
    }
  });

  it("names a source id that exists in the research index", () => {
    const index = readFileSync(path.join(process.cwd(), "docs", "research", "INDEX.md"), "utf8");
    for (const c of entries) {
      expect(index, `${c.id} (${c.short})`).toContain(`| ${c.id} |`);
    }
  });

  it("links every source with an https URL and the day it was checked", () => {
    for (const c of entries) {
      expect(c.url, c.short).toMatch(/^https:\/\/[^\s"]+$/);
      expect(c.urlFetched, c.short).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      expect(Number.isNaN(Date.parse(c.urlFetched)), c.short).toBe(false);
    }
  });

  it("keeps each claim to one sentence that names no proof", () => {
    for (const c of entries) {
      expect(c.claim.trim().endsWith("."), c.short).toBe(true);
      expect(c.claim.toLowerCase(), c.short).not.toMatch(/\b(optimal|gto|unexploitable|solved)\b/);
    }
  });

  it("puts every idea's sources behind a Why? chip somewhere in the app", () => {
    const dir = path.join(process.cwd(), "src", "components");
    const shown = new Set<string>();
    for (const file of readdirSync(dir).filter((f) => f.endsWith(".tsx"))) {
      const text = readFileSync(path.join(dir, file), "utf8");
      for (const chip of text.matchAll(/<WhyChip ideas=\{\[([^\]]*)\]\}/g)) {
        for (const key of chip[1]!.matchAll(/"([a-z-]+)"/g)) shown.add(key[1]!);
      }
    }
    for (const key of Object.keys(CITATIONS)) {
      expect(shown.has(key), key).toBe(true);
    }
  });
});
