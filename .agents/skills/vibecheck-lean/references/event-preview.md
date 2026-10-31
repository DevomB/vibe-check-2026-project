# Event preview details

## Event preview and checks

The chat runner, local HTTP fixtures and relocated installation have automated tests on macOS with Lean 4.35.0.
Interactive Claude Code and OpenCode flows, and fresh Linux dependency installation, have not been tested end to end.
Install dependencies before the event. The project track supplies a working seed and guided milestones; later features are built during lessons.

From this skill folder, these commands print a dependency plan and run the workflow tests:

```bash
python3 scripts/setup.py --rung learn --mode chat
python3 -m unittest discover -s tests -v
python3 scripts/lesson.py check
```

After approving any missing dependencies, ask your agent to apply the plan and start the lesson.
The proof audit reports an unlocked spec; review and lock the intended properties before relying on spec-change checks.

## License status

This event preview is published for review with the license decision pending. It does not yet include an open-source LICENSE file.

## Local data

Checking Lean runs it. The runner refuses submissions that run commands, touch files, read the environment
or open the network unless `--allow-io` is given, and runs checks inside the OS sandbox where one exists
(sandbox-exec on macOS, bubblewrap on Linux): no network, writes only to the build folder and temp,
no reading of credential folders. The gate is a text check, so the sandbox is the real boundary;
without one, only the gate applies. `python3 scripts/guard.py status` names the sandbox in use.
Setup never calls sudo: a step that needs administrator rights prints the command for you to run.
Profiles, submitted code and compiler output stay in local profile and project folders.
Dependency installers download their tools; API examples contact the endpoint you select.
Generated projects ignore chat transcripts, generated start and lesson pages, progress notes and environment files in Git.
They include portable audit tools, so sharing a project does not require publishing the skill's local installation path.

## Before the event

Do the set-up at home: the Lean toolchain is a few hundred MB, and the Rust
route (hax plus Aeneas plus Mathlib) needs about 8 GB and a few minutes of
downloads that venue Wi-Fi will not enjoy.

## Contents

```
SKILL.md                      entry point: placement question, rungs, rules
scripts/profile.py            learner profile and spaced-repetition schedule
scripts/launch.py             opens VS Code, the start page and Loogle for a rung
scripts/doctor.py             read-only environment check
scripts/setup.py              plan, install and recheck missing requirements for the chosen mode
scripts/bootstrap.sh          install steps: prereqs, elan, vscode, uv, rust, hax, node, mcp, open
scripts/chat.py               spool chat submissions, run Lean and return compiler results
scripts/guard.py              gate for code that reaches outside Lean; OS sandbox for checks and runs
scripts/lesson.py             show, render and Lean-check the illustrated lessons; align syntax trees
scripts/new_project.py        project scaffold, optionally from a starter
scripts/detect_repo.py        language detection, route choice, first targets
scripts/audit.py              proof audit and VERIFICATION.md
assets/exercises/             the eight-level ladder, plus solutions/
assets/project-ladder/        runnable API checker seed for the incremental project track
assets/bridge/Bridge.lean     Python/TypeScript idioms in Lean
assets/starters/              undo, gcounter, rle (with reference solutions)
assets/recipes/               KvApp.lean (complete verified app), IoRecipes.lean
assets/spec-patterns/         one compiled example per spec-interview question
assets/template/, difftest/   scaffold files; differential-test server and harness
references/lessons/           L1–L8 lessons: annotated syntax, accepted and rejected examples, one exercise
references/                   primer, learn, refresh, spec-elicitation, app-recipes,
                              track playbooks, judging, other tools
```

Tested on 2026-10-30 with Lean 4.35.0 and cargo-hax 0.4.2.
