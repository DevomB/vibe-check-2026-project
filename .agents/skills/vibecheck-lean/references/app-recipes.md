# Building an app in Lean: starters and recipes

For the "build an app" rung. Lean is a real programming language: it compiles to
a native executable, and the parts that matter can carry proofs. The shape of
every verified app is the same: a pure core where all decisions happen, a spec
about the core, and a thin shell for I/O.

## Pick a starting point

| Start from | Command | When |
| --- | --- | --- |
| The ledger example | `new_project.py NAME --dir PARENT` | They have their own idea; the example shows the file layout |
| Undo/redo editor | `new_project.py NAME --dir PARENT --starter undo` | First project; four short proofs about stacks |
| Grow-only counter CRDT | `… --starter gcounter` | Distributed-systems flavour; headline: replicas converge in any delivery order |
| Run-length codec | `… --starter rle` | A roundtrip property; the classic "decode undoes encode" |

Starters arrive with the code and the spec written and every proof `sorry`; the
team's job is to prove them, which `audit.py` confirms. Each starter's reference
proofs are in `<skill>/assets/starters/NAME/solution/Proofs.lean`. Use them to give
hints, and don't show them unless the team asks. A starter is a warm-up: once
it's proved, extend it with a feature and a new property, or move to their own idea.

For their own idea, run the spec interview in `references/spec-elicitation.md`
before writing code, then follow `references/track-a-build.md`.

## Recipes

Two compiled files, runnable with `lean --run FILE [ARGS]`:

- `<skill>/assets/recipes/KvApp.lean`: a complete key-value store. Pure `step`
  function, three proved properties (read-after-write, writes don't disturb other
  keys, delete removes), and a stdin REPL shell. The model to imitate.
  `printf 'put a 1\nget a\n' | lean --run KvApp.lean`
- `<skill>/assets/recipes/IoRecipes.lean`: command-line arguments and exit codes,
  JSON with `deriving ToJson, FromJson`, reading and writing files, and state in
  an `IO.Ref`.

Copy the parts they need into `Main.lean`. Keep `Main.lean` free of decisions:
if a branch in the shell decides something the user cares about, move it into
the core and give it a property.

## Lean 4.35 notes for app code

- `String.trim` is gone: use `s.trimAscii.toString` (`trimAscii` returns a slice).
- `Std.HashMap` needs `import Std.Data.HashMap`. For proofs, an association `List`
  is often easier; switch to a `HashMap` later if speed matters.
- `partial def` is fine in the shell, never in code you prove things about.
- `lake exe NAME ARGS` builds and runs; `lake build` alone produces
  `.lake/build/bin/NAME` for the demo.

## Shipping the demo

- `Main.lean` runs the verified core on realistic input.
- `audit.py --report` passes, and `VERIFICATION.md` lists the headline first.
- The README says what is not verified: the shell, I/O, parsing of user input
  unless it has its own property, and the Lean compiler and runtime.
