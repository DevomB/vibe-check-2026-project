# Summary: D06: Shipping a Lean program with a web GUI (`make install && make run`)

**Source:** Std.Http API docs: https://lean-lang.org/doc/api/Std/Http.html. Lean.Json: https://lean-lang.org/doc/api/Lean/Data/Json/Basic.html

**TL;DR.** Core Lean v4.35 ships `Std.Http.Server`. One Lean binary can serve a static HTML/JS page plus a JSON API (using `Lean.Json`). Fallback: JSON over stdin/stdout behind a small Python server, which the Kuhn prototype already uses.

- Lean to WebAssembly has no maintained path; Lean2Wasm is stuck at v4.7.0.
- ProofWidgets runs only inside the editor's infoview, so it is no use for a consumer GUI.
- `make install` = elan plus a toolchain download of about 545-595 MB. Skip Mathlib to keep it small.
- Unknown: whether `Std.Http` works on Windows. Spike it early on both platforms (1-3 h).

Verdict: use (`Std.Http` + JSON, with the Python bridge as a fallback).

Full extraction: [notes.md](notes.md).
