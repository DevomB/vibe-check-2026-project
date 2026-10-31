# Rules for agents in this Lean project

This project is verified with Lean 4. The kernel checks every proof, so the only
way to get a wrong result is a wrong statement or a cheat. These rules close both.

- `__LIB__/Spec.lean` belongs to the humans. Do not edit it. If a property there
  looks false or unprovable, stop and explain why, with a counterexample if you
  have one. A false spec is a finding, not an obstacle.
- Never use `sorry`, `admit`, `axiom`, `native_decide`, `implemented_by`, or
  `set_option debug.skipKernelTC`. Avoid `partial def` in code you prove things about.
- Each property `Spec.foo` is proved by `theorem foo : Spec.foo` in `__LIB__/Proofs.lean`.
  Add helper lemmas freely.
- Try `grind`, `simp`, `omega`, then `exact?` before writing long manual proofs.
- Use the lean-lsp MCP tools to read goal states instead of rebuilding blind.
  Without them, `lake env lean __LIB__/Proofs.lean` shows one file's errors cleanly.
- Products of two variables defeat `omega`/`grind`: state the fact with
  `Nat.mul_pos`, `Nat.mul_le_mul_left` and similar, then `omega`.
- If `split` fails after `unfold` because the goal shows `have …`, use `simp only [f]`.
- Probe ideas in `Scratch/`; the audit ignores it, so don't leave anything there
  that the deliverable needs.
- After each change run `lake build`, then the vibecheck audit:
  `python3 .vibecheck/tools/audit.py`.
- Explain each proof step in plain English when the human is learning; they
  should be able to redo the next one themselves.
