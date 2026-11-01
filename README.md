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
- A Next.js UI backed by the Lean game program through the Node JSON bridge.
  Lean decides legal moves, bot actions, winners and review grades, and names each
  made hand from the flop on. The preflop description (such as "Ace-King suited")
  comes from the browser.
- Heads-up 500-chip games, fixed 5/10 blinds, one Risk slider (higher means more
  risk-seeking, lower more risk-averse), explicit Next Hand, game-over handling and replay
  support. Random-game seeds remain private until
  game over; entering a seed deliberately starts a replay.
- Lean project under `engine/`, pinned to Lean 4.35.0: card/deck definitions,
  reference hand ranking, seeded shuffle, betting, payouts and hand/game transitions.
- The Lean slider bot, fixed preflop data, sampled flop counts, exact turn/river
  counts, river betting sets and call/fold review against opening river bets.
- Tier 1 T1-T5 and Tier 2 T6-T8 proofs, with standard-axiom audits, Comparator and
  kernel re-checks in Linux CI, green on `main` at `df6904a`
  ([run 41281639578](https://github.com/DevomB/vibe-check-2026-project/actions/runs/41281639578)).
  Their scope and trusted definitions are listed below.
- Lean examples, known-showdown checks and 300 simulated random games; JavaScript
  unit tests and tests against the compiled Lean program. TypeScript game code remains
  a test reference. Differential-test cases and recorded results are under `tests/diff/`.
- Makefile targets build Lean before running the integration tests.
- Integrated session proofs, T9's 200-move hand bound, and checked range/Risk panels.
  See [the merge review](docs/INTEGRATION_REVIEW.md) for current evidence and remaining work.
- Peek (off by default), the Proofs drawer, practice challenges and Mystery opponents.
  Mystery reviews remain hidden until the guess/reveal.

## Still needed

- A final rehearsal on the demo machine; the integrated fresh-Linux-checkout Makefile
  launch and production HTTP checks passed (see the merge review).
- Final UI playthroughs covering folds, showdowns, short stacks, reviews, replay and
  engine restart errors. The checklist, with seeds and moves, is in
  [docs/DEMO.md](docs/DEMO.md), with the demo seeds, Risk, moves, turn mode and
  engine commit. Recheck them on the final build.
- Rehearse the five-minute pitch in [docs/PITCH.md](docs/PITCH.md). Its claim table
  ties each spoken claim to its theorems. T9 is proved; T10 remains optional if a separate
  fast evaluator is introduced.

MVP section 11 records completed and remaining work without assigning people.
The shipping game engine is Lean; browser rendering and transport are tested separately.

When working in parallel:

1. Work from `engine/` for Lean commands; `engine/lean-toolchain` and
   `engine/lake-manifest.json` are committed. MVP section 15 lists the release checks
   and the settled integration details.
2. Use the shared card/action/state types in `src/lean/protocol.ts` and the JSON
   messages in MVP section 13 and `engine/Engine/Protocol.lean`.
   Bet/raise amounts and their bounds are street totals; call amounts are
   additional chips paid. Keep those units consistent across the bridge and UI.
3. Coordinate edits to shared files, including the Lake config, bridge protocol
   and Makefile, before changing them.

The integration target is a complete browser game against the Lean slider bot,
with at least one graded river decision. MVP section 9 lists what to defer.

On Windows, the Makefile needs a POSIX shell and GNU make. With Node and Lean
already installed, the equivalent PowerShell launch is:

```powershell
npm ci
Push-Location engine
lake build
Pop-Location
npm run build
npm start
```

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
- What the bot's internal caution means, in
  [`Engine/Proofs/RiskSpec.lean`](engine/Engine/Proofs/RiskSpec.lean): `riskWeight` (a lost
  chip counts 1 + caution/50 times), `Gamble.Takes`, `callGamble`. The spec files call this
  internal number `risk`. The Risk the player sets (0 to 100, higher means more risk-seeking)
  is mapped to it by `Sliders.ofRisk`: caution falls from 100 at Risk 0 to 0 at Risk 50 and
  stays 0 above, while the bluff share rises. See [docs/THEORY.md](docs/THEORY.md).
- What the bot and equity counts must do, in `Engine/Proofs/BotSpec.lean`
  (`AlwaysLegal`, `RiskMonotone`) and `Engine/Proofs/EquitySpec.lean`
  (`OpponentCanHold`, `TurnOutcomePossible`, `timesListed`, `timesListedTurn`,
  `countResults`).
- What "nearest whole hand" means for Bluff, in
  [`Engine/Proofs/BluffSpec.lean`](engine/Engine/Proofs/BluffSpec.lean): `NearestWhole`.
- What the review must compute, in
  [`Engine/Proofs/ReviewSpec.lean`](engine/Engine/Proofs/ReviewSpec.lean): `callResult`
  (what a call wins against one bot hand), `choiceTotal` and `RiverSpot.total` (what a
  choice wins over all the bot's possible hands), `Frac.LE` (comparing fractions) and
  `SameForHuman` (two hands that look the same to the human).

The engine code itself (`step`, `startHand`, `shuffle`, the bot, the review) is what the
theorems are about, so it does not have to be trusted for what they prove. But some
theorem statements name engine definitions directly. A reader must check that these say
the right thing too:

- `Game.Reachable` is built from `newGame`, `Game.act` and `Game.nextHand`, and
  `Hand.Reachable` from `startHand` and `step`. T1-T3 hold for the games these build.
- `riverBettingSet` is the set T7 counts. The review's range is built from it too.
- `RiverSpot.botHands` (the review's range: the betting set minus the hands that use
  the human's cards), `RiverSpot.prize` and `RiverSpot.cost` (the chips a call can win
  and costs) appear in `RiverSpot.total`, so they fix what T5's worths mean.
- `riverSpotOf` is what the review sees of a hand (T8 `no_hindsight`).
- `labelFor` sets the label bands (Good under 0.5 BB, Inaccuracy under 2, Mistake under
  5, then Blunder). T5 proves that Best means nothing lost and that labels only get worse
  as more is lost; the band edges themselves are only in `labelFor`.

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
- **Turning the engine's state into JSON** (`engine/Engine/Protocol.lean`) and back.
  `engine/Main.lean` only reads and writes the lines.
- **Recorded review inputs**: the explorer is proved equal to the bot on its recorded inputs.
  Faithful recording of the original inputs is checked by guards and route tests rather
  than a recording-correctness theorem. Session reachability and rejection are now proved.
- **The human's buttons**: `legalOptions` (which moves to offer, and the raise bounds)
  is never proved equal to `Legal`. The engine still rejects any illegal move (T3).
- **`Task.spawn` in `turnCounts`**: the turn counts run 46 tasks in parallel. The proofs
  treat a task as the plain function it runs; the compiler is trusted to run them
  correctly.
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
