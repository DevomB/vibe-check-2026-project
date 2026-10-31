# vibe-check-2026-project
Vibecheck 2026 hackathon project (name to change)

## Start here

Read [MVP.txt](MVP.txt) first. It defines the scope, bot rules, proof targets,
work status, checkpoints, and engine/web JSON messages. Use it when older
research or a local prototype describes a different product.

- [RULES.md](RULES.md): judging criteria and the required `make install && make run` entry point.
- [SPEC.md](SPEC.md): the engine's correctness definitions and proof targets.
- [CLAUDE.md](CLAUDE.md): toolchain, human-owned specifications, build discipline, and proof checks.
- [Lean skill](.agents/skills/vibecheck-lean/SKILL.md): the existing setup and verification workflow for Claude Code or Codex.
- [MVP review and decision log](docs/MVP_REVIEW.md): findings, confirmed choices and remaining gaps.
- Engineering research: [toolchain](docs/research/sources/D01-lean-toolchain-v4.35/notes.md),
  [Comparator](docs/research/sources/D02-comparator-lake-check/notes.md),
  [GUI transport](docs/research/sources/D06-gui-shipping-http-json-wasm/notes.md),
  and [exact arithmetic and performance](docs/research/sources/D07-performance-decide-rat/notes.md).
  The [research synthesis](docs/research/SYNTHESIS.md) is available; its older
  scope and implementation assumptions do not override the MVP.

## What is ready

Done or present:

- MVP, organizer rules, agent guidance, and published research with a synthesis.
- Published TypeScript/Next.js prototype source for cards, shuffle, evaluator,
  betting, bot and UI (`69c4e46`). It remains active development and is ready
  for teammates to pull; it is not the Lean implementation.
- Prototype corrections and 167 tests across 9 files, covering
  validation, chip accounting, all-ins and hand progression.
- Heads-up 500-chip games, fixed 5/10 blinds, explicit Next Hand and seeded replays.
- A TypeScript slider-bot module with preflop data, sampled flop counts and exact
  turn/river counts. The browser still uses the earlier personality bot.
- Lean project under `engine/`, pinned to Lean 4.35.0: card/deck definitions,
  reference hand ranking, seeded shuffle, betting, payouts and hand/game transitions.
- Lean examples, known-showdown checks and 300 simulated random games, plus proofs
  that new hands and accepted moves give the turn only to a player who may act.
  The remaining MVP theorem proofs still need completion and final checks.
- Root Makefile targets build the Lean project through `cd engine && lake build`.
  The browser still uses the TypeScript prototype; the JSON bridge is not implemented.

## Still needed

- Remaining human-reviewed theorem statements and proofs for the agreed MVP properties.
- Lean Risk/Bluff bot, equity counts and data, and river review.
- Node-to-Lean bridge and UI integration, including hand transitions and review history.
- Differential checks, Tier 1 proofs, axiom audit and Linux/WSL Comparator checks.
- Fresh-clone `make install && make run`, rehearsed demo hands and accurate proof claims.

MVP section 11 records the work status. Tasks are deliberately unassigned
while the team gets its footing. TypeScript is a rapid prototype; the
shipping game engine remains Lean.

Before parallel implementation:

1. Work from `engine/` for Lean commands; `engine/lean-toolchain` and
   `engine/lake-manifest.json` are committed. MVP section 15 lists the remaining decisions.
2. Agree shared card/action/state types and the JSON messages in MVP section 13.
   Bet/raise amounts and their bounds are street totals; call amounts are
   additional chips paid. Keep those units consistent across the bridge and UI.
3. Coordinate edits to shared files, including the Lake config, bridge protocol
   and Makefile, before changing them.

The first integration target is **one complete browser hand against an
always-call bot** (Checkpoint A). Then add the Risk/Bluff bot, exact river
call/fold review, and Tier 1 proofs (Checkpoint B). MVP section 9 lists
what to defer until then.

## Working together

Use separate clones and a branch per task. Commit small changes; coordinate
before editing files that someone else is changing. Run one Lake build at a
time per checkout, and pull with rebase before pushing as specified in the MVP.

For each delivered feature, include a small runnable check and the command
used to run it. State which build and checks actually passed. Humans own
the specs; changing a definition to make a proof pass changes the contract.
Before calling a theorem complete, build it, inspect its axioms, and include
a concrete valid example plus a known-bad case that the spec rejects. Use
the Comparator workflow in CLAUDE.md for final verification.

Before the demo, test `make install && make run` in a fresh clone. A working
developer checkout alone does not establish that the shared repo is ready.
