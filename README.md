# vibe-check-2026-project
Vibecheck 2026 hackathon project (name to change)

## Start here

Read [MVP.txt](MVP.txt) first. It defines the scope, bot rules, proof targets,
proposed owners, checkpoints, and engine/web JSON messages. Use it when older
research or a local prototype describes a different product.

- [RULES.md](RULES.md): judging criteria and the required `make install && make run` entry point.
- [CLAUDE.md](CLAUDE.md): toolchain, human-owned specifications, build discipline, and proof checks.
- [Lean skill](.agents/skills/vibecheck-lean/SKILL.md): the existing setup and verification workflow for Claude Code or Codex.
- Engineering research: [toolchain](docs/research/sources/D01-lean-toolchain-v4.35/notes.md),
  [Comparator](docs/research/sources/D02-comparator-lake-check/notes.md),
  [GUI transport](docs/research/sources/D06-gui-shipping-http-json-wasm/notes.md),
  and [exact arithmetic and performance](docs/research/sources/D07-performance-decide-rat/notes.md).
  Research is being published incrementally; its synthesis is still pending.

## What is ready

This handoff publishes the planning and agent guidance. The Lean engine,
web bridge, Makefile, and runnable application still need to be integrated.
There is no fresh-clone build or run command to claim yet.

A TypeScript engine prototype is being developed locally. Its presence in one
checkout does not mean teammates can pull it. The MVP calls for game logic in
Lean and a web UI that talks to it through the Node bridge; agree with the
owner before building against a prototype's API.

## First tasks

These are the proposed owners from MVP section 9; confirm them as a team.

| Owner | First deliverable | Proof targets |
| --- | --- | --- |
| Devom | Human-owned specs and theorem statements in `engine/Poker/Spec/`; settle the toolchain and shared types. | T4 risk monotonicity, T5 review soundness, T8 no hindsight |
| Aarav | Lean betting/street/showdown state machine, initially enough to play one heads-up hand. | T1 chip conservation, T3 legal actions |
| Vishal | Cards, seeded shuffle, evaluator, equity enumeration, and differential checks. | T2 no duplicate cards, T6 exact enumeration, T7 bluff frequency |
| Om | Web table, Node-to-Lean bridge, and Makefile install/run targets. | Full-hand browser integration |

Before parallel implementation:

1. Agree the Lean version, pin dependencies, and commit `lean-toolchain` and
   `lake-manifest.json`. MVP section 12 lists the pending decisions.
2. Agree shared card/action/state types and the JSON messages in MVP section 11.
   Clarify whether a raise's `amount` means a street total or an increment,
   and use the same meaning for legal-action limits and the UI.
3. Give one person ownership of each shared file, including the Lake config,
   bridge protocol, and Makefile. Coordinate changes to those files.

The first integration target is **one complete browser hand against an
always-call bot** (Checkpoint A). Then add the Risk/Bluff bot, exact river
call/fold review, and Tier 1 proofs (Checkpoint B). Follow MVP section 7 for
what to defer until then.

## Working together

Use separate clones and a branch per task. Commit small changes; coordinate
before changing another person's files. Run one Lake build at a time per
checkout, and pull with rebase before pushing as specified in the MVP.

For each delivered feature, include a small runnable check and the command
used to run it. State which build and checks actually passed. Humans own
the specs; changing a definition to make a proof pass changes the contract.
Before calling a theorem complete, build it, inspect its axioms, and include
a concrete valid example plus a known-bad case that the spec rejects. Use
the Comparator workflow in CLAUDE.md for final verification.

Before the demo, test `make install && make run` in a fresh clone. A working
developer checkout alone does not establish that the shared repo is ready.
