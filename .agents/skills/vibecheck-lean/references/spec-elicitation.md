# Spec elicitation: turning "what this code must do" into Lean properties

For people who already know Lean and want properties for an existing project,
and for any rung once there is code to specify. The hard part of verification is
choosing what to prove; this interview gets there in about 15 minutes.

## Tone for the "I know Lean" rung

Be terse. Skip the primer, the infoview tour and tactic explanations unless
asked. Show Lean, not prose about Lean. They want leverage: a good property list,
fast scaffolding, and the audit.

## Before the interview

- Lean repo: find the library and the definitions that matter (`lakefile`,
  the root module, `grep -n "^def\|^structure\|^inductive"`). Ask which module is
  the core.
- Any other language: run `detect_repo.py` and show the candidates; ask which
  function or module carries the risk.

Read the chosen code yourself before asking anything, so every question names
real functions and fields.

Compiled examples of every pattern below, with proofs, are in
`<skill>/assets/spec-patterns/Patterns.lean`. Open it next to their code
(`launch.py spec-existing --project DIR --file …`), and copy shapes from it.

## The interview

Ask a few at a time, grounded in their code, and skip categories that clearly
don't apply. Each answer usually becomes one property.

| Category | Ask | Typical Lean shape |
| --- | --- | --- |
| Never | What must never happen? (money created, negative balance, crash, unauthorised access, overflow) | `∀ inputs, pre → ¬ bad (f inputs)` |
| Always possible | What must always remain possible? (a full bucket admits a request, a valid user can log in) | `∀ s, condition s → ok (f s)`: the liveness partner of every "never" |
| Bounds | What stays within limits? | `∀ x, lo ≤ f x ∧ f x ≤ hi` |
| Invariants | What is true of every reachable state? | `inv init ∧ ∀ s e, inv s → inv (step s e)` |
| Roundtrips | Is anything encoded and decoded, serialised, escaped? | `∀ v, decode (encode v) = some v` |
| Equivalence | Is there a simple version and a fast one, or an old one and a new one? | `∀ x, fast x = reference x` |
| Idempotence and order | Does applying twice change anything? Does order matter? (CRDT merge, normalisation) | `f (f x) = f x`, `merge a b = merge b a` |
| Monotonicity | Does anything only grow or only shrink? (versions, logs, permissions) | `s ≤ step s e` |
| Preconditions | Which inputs are invalid, and does the code check them? | the hypothesis list of the other properties; an unchecked one is often a `FINDING:` |
| Docstring claims | What do the comments and docs promise? | read them aloud and turn each claim into a property |

## Turning answers into `Spec.lean`

- One `def name : Prop` per property, with a doc comment that a non-Lean reader
  understands. Prefix the most important one with `Headline.`
- Definitions that give a property its meaning (a reference implementation, a
  validity predicate) go in `Spec.lean` so the spec lock covers them.
- Put every precondition in the statement. If the code doesn't enforce it, also
  state the failing case as a `FINDING:` property.
- Write the list back in English before any Lean, and get a yes on each line.
  Then write the Lean, show it, and lock: `audit.py --lock`.

## Existing Lean projects

- Add `<Lib>/Spec.lean` (namespace `<Lib>.Spec`) and `<Lib>/Proofs.lean` and
  import both from the root module; the audit finds properties by that namespace.
- Existing theorems count: if one already proves a property, state the property
  in `Spec.lean` and prove it with `theorem x : Spec.x := existingTheorem …`.
- Projects with several `lean_lib`s: pass `--lib NAME` to `audit.py`.
- If they keep proofs elsewhere by convention, respect it; the audit only needs
  the `Spec` namespace and theorems whose type is exactly a `Spec` property.

## Example: from interview to spec

Code: a Python `apply_coupon(total, percent, cap)`. Answers: "never negative,
never more than the original price, discount never above the cap; percent is
supposed to be 0–100 but nobody checks."

```lean
/-- Headline. With a valid coupon, the price stays between 0 and the original total. -/
def couponInRange : Prop :=
  ∀ total percent cap : Int, 0 ≤ total → 0 ≤ percent → percent ≤ 100 → 0 ≤ cap →
    0 ≤ apply_coupon total percent cap ∧ apply_coupon total percent cap ≤ total

/-- For any inputs at all, the discount never exceeds the cap. -/
def discountCapped : Prop :=
  ∀ total percent cap : Int, total - apply_coupon total percent cap ≤ cap

/-- FINDING: nothing checks the percent, and a coupon over 100% makes the price negative. -/
def bugOverHundred : Prop :=
  ∃ total percent cap : Int, 0 ≤ total ∧ 0 ≤ cap ∧ apply_coupon total percent cap < 0
```
