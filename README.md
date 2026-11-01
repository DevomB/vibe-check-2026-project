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

## What we trust

A Lean proof shows that the code does what the theorem says. It does not show that the
theorem says the right thing, and it says nothing about code outside the proof. This
section lists everything a reader must still trust.

**How the proofs are checked.** On every push that changes Lean files, GitHub runs
[`.github/workflows/lean-proofs.yml`](.github/workflows/lean-proofs.yml) on a fresh Linux
machine:

1. `checks/audit.sh`: builds the engine and fails if any `sorry`, `admit`,
   `native_decide`, `maxHeartbeats 0` or new `axiom` appears, or if a main theorem uses
   an axiom other than the three below.
2. `lake comparator`: checks that each theorem listed in
   [`engine/comparator.json`](engine/comparator.json) proves exactly the statement in
   [`engine/Checks/Challenge.lean`](engine/Checks/Challenge.lean), the file of statements
   the team agreed on.
3. `lake check`: Lean's kernel checks the whole engine again.

Run the audit yourself with `checks/audit.sh`. Comparator and `lake check` need Linux.

**We trust these tools:**

- **Lean 4.35.0**: its kernel (the part that checks proofs) and its compiler (the part
  that turns the engine into the `poker` program the web app runs).
- **Three standard axioms**: `propext`, `Quot.sound` and `Classical.choice`. Every Lean
  project that uses ordinary logic relies on them. We use no other axiom and no
  `native_decide`.
- **GitHub Actions and bubblewrap**: the Linux machine and sandbox that run the checks.

**We trust these definitions.** A theorem means only what its definitions mean, so a
reader must check that each of these says the right thing. Each one is short and has a
plain-English docstring and examples.

- Rules of the game, in [`engine/Poker/Spec/`](engine/Poker/Spec/): `State.total` (where
  chips can be), `Legal` (which moves are allowed), `State.MayAct` (who may act),
  `fullDeck` and `FairDeck` (what a fair deck is), and the hand ranking.
- Which hands and games can happen, in
  [`Engine/Proofs/Reachable.lean`](engine/Engine/Proofs/Reachable.lean):
  `Hand.Reachable`, `Game.Reachable`, `Hand.dealtCards`.
- What Risk means, in [`Engine/Proofs/RiskSpec.lean`](engine/Engine/Proofs/RiskSpec.lean):
  `riskWeight` (a lost chip counts 1 + Risk/50 times), `Gamble.Takes`, `callGamble`.
- What the bot and equity counts must do, in `Engine/Proofs/BotSpec.lean` and
  `Engine/Proofs/EquitySpec.lean`.

The engine code itself (`step`, `startHand`, `shuffle`, the bot) is not trusted: the
theorems are about that code directly, not about a copy of it.

One proof helper is built by a small Lean command instead of written by hand:
`#make_dealFrom` in `Engine/Proofs/Chips.lean` makes `dealFrom` (the body of `dealHand`,
with the shuffled deck as an input) and the fact `dealHand_eq_dealFrom`. Lean's kernel
checks both, and no main theorem's statement mentions them. It exists because Lean would
otherwise try to run the 52-card shuffle on an unknown seed inside a proof.

**We trust this data, without proof:**

- **The preflop table**, [`data/preflop.json`](data/preflop.json): win, tie and loss
  counts for each starting hand, estimated from 50,000 random deals per hand with seed
  20261031. Rebuild it with the command stored in the file
  (`npx --yes tsx@4.20.6 scripts/gen-preflop.ts`). These are estimates, not exact counts.
- **Flop counts** are estimated from 1,000 seeded random deals. Turn and river counts are
  exact (theorem T6).

**Not covered by any proof:**

- **The web app**: the Next.js pages, the browser code, Node, and the bridge that passes
  JSON between the browser and the Lean `poker` program (`src/lean/`,
  `src/app/api/game/`). If the bridge sent a different move than the player clicked, no
  theorem would catch it. The engine still rejects any illegal move it receives (T3).
- **Turning the engine's state into JSON** (`engine/Main.lean`) and back.
- **Whole games**: the bot theorems are about one decision at a time. They do not say
  how often a bot wins.

**Functions without a body (`opaque`)**: none.

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
