# Summary: C05: Game theory libraries in Lean 4 (elazarg/GameTheory; math-xmum) and Isabelle (AFP Nash_Equilibrium)

TL;DR: Lean 4 now has game theory libraries on Mathlib with von Neumann's minimax theorem and mixed Nash existence. elazarg/GameTheory (Apache-2.0, Lean v4.33.1) proves minimax for finite two-player zero-sum games with no `sorry` in that file. Isabelle's AFP has a 2026 Nash equilibrium entry.
- None of them mentions poker, CFR, exploitability, or Kuhn's theorem on behaviour strategies (from what I could see). Verified exploitability for a poker strategy would be new.
- Payoffs are real numbers (`ℝ`). Good for theory, but not computable. Our Kuhn/Leduc checks need exact `Rat` values to run `decide`.
- Toolchain clash: elazarg uses Lean v4.33.1 and math-xmum uses Lean/Mathlib v4.33.0. CLAUDE.md wants Lean 4.35 for Comparator. Importing either library would force a version mismatch. Read them; do not depend on them.
- Useful idea: "exploitability = 0" is the same as "this strategy guarantees the game value". Minimax says that value exists, so "unexploitable" has a clear meaning for a reviewer.

Verdict: maybe. Good to cite as prior work and as a spec reference. Do not import (toolchain mismatch, real numbers).


Full extraction: [notes.md](notes.md).
