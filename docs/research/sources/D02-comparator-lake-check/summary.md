# Summary: D02: Comparator, `lake check`, `lake comparator`

**TL;DR.** `lake comparator` checks a solution against a trusted file of theorem statements. `lake check` replays the build through the kernel and rejects any axiom beyond the standard three. Both run in a Linux-only bubblewrap sandbox.

- `comparator.json` names `challenge_module`, `solution_module`, `theorem_names` and `permitted_axioms`.
- Comparator checks three things: each statement matches the challenge (including every definition it uses), the proofs use only permitted axioms, and the kernel accepts them. `--paranoid` runs 5 bundled checkers.
- `lake check` allows only `propext`, `Classical.choice` and `Quot.sound`. Each `native_decide` adds its own axiom, so it fails the check. Ban `native_decide`.
- We develop on Windows, so we run these checks in WSL2 and add a `make check` target.
- Plan: main theorems as `sorry` statements in `Challenge.lean`, proved in `Solution.lean`.

Verdict: use. It defines what "passes Comparator" means for us.

Full extraction: [notes.md](notes.md).
