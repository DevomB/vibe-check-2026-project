# Summary: D05: Agent tooling: lean-lsp-mcp and the Lean REPL

**TL;DR.** lean-lsp-mcp gives a coding agent goal states and diagnostics without a rebuild. The Lean REPL is an alternative.

- Setup: `claude mcp add lean-lsp -s project uvx lean-lsp-mcp`; run `lake build` first.
- The REPL has a `v4.35.0` tag; pin it if used.
- Keep one lake process per checkout. Do not run lake and the REPL at once in the same checkout.
- These are development tools only. They are not part of the shipped app or the trusted base.

Verdict: use (development only).

Full extraction: [notes.md](notes.md).
