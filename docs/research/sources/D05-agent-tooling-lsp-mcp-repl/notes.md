# D05: Agent tooling: lean-lsp-mcp and the Lean REPL

## Summary

**Source:** lean-lsp-mcp: https://github.com/oOo0oOo/lean-lsp-mcp. Lean REPL: https://github.com/leanprover-community/repl

**TL;DR.** lean-lsp-mcp gives a coding agent goal states and diagnostics without a rebuild. The Lean REPL is an alternative.

- Setup: `claude mcp add lean-lsp -s project uvx lean-lsp-mcp`; run `lake build` first.
- The REPL has a `v4.35.0` tag; pin it if used.
- Keep one lake process per checkout. Do not run lake and the REPL at once in the same checkout.
- These are development tools only. They are not part of the shipped app or the trusted base.

Verdict: use (development only).

## Citation / identity (all fetched 2026-10-31)
| Tool | URL(s) fetched | Type | Pinned Lean | License | Stars |
|---|---|---|---|---|---|
| lean-lsp-mcp (oOo0oOo/lean-lsp-mcp) | https://github.com/oOo0oOo/lean-lsp-mcp ; repo metadata via GitHub API search | code repo (Python) | n/a (uses the project's own toolchain via `lake serve`) | MIT | 542 |
| Lean REPL (leanprover-community/repl) | https://github.com/leanprover-community/repl ; lean-toolchain + tags via GitHub API | code repo | `master` (commit 6a2be396) = **v4.36.0-rc2**; tag **`v4.35.0`** exists (58bdde1f) | Apache-2.0 | 237 |

## lean-lsp-mcp (documented behavior)
- An MCP server (a plug-in for AI coding agents) that talks to Lean's language server. Gives an agent diagnostics, goal states, hover docs, term info, and search (LeanSearch, Loogle, Lean Finder, Lean Hammer).
- Tool names seen on the README: `lean_goal`, `lean_build`, `lean_run_code`, `lean_verify`, `lean_local_search` (needs ripgrep). The full list is in `docs/tools.md` (not opened).
- Install for Claude Code (exact commands from README):
  - `claude mcp add lean-lsp uvx lean-lsp-mcp` (local scope)
  - `claude mcp add lean-lsp -s project uvx lean-lsp-mcp` (project scope; writes `.mcp.json`)
- Needs `uv`, elan/lake, and a Lean project. **Run `lake build` before starting the server** to avoid client timeouts. It runs `lake serve` in the project root.
- Windows: local Loogle is Unix-only (use WSL or the remote API); "REPL memory budget is not enforced on Windows". A WSL2 config via `wsl.exe` is documented for VS Code.
- Maturity: active (updated 2026-10-31), 84 forks, 1 open issue. Releases section empty on the page.
- Caution from CLAUDE.md: never run two `lake` processes in one checkout at once. `lake serve` from the MCP plus a manual `lake build` can collide. Opinion: give each agent its own git worktree.

## Lean REPL (documented behavior)
- "A simple REPL for Lean 4, returning information about errors and sorries." JSON on stdin/stdout, commands separated by blank lines.
- Run with `lake exe repl`. From another project: `lake env /path/to/repl/.lake/build/bin/repl < commands.in`.
- Command mode: `{"cmd": "def f := 2"}` gives back an `env` number. Reuse: `{"cmd": "example : f = 2 := rfl", "env": 1}`. `import` only allowed when `env` is omitted.
- Tactic mode (experimental): send a command with `sorry`, get a `proofState`, then `{"tactic": "...", "proofState": N}`.
- File mode: `{"path": "test/file.lean", "allTactics": true}`.
- Pickling: `pickleTo`, `unpickleEnvFrom`, `unpickleProofStateFrom` (saves to `.olean`). Scoped environment extensions do not pickle correctly (known limitation).
- Tags follow Lean versions (`v4.35.0`, `v4.35.0-rc1..rc4`, `v4.36.0-rc1/rc2`, ...): seen in tag list. Use tag `v4.35.0`.

## Fit for our project
- Both are developer tools, not part of the shipped product. They help the Lean-strong teammate and AI agents write proofs faster.
- lean-lsp-mcp is the easier win: one command to add, and it uses our pinned toolchain automatically.
- REPL: useful only if we script proof search. Not needed for the hackathon otherwise.
- Interesting idea (opinion): the REPL's JSON-over-stdin protocol is the same shape we propose for the engine binary in D06. That pattern is proven to work for Lean programs.

## Recommendations
1. Install lean-lsp-mcp on the proof-writers' machines (project scope `.mcp.json` is fine to commit; contains no secrets). Build first.
2. Skip the REPL unless someone builds a proof-search loop.
3. One lake process per checkout. Use separate worktrees for parallel agents.

## Candidate checks
- None (tooling only). Setup time: 0.5 h per machine for lean-lsp-mcp (needs `uv`).
