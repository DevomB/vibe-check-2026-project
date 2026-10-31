# D06: Shipping a Lean program with a web GUI (`make install && make run`)

## Citation / identity (all fetched 2026-10-31)
- `Std.Http` overview: https://lean-lang.org/doc/api/Std/Http.html (official API docs, core library)
- `Std.Http.Server`: https://lean-lang.org/doc/api/Std/Http/Server.html (official API docs)
- v4.35.0 release notes (fix #15043 for `Std.Http.Server`; libuv fixes #14796): https://lean-lang.org/doc/reference/latest/releases/v4.35.0/
- `Lean.Json`: https://lean-lang.org/doc/api/Lean/Data/Json/Basic.html (official API docs)
- Lean2Wasm (T-Brick): https://reservoir.lean-lang.org/@T-Brick/lean2wasm (Reservoir package page)
- ProofWidgets4: https://github.com/leanprover-community/ProofWidgets4 (code repo; paper at ITP 2023, peer-reviewed, per README)
- Lean release assets: https://github.com/leanprover/lean4/releases/expanded_assets/v4.35.0
- elan install line as shown in Velvet's README: https://github.com/verse-lab/velvet
- Note: the API docs at lean-lang.org/doc/api do not show which Lean version they were built from. The v4.35.0 release notes mention a `Std.Http.Server` fix, so the module is in v4.35.0 (documented). Exact API at v4.35.0 may differ slightly from "latest" docs (unsure).

## Option 1: Lean serves HTTP itself with core `Std.Http.Server` (documented behavior)
- Core Lean ships "A low-level HTTP/1.1 server implementation for Lean". It is sans-I/O (pure protocol code) and runs over the `Async` library's TCP. Features: streaming bodies, keep-alive, chunked encoding, header validation, timeouts and limits.
- Entry point (signature from docs):
```lean
def Std.Http.Server.serve {σ : Type} [Handler σ] (addr : Net.SocketAddress) (handler : σ)
  (config : Config := {}) (backlog : UInt32 := 1024) : Async.Async Server
```
- Pattern from the overview (paraphrased; exact code not copied): import `Std.Http`; open `Std`, `Async`, `Http`, `Server`; make `structure MyHandler`; write `instance : Handler MyHandler` whose `onRequest` returns `Response.ok` with a body; in `main : IO Unit`, `Async.block` around: build an IPv4 address 127.0.0.1:8080, `Server.serve addr handler`, then `server.waitShutdown`.
- Response helpers exist for text, HTML, JSON and bytes; `header!` adds headers. `onRequest` runs in `ContextAsync`; `onFailure`, `onContinue` in `Async`.
- Lifecycle: `shutdown`, `waitShutdown`, `shutdownAndWait`.
- No "experimental" warning on the pages read. Windows support: **not stated** (unsure). Lean's async I/O uses libuv (release note #14796 mentions "libuv modules"), and libuv is cross-platform, but I did not verify Windows behavior.
- Third-party alternative seen in search results only (not opened, not counted): axiomed/http (WIP, libuv based).

## Option 2: Lean binary speaks JSON over stdin/stdout, a tiny server elsewhere
- `Lean.Json` is in core (`Lean.Data.Json.Basic`), constructors `null | bool | num | str | arr | obj` (documented). `ToJson`/`FromJson` and `Json.parse`/`compress`: not on the page I read (background knowledge says they exist in `Lean.Data.Json`; unsure for exact names at v4.35).
- `IO.getStdin` / `IO.getStdout`: core IO API (background knowledge; not fetched today: UNVERIFIED in this pass).
- Proven pattern: the Lean REPL (D05) uses exactly this JSON-over-stdin design.
- Downside: needs a second runtime (Python or Node) to serve the web page and proxy to the Lean process. That is one more thing a judge must have installed.

## Option 3: Compile Lean to WebAssembly (run in the browser)
- Lean compiles to C; in principle Emscripten (`emcc`) can build that C to Wasm. The only package found, Lean2Wasm, "Tool for compiling Lean to WASM", needs `emcc`, MIT, and its latest commit builds on **Lean v4.7.0** (page updated 2026-09-22). Far behind v4.35.0. Not maintained for our version.
- Verdict: too risky for a 34-hour build. Ignore.

## Option 4: ProofWidgets
- "A library of user interface components for Lean 4", built on Lean's user-widget mechanism. Its widgets render in the **Lean infoview** (the side panel of the editor). Peer-reviewed paper (ITP 2023). Apache-2.0, 231 stars.
- Not a consumer GUI: a non-technical judge would need VS Code + the Lean extension + a built project. NPM import of its JS components is marked "[EXPERIMENTAL]".
- Possible side use (opinion): a "proof viewer" for technical judges. Not for the main product.

## Recommended architecture
1. One Lean executable, `poker` (built by `lake build`), that:
   - serves the static front end (one `index.html`, plain JS + CSS, no npm build step, files committed in `web/`) with `Std.Http.Server`, and
   - answers JSON API calls (`POST /api/new`, `/api/act`, `/api/review`) by calling the pure engine and returning `Lean.Json`.
2. All game logic and bot logic live in pure Lean modules (the verified part). `Main.lean` is a thin IO shell: parse JSON, call engine, print JSON. Keep the shell small and list it as trusted/unverified in the README.
3. Fallback (if `Std.Http` misbehaves, especially on Windows): keep the same JSON request/response types and switch transport to stdin/stdout lines, with a ~40-line Python standard-library server. Design the JSON types first so the switch is cheap.
4. Spike in hour 1 to 3: "hello world" `Std.Http.Server` on Windows and on Linux (WSL). If either fails, go to the fallback at once.

## What `make install` must fetch
- elan (Lean version manager), if missing. Official elan README (https://github.com/leanprover/elan, fetched 2026-10-31; Apache-2.0/MIT): Linux/macOS `curl https://elan.lean-lang.org/elan-init.sh -sSf | sh`; Windows PowerShell: `curl -O --location https://elan.lean-lang.org/elan-init.ps1`, then `powershell -ExecutionPolicy Bypass -f elan-init.ps1`, then `del elan-init.ps1`. Velvet's README shows a variant with `-s -- -y` for non-interactive install. elan's `lean`/`lake` "automatically select and, if necessary, download" the version in `lean-toolchain`. A Makefile still needs a POSIX shell, so on Windows judges should use WSL or Git Bash (opinion).
- The v4.35.0 toolchain, downloaded automatically by elan from `lean-toolchain` on first `lake` call: about 544 to 594 MB (.tar.zst, rounded sizes from the release page). Time: opinion, 1 to 3 min on good internet, longer on venue Wi-Fi.
- Dependencies: if only core (+ Batteries), a small git clone. No Mathlib (avoids a large cache download and `lake exe cache get`).
- Build: `lake build` of a core-only project: minutes, not hours (opinion).
- `make run`: `lake exe poker` (or `.lake/build/bin/poker`), print "open http://127.0.0.1:8080", optionally open the browser (`xdg-open` / `open`).

Suggested Makefile shape (ours, untested):
```make
install:
	command -v elan >/dev/null || (curl https://elan.lean-lang.org/elan-init.sh -sSf | sh -s -- -y)
	. $$HOME/.elan/env && lake build
run:
	. $$HOME/.elan/env && lake exe poker
```

## Fit and relevance
- Good: one language, one binary, no Node/Python. Strong story: "the server is the verified engine".
- Risk: `Std.Http` maturity and Windows behavior unknown; that is why the fallback exists.

## Candidate checks
- Round-trip test: `fromJson? (toJson s) = .ok s` for the game-state type, as `#guard` on examples (1 h) or a theorem for simple types (3 to 5 h; optional).
- Engine is total: API handler never panics on any JSON input (return an error object). Engineering, 1 h.
