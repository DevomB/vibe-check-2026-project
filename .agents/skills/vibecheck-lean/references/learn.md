# Learn mode: from zero to comfortable

The goal is a person who can state a property of their own code and prove it
without you. Proofs you write for them do not get them there; proofs they write
with you watching do.

## Getting them set up to learn

Default to `references/project-ladder.md` as the main progression, or adapt its milestones to the learner's own useful program.
Grow the API checker through L1–L8 and keep this ladder's learning goals and grading rules.
Use standalone exercises as optional drills rather than replacing the learner's project at each level.
If the learner requests standalone exercises, save `learning_track` as `exercises` and follow the setup below.

1. **A playground project.** Learners who don't have a project yet get one:
   `new_project.py playground --dir ~/vibecheck` (ask before choosing the
   location). Exercises are copied into its `Learn/` folder, which the audit
   ignores. Record it: `profile.py set project ~/vibecheck/playground`.
2. **Placement.** Experience "none": start at level 1. "Tried it a little" or
   "comfortable": don't take their word or make them repeat basics. Probe levels
   2, 4 and 6 in that order, one exercise each, about five minutes apiece, and stop
   at the first one they don't solve cleanly (needed a hint, or couldn't). Start
   there: a probe they struggled on, or the level below a probe they couldn't do.
   Example: L2 clean, L4 needed a hint → start at L4 (skip probing L6). Record each
   probe with `profile.py review L<n> --result …`; levels below the start that
   weren't probed need no record.
3. **Their language.** If they know Python, TypeScript or JavaScript, the bridge
   (`<skill>/assets/bridge/Bridge.lean`: every Python/TS idiom with its Lean
   equivalent, all compiled, with `#eval` output to read) opens next to the
   exercise; `launch.py` copies it into `Learn/` for the learn rung when their
   profile lists one of those languages. For Rust or other languages, point out
   the closest idioms as they come up.
4. **In chat by default.** Read `references/chat-workspace.md`. Use
   `launch.py learn --project <playground> --level L<n> --mode chat` to copy the exercise.
   Show the worked example here, then execute the learner's submissions with `chat.py`.
   No editor, extension or browser is required.
5. **Editor when preferred.** `launch.py learn --project <playground> --level L<n> --mode editor` copies the
   exercise, opens VS Code on it (installing the Lean extension first if they
   agreed), and opens the start page and Loogle in the browser.

## Open every level with its lesson

Each level has an illustrated lesson in `references/lessons/L1.md` … `L8.md`. Each lesson:

- breaks new syntax into an annotated tree that labels every piece of a line;
- shows the goal changing in the Lean panel;
- shows examples Lean accepts, and examples it rejects, with the error it really prints;
- gives a rule of thumb and a few check-yourself questions;
- ends on **one exercise to run now**.

Every example has been compiled: `lesson.py check` confirms that each ✓ block compiles, each ✗ block fails with the quoted error, each `#eval` prints what the lesson says, and each tree lines up with its code.

Lessons apply to both tracks. On the API checker track, teach the level's lesson first, then apply it to `ApiCheck.lean`; its last line says how.

Deliver it as a short story rather than a file dump:

1. **Open with the hook**, the lesson's first paragraph, in your own words, tied to code they care about.
2. **Show the annotated trees exactly as written**, in code blocks so the columns stay aligned, with one or two sentences after each. This is what builds confidence: every symbol on the line has a name and a job.
3. **Show one ✓ and one ✗ live.** Run the first accepted example, then a rejected one, through `chat.py --fresh` (or the editor). That way they see real Lean output, and an error that was predicted in advance. Show the remaining examples as written; they're already checked.
4. **Give the rule of thumb** and ask one check-yourself question. Wait for the answer before revealing it.
5. **End on the exercise**, the "Run one exercise now" section. Make it an invitation: paste a try and see what Lean says, and either result is progress. Then stop and wait for their code. Don't add the next idea.

Before teaching, `lesson.py show L<n>` prints a lesson; read it then. In editor mode, `launch.py` renders the illustrated page and opens it alongside the exercise. In chat mode, offer the page once: "Want the illustrated version in your browser?" Then run `lesson.py render L<n> --project DIR --open`.

When a learner's own code uses syntax they haven't met, explain it the same way. Generate an aligned tree for that line rather than drawing one by hand:

```bash
python3 <skill>/scripts/lesson.py tree 'theorem t (n : Nat) : n ≤ n + 1 := by omega' \
  'theorem t' 'a fact named t' '(n : Nat)' 'for any whole number n' 'n ≤ n + 1' 'the statement' 'omega' 'the proof step'
```

## How to teach

- **Show, then share, then hand over.** For each new idea: you do a worked example
  and narrate every goal change; then you do the next one together (they choose
  the tactic, you explain the result); then they do one alone while you only
  answer questions.
- **Always point at the goal.** After every tactic, quote the new goal and say in
  one sentence what changed. This is the habit that makes people self-sufficient.
- **Hints in three steps.** Asked for help on an exercise: first a question ("what
  does the goal look like after `unfold`?"), then the tactic name, then the line.
  Never the full solution unless they ask for it outright.
- **Connect every exercise to software.** "This is the rate limiter's budget
  check", "this is how you prove a fast path equals the slow path".
- **Keep sessions short.** One level per sitting is plenty. End each with what
  they can now do that they could not before.

## The ladder

Exercise files live in `assets/exercises/` (solutions in `assets/exercises/solutions/`;
never open those in front of the learner unless asked). Copy a level into the
learner's project folder as `Learn/LN_Name.lean`, open it in the editor, and work
through it. A level is done when `lake env lean Learn/LN_Name.lean`, run in the
project folder (or the file in the editor), shows no errors and no `sorry` warnings.

Each level's lesson ends on the exercise named in `lesson.py list`; the rest of the file is for practice after that first win.

| Level | File | New idea | The software skill it unlocks |
| --- | --- | --- | --- |
| 1 | `L1_Programs.lean` | `def`, `#eval`, `rfl`, `decide` | Lean as a language; facts by computation |
| 2 | `L2_Unfold.lean` | `unfold`, `omega`, statements about all inputs | Arithmetic safety: no overflow, no negative prices |
| 3 | `L3_Branches.lean` | `split`, `grind`, hypotheses from `if` | Guards and validation: rate limiters, permission checks |
| 4 | `L4_Induction.lean` | `induction`, recursive functions | Anything over lists, trees, logs |
| 5 | `L5_Reference.lean` | Generalized lemmas, fast-equals-reference | Optimizations that provably change nothing |
| 6 | `L6_Loops.lean` | `mvcgen`, loop invariants | Imperative code with `let mut` and `for` |
| 7 | `L7_Invariants.lean` | Structures carrying proofs | Illegal states unrepresentable: bounded queues, counters |
| 8 | `L8_Compiler.lean` | Induction over syntax trees | Interpreters, compilers, query planners |

After level 3 a learner can contribute to a hackathon project. After level 5 they
can verify most pure business logic. Level 8 is the "I proved a compiler correct"
moment; celebrate it.

## Teams with a deadline

A hackathon team usually wants a result today, not a course. Two ways to fit
learning in:

- **Teach inline.** Skip the ladder and narrate the real project's proofs as you
  write them, using the habits above. Offer the ladder afterwards.
- **Compressed warm-up.** Levels 1–3 together in about 30 minutes, one person
  driving, then straight into the project. Level 3 exercise 3 is a tiny rate
  limiter, a good bridge into real code.

Exercise files in `Learn/` are ignored by `audit.py`, so unfinished ones never
block a submission.

## Recording progress

The learner's profile (`scripts/profile.py`, stored in `~/.vibecheck/profile.json`)
follows them across projects. After each level:

```bash
python3 <skill>/scripts/profile.py review L3 --result pass        # or struggled / fail
python3 <skill>/scripts/profile.py weak add "induction generalizing"   # something that didn't click
python3 <skill>/scripts/profile.py log learn "L3 done; split clicked, grind felt like magic"
```

`review` also schedules the level for spaced review, so a learner who later moves
to the refresh rung gets drills on exactly what they learned and struggled with.

## Beyond the ladder

Point learners who want more at, in this order:

- [Functional Programming in Lean](https://lean-lang.org/functional_programming_in_lean/)
- [Theorem Proving in Lean 4](https://lean-lang.org/theorem_proving_in_lean4/)
- The [mvcgen tutorial](https://lean-lang.org/doc/tutorials/4.34.0/mvcgen/)
- [Lean Zulip](https://leanprover.zulipchat.com), stream `#new members`
- [Loogle](https://loogle.lean-lang.org) to search lemmas by shape

The real graduation is their own code: pick a function from something they
maintain, write `Spec.lean` for it, and prove it.
