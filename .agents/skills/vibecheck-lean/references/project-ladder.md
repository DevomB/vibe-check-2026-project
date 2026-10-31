# Learn by growing an API checker

Use this track when the learner wants useful code, API integration or command execution while learning Lean.
Keep their rung as `learn`. Each lesson extends the same program and introduces the corresponding ladder skill.
Keep standalone exercises available when they want extra practice or a different setting.

## Start with a working command

The seed is `assets/project-ladder/ApiCheck.lean`. It runs curl, reads an HTTP status and reports whether it is healthy.
At L1, healthy means HTTP 200. Later lessons broaden the policy and add retries.
The adapter supplies I/O so the learner can focus on one pure function at a time.
Lean starts the command with a separate executable and argument array, as described in the
[process documentation](https://lean-lang.org/doc/reference/latest/IO/Processes/).

Record the track, current milestone and source file without marking a level complete:

```bash
python3 <skill>/scripts/profile.py set learning_track api-check
python3 <skill>/scripts/profile.py set project_level L1
python3 <skill>/scripts/profile.py set learning_file Learn/ApiCheck.lean
python3 <skill>/scripts/launch.py learn --project DIR --track api-check --mode chat
```

The launcher copies the seed only when absent. Preserve the learner's subsequent changes to that file.
Begin with `#eval ApiCheck.isHealthy 200`, then let them try other statuses and explain what they observe.
Explain the adapter gradually. Do not teach its whole source before they write their first function.

This command evaluates a snippet against the current lesson file:

```bash
python3 <skill>/scripts/chat.py --project DIR --session api-check-L1 --context-file Learn/ApiCheck.lean --code '#eval ApiCheck.isHealthy 200'
```

This command runs the actual CLI against a local service supplied for the lesson:

```bash
python3 <skill>/scripts/chat.py --project DIR --run Learn/ApiCheck.lean --arg http://127.0.0.1:8000/health --allow-io
```

The program runs curl, so it needs `--allow-io`. Snippets checked against `--context-file` do not.

Start the local fixture before running that command, or use an endpoint the learner selected.
Use a local fixture for reproducible grading. Never invent a remote service result or require an API key for the first lesson.

## Grow one program through eight milestones

The table is a curriculum, not a list of claims already proved by the seed.
Agree on each property's English meaning before writing its Lean statement.

| Level | Useful increment in the same program | Learner's proof task |
| --- | --- | --- |
| L1: definitions and evaluation | Inspect the status policy and command arguments; add a small policy helper used by the app | Prove a concrete policy example by computation |
| L2: all inputs | Add request counts and timeout budgets as pure functions | Prove a configured positive attempt budget allows at least one attempt |
| L3: branches | Classify success, retryable responses and permanent failures; connect the classification to the adapter | Prove success corresponds to the agreed status range; prove an accepted success can advance |
| L4: induction | Build a retry plan over response histories and stop after success | Prove plan length stays within the attempt budget; prove success stops further attempts |
| L5: implementation equivalence | Replace repeated history traversal with an accumulator | Prove the optimized planner equals the simple reference on every input |
| L6: loops | Add a response summary using a loop and connect it to CLI output | Prove the loop summary equals the list specification using an invariant |
| L7: invariant types | Validate configuration and carry a bounded positive attempt count in its type | Prove every constructed configuration satisfies its limits; show a valid configuration exists |
| L8: structural induction | Add a small check-plan language and compile it to command plans | Prove compilation preserves the pure plan semantics and keeps the URL as one command argument |

Open each milestone with that level's lesson (`references/lessons/L<n>.md`, delivered as described in
`references/learn.md`): annotated syntax, accepted and rejected examples, one standalone exercise.
Then provide the milestone's new syntax as a worked example; leave a related change and proof to the learner.
Keep the program runnable after every increment. Use one small change per 15-minute lesson.
Give hints before solutions, and show actual goals after proof tactics.
Do not write all eight implementations or proofs in advance and count them as learner progress.

## Keep code, experiments and progress connected

The durable program is `Learn/ApiCheck.lean`; chat submissions are experiments checked against that file.
Pass `--context-file` for project snippets so the next evaluation sees the current program.
For a learner-approved edit, change the program file and check the whole file before running it.
Move a successful experimental definition into the app only when the learner wants it there.
Then start a new named chat context to avoid defining the same name twice; retain the earlier submission history.

At each checkpoint, show the changed behavior, its checked example, the proposed property and any remaining proof goal.
Record `profile.py review L<n>` only after the learner completes that level's implementation and proof task.
Then update `project_level` to the next level. Merely compiling the supplied seed does not complete L1.
Record the feature, proof and weak spots with `profile.py log learn` so another harness can resume the lesson.

## Revisit the project in refreshers

Use the learner's saved track and source file when writing a refresher.
Give a small variation: another response policy, a retry boundary, an equivalent planner or a configuration constructor.
Reuse local response fixtures. Check both a successful path and a rejected path.
Grade the proof independently using the existing refresh rubric; attach the result to its ladder level or catalogue topic.
Avoid changing the real app while grading an experimental drill unless the learner requests that edit.

## State exactly what the proofs cover

Prove properties of the pure policy, planner, summary and command-plan compiler.
Network I/O, curl, the remote server, credentials and operating-system scheduling remain outside those proofs.
A bounded request plan does not prove a wall-clock deadline for real network execution.
Tests exercise the adapter; they do not turn the external service into a proved component.

Learning files are excluded from the production audit. Never cite the sample ledger's audit as evidence for the API checker.
At graduation, follow `references/track-a-build.md` to move the core into an app with a human-reviewed spec and proofs.
Audit those actual properties before describing the resulting app as verified.
