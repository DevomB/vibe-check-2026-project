# Refresher sessions: keeping Lean in your life

For people who learned some Lean and want to stay sharp: short sessions every few
days or weeks, each with a warm-up drill on something due for review and one new
idea. The profile (`scripts/profile.py`) decides what is due using spaced
repetition: a topic passed cleanly comes back after 1, 3, 7, 14, 30 and then 60
days; a struggle moves it back a step; a failure restarts it at 1 day.

## A session (10 to 20 minutes)

When the profile has a project learning track, read `references/project-ladder.md` and base drills on that program.
Honor `workspace_mode`: show the drill in chat when requested and check it with `chat.py --file ... --fresh`.
Keep the learner's real program unchanged unless they request a feature edit.

1. **Where they are.** `python3 <skill>/scripts/profile.py show`. Greet them with
   one line: days since the last session, and what is due. Keep it light; a long
   gap is normal, not a failure. Returning users skip `doctor.py` unless something
   fails to build.
2. **What changed in Lean.** Compare `lean --version` with the newest stable
   release at the top of the release notes (the start page links them).
   - Newer release available: say so in a sentence, mention one change worth
     knowing if you know one (don't go digging), and offer
     `elan toolchain install stable`.
   - Machine already current but the profile's `lean_version` is older: they
     updated on their own; mention a change from the "Versions" notes in SKILL.md
     if one applies.
   - Then `profile.py set lean_version X.Y.Z` to the version they now run.
3. **Warm-up drill.** Pick the topic: the most overdue weak spot, else the most
   overdue topic, else the next unseen topic in the catalogue below. If several
   things are due, drill one and leave the rest due: one drill per session. Author a fresh
   drill (next section), open it with
   `launch.py refresh --file ~/.vibecheck/drills/<file>.lean`, and let them work.
   Hints in three steps as usual; note whether they needed any.
4. **Grade honestly.** `profile.py review TOPIC --result pass|struggled|fail`:
   pass means no hints, struggled means hints, fail means you showed the answer.
   Say when it comes back.
5. **One new idea.** The next catalogue topic they haven't seen, where a ladder
   level they finished counts as having seen its topic (table below). Prefer a
   topic their weak spots or session notes point at. Show it on a small example in
   about five minutes, with one tiny exercise, and record it with `profile.py
   review` so it enters the rotation.
6. **Close.** `profile.py log refresh "<setting of the drill; what we did; what clicked>"`.
   Naming the setting ("shipping manifest") lets the next session pick a different one.
   Tell them when the next review falls due. If they want a nudge, offer to set a
   reminder with whatever scheduling tool this environment has; don't set one
   unasked.

If they arrive with their own Lean question or project instead, answer that;
the drill can wait. Still log the session.

**Review dates and cadence.** The review schedule says when a topic is *due*,
not when the next session is. A topic due tomorrow from someone on a weekly
cadence simply waits for next week's session, where it is overdue and goes
first. Don't nag between sessions because something fell due.

**Topic names.** Record ladder drills by level (`L4`), everything else by the
catalogue name below (`induction-generalizing`). Weak spots use the same names.

## Authoring a fresh drill

Drills are written new each time, so they never become rote recall. They must
compile, because a broken drill wastes the session and erodes trust.

1. Write the solved version to `~/.vibecheck/drills/<date>-<topic>-solution.lean`:
   core Lean only (`import Std...` is fine; no Mathlib), 10 to 30 lines, one or two
   theorems about a small program in a software setting (a cart, a queue, a parser,
   a permission check), not abstract maths.
2. `lean <solution file>` must print no errors and no `sorry` warnings. Fix until it does.
3. Copy it to `~/.vibecheck/drills/<date>-<topic>.lean`, replace the proofs (only
   the proofs) with `sorry`, and run `lean` on it: only `sorry` warnings allowed.
4. Open the learner file, never the solution.

Vary the setting between sessions so the shape transfers, not the answer.

## Topic catalogue

Rotate through these after the ladder levels (`L1`–`L8`). Use the topic name as
written when recording reviews. A finished ladder level covers its topic:

| Ladder level | Covers |
| --- | --- |
| L2 | `unfold-omega` |
| L3 | `split-grind` |
| L4 | `induction` |
| L5 | `induction-generalizing` |
| L6 | `mvcgen-invariant` |
| L7 | `subtype-invariant` |
| L8 | `structural-custom` |

| Topic | The idea | Drill shape |
| --- | --- | --- |
| `unfold-omega` | Facts about all inputs by unfolding and arithmetic | A pricing or quota function; prove a bound |
| `split-grind` | Case analysis on `if` and `match` | A validator with several branches; prove it never accepts an invalid input |
| `induction` | Recursion and induction on lists | A recursive list function; prove a length or sum fact |
| `induction-generalizing` | Strengthen before inducting | An accumulator loop; prove it equals the naive version |
| `structural-custom` | Induction over your own inductive type | A small expression or JSON-like tree; prove an evaluator fact |
| `option-except` | Reasoning about `Option` and `Except` results | A parser returning `Option`; prove `parse (print x) = some x` |
| `mvcgen-invariant` | Loop invariants for `do` code | A `for` loop with `let mut`; prove its result |
| `subtype-invariant` | Invariants carried in the type | A bounded buffer whose push must prove capacity |
| `decide-finite` | Exhaustive checking of finite cases | A state machine over a small enum; prove a property by `decide` |
| `termination` | `termination_by` and well-founded recursion | A function recursing on a decreasing measure (binary search, gcd) |
| `hashmap-lemmas` | Using `Std.HashMap` lemmas | `insert` then `get?`; find the lemma with Loogle or `exact?` |
| `calc-chains` | Readable multi-step proofs with `calc` | A chain of inequalities about a fee schedule |
| `typeclass-laws` | Stating laws for an interface | A `Monoid`-like merge; prove associativity for one instance |
| `spec-writing` | Turning a sentence into a `Prop` | Given English claims, write the `def … : Prop` (no proof needed) |
| `finding` | Proving a bug exists | Code with a missing check; prove `∃ input, bad` |

## Profile fields used here

`rung`, `experience`, `languages`, `cadence` (days between sessions they asked
for), `minutes` (session length), `lean_version`, `topics` (per-topic review
history and next due date), `weak_spots`, `sessions`.
