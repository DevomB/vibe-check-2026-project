# How the team worked

This was the README's process section during the hackathon. It is kept for the team.

## Working in parallel

1. Work from `engine/` for Lean commands; `engine/lean-toolchain` and
   `engine/lake-manifest.json` are committed. MVP section 15 lists the release checks
   and the settled integration details.
2. Use the shared card/action/state types in `src/lean/protocol.ts` and the JSON
   messages in MVP section 13 and `engine/Engine/Protocol.lean`.
   Bet/raise amounts and their bounds are street totals; call amounts are
   additional chips paid. Keep those units consistent across the bridge and UI.
3. Coordinate edits to shared files, including the Lake config, bridge protocol
   and Makefile, before changing them.

Use separate clones or worktrees and a branch per task. Commit small changes; coordinate
before editing files that someone else is changing. Run one Lake build at a time per
checkout, and pull with rebase before pushing.

## Checks for each change

For each delivered feature, include a small runnable check and the command used to run it.
State which build and checks actually passed. Humans own the specs; changing a definition
to make a proof pass changes the contract. Before calling a theorem complete, build it,
inspect its axioms, and include a concrete valid example plus a known-bad case that the
spec rejects. Use the Comparator workflow in [CLAUDE.md](../CLAUDE.md) for final
verification.

Before the demo, test `make install && make run` in a fresh clone. A working developer
checkout alone does not show that the shared repo is ready.

## Other notes

- [MVP review and decision log](MVP_REVIEW.md): findings, confirmed choices and the gaps at
  the time.
- [Merge review](INTEGRATION_REVIEW.md): the overnight merge, its checks and limits.
- The Lean skill under `.agents/skills/vibecheck-lean/` is a third-party tutorial skill
  (`modiqo/vibecheck-lean`, see `skills-lock.json`), not this project's own workflow.
- Engineering research: [toolchain](research/sources/D01-lean-toolchain-v4.35/notes.md),
  [Comparator](research/sources/D02-comparator-lake-check/notes.md),
  [GUI transport](research/sources/D06-gui-shipping-http-json-wasm/notes.md),
  and [exact arithmetic and performance](research/sources/D07-performance-decide-rat/notes.md).
