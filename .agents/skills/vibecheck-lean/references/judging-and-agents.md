# Proving the proof is real, and keeping agents honest

## Why this matters

The kernel makes a finished proof trustworthy. Three things can still make a
submission worthless: an unfinished proof hidden by `sorry`, an assumption
slipped in as an `axiom`, or a theorem that proves the wrong statement. The
first two are mechanical and `audit.py` catches them. The third needs a human,
and the workflow below makes that review small.

## Division of labour

1. **Humans own `Spec.lean`.** Properties as `def name : Prop` with a one-line
   doc comment in English. A human outside the team reads each statement aloud
   and agrees it says what the doc comment claims. Then `audit.py --lock`.
2. **Agents own `Impl.lean` and `Proofs.lean`.** They may add helper lemmas but
   never edit the spec.
3. **Review the spec diff, not the proofs.** After every agent session the
   audit's spec-lock check must pass. Proofs need no review; the kernel did it.

## How agents cheat, and how the audit catches it

| Cheat | Looks like | Caught by |
| --- | --- | --- |
| Leaves a hole | `sorry`, `admit` | Build warning, `sorryAx` in axioms (and a source scan for `sorry`) |
| Assumes the goal | a new `axiom` | Source scan, extra axiom on the theorem |
| Weakens the spec | extra hypothesis, or a property that is now trivially true | Spec lock |
| Changes what the spec means | edits a helper in `Impl.lean` that a property mentions | Not caught: keep meaning-giving definitions in `Spec.lean` |
| Trusts the compiler | `native_decide` | Source scan, `…native_decide.ax_…` axiom |
| Runs different code | `@[implemented_by]`, `@[extern]` | Source scan |
| Switches off the kernel | `set_option debug.skipKernelTC` | Source scan |
| Proves something else | `theorem conserves : True` | Not counted: only a theorem whose type is exactly `Spec.conserves` proves `conserves` |

## The audit

```bash
python3 <skill>/scripts/audit.py [PROJECT] [--lock] [--report] [--json] [--skip-build]
```

| Check | Passes when |
| --- | --- |
| build | `lake build` succeeds with no `sorry` warnings |
| no cheats | none of the constructs above in non-comment source |
| spec lock | Spec files hash to the value recorded by `--lock` (a note, not a failure, before the first lock) |
| proofs | every `<Lib>.Spec.*` property has a theorem of exactly that type, and every project theorem uses only `propext`, `Classical.choice`, `Quot.sound` (plus accepted assumptions) |

`--report` writes `VERIFICATION.md`: each property, its English meaning, the
theorem that proves it, and its axioms. That table is the judges' five-minute
check. Two doc-comment conventions shape it: `Headline.` puts a property in its
own section at the top, and `FINDING:` lists a proved bug separately from the
guarantees. Files under `Learn/` and `Scratch/` are not scanned.

**Accepted assumptions.** Rust extraction models external library functions with
`axiom`s in `Assumptions/`. When a human has read one and accepts it as an
accurate model, add its full name to `.vibecheck/assumptions.txt` (one per line,
`#` comments allowed). The audit then allows it and lists it under "Trusted
assumptions" in the report, so the trust is disclosed rather than hidden.

## Submission checklist

- [ ] `audit.py --report` prints ALL CHECKS PASS from a clean clone.
- [ ] Every property in `Spec.lean` has a doc comment, and an outsider agreed with each.
- [ ] README says what is *not* verified: I/O, UI, the port's faithfulness, the Lean compiler and runtime.
- [ ] Track B: the differential-test command, input count and seed.
- [ ] A running demo of the program, not only the proofs.

## Agent setup

Projects from `new_project.py` already have `.mcp.json` for
[lean-lsp-mcp](https://pypi.org/project/lean-lsp-mcp/) and a `CLAUDE.md` with these
rules. For an existing project:

```bash
lake build                                            # warm first; the server times out otherwise
claude mcp add -s project lean-lsp -- uvx lean-lsp-mcp
```

With lean-lsp the agent sees goal states, diagnostics and hover docs directly,
and can try several tactics at one position, instead of rebuilding the whole
project to read one error.
