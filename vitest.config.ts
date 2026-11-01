import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  // The Lean program's first start can be slow (Windows scans a new binary), and the bot
  // takes up to about a second per turn decision, so tests get more time than the default.
  test: { include: ["src/**/*.test.ts"], testTimeout: 60_000 },
});
