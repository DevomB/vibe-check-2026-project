# The placement question

People can't pick a rung from a four-word label. They pick by recognising
themselves ("pick this if…") and by seeing what happens next (the preview). So the
question carries both, says the choice is reversible, and offers a way out for
anyone unsure. Use the text below as written.

## With AskUserQuestion

One question, `multiSelect: false`.

- **header:** `Start here`
- **question:** `Where would you like to start? Pick the closest match; you can switch any time just by saying so. Not sure? Choose "Other" and type "not sure", and I'll ask two quick questions instead.`

Options, in this order (beginner first, so the list reads as a ladder):

**1. label:** `Learn Lean`
**description:** `Pick this if you've never used Lean, or tried it and it didn't stick. Short exercises, hints not answers.`
**preview:**
```
First 10 minutes
──────────────────────────────────
1. Two quick questions: languages
   you know, Lean experience
2. A practice project is created
3. A real API checker starts at L1:

     #eval ApiCheck.isHealthy 200

   run it here, or in the editor
4. Extend its policy, then prove
   a concrete fact about it

8 levels: API calls, retries,
budgets, and a proved compiler.
Standalone exercises available.
```

**2. label:** `Build an app in Lean`
**description:** `Pick this if you want to make something new and prove it works. Lean experience optional: I teach as we go.`
**preview:**
```
First 10 minutes
──────────────────────────────────
1. Your idea, or pick a starter:
   undo/redo editor · CRDT counter
   · run-length codec
2. One sentence: what must always
   hold ("undo restores the
   previous document")
3. Project created; VS Code opens
   on Spec.lean
4. You approve the spec; we prove
   it together

Ends with a running app and a
VERIFICATION.md anyone can check.
```

**3. label:** `Spec my existing project`
**description:** `Pick this if you have code (any language) and want to prove what it must and must not do. Best if you can read some Lean.`
**preview:**
```
First 10 minutes
──────────────────────────────────
1. The path to your repo
2. Language detected, route picked:
   Lean-native · port & prove ·
   Rust extraction · protocol model
3. Interview: what must never
   happen? what must always work?
4. Your answers become Lean
   properties you review

New to Lean but have code to
check? Pick this anyway; I'll
teach as we go.
```

**4. label:** `Keep me sharp`
**description:** `Pick this if you've learned some Lean and want short, regular refreshers so it stays with you.`
**preview:**
```
Each session: 10–20 minutes
──────────────────────────────────
1. What's due, by spaced repetition
2. A fresh drill opens in VS Code
   (written new each time and
   checked to compile)
3. One new idea, one tiny exercise
4. Next review scheduled

Works best after Learn levels 1–4.
```

Map the answer: `Learn Lean` → `learn`, `Build an app in Lean` → `build-app`,
`Spec my existing project` → `spec-existing`, `Keep me sharp` → `refresh`.

## Without AskUserQuestion (Codex, or plain chat)

Send this as text and wait for a reply:

```
Where would you like to start? (You can switch any time.)

  1. Learn Lean: never used it, or it didn't stick. Short exercises.
  2. Build an app in Lean: make something new and prove it works.
  3. Spec my existing project: prove what your code must and must not do.
  4. Keep me sharp: short, regular refreshers on what you've learned.

Reply with a number. Not sure? Reply "?" and I'll ask two quick questions.
Want to see what an option looks like first? Reply "?2" (or any number).
```

For `?N`, show that option's preview from above, then ask again.

## "Not sure": two questions that decide for them

One AskUserQuestion call with two questions (or both as numbered text):

1. **header** `Lean so far`: `Have you written any Lean before?`
   - `Never`
   - `A little`: tutorials, exercises, a few proofs
   - `Yes, regularly`
2. **header** `Today`: `What do you want out of today?`
   - `Understand how it works`
   - `Make something new`
   - `Check code I already have`
   - `Stay in practice`

| Lean so far | Today | Rung | Experience to record |
| --- | --- | --- | --- |
| any | Understand how it works | `learn` | as answered |
| any | Make something new | `build-app` | as answered |
| any | Check code I already have | `spec-existing` | as answered; "Never" means teach inline |
| Never | Stay in practice | `learn` (nothing to refresh yet; say so kindly) | none |
| A little or more | Stay in practice | `refresh` | as answered |

Tell them the result in one line and why ("You've got code to check and you're
new to Lean, so we'll spec your project and I'll teach as we go"), then carry on
with that rung's follow-up questions, skipping any the two answers already cover.

## Returning users

When a profile exists, don't re-ask the placement question. One question,
header `Today`: `Welcome back: <rung, days away, what's due>. Still <rung>?`,
with the profile's rung first and labelled `(Recommended)`, and the other three
rungs after it with the same descriptions as above.
