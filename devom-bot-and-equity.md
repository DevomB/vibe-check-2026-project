# Task for Devom: Lean equity counts, Lean slider bot, T3 (bot half), T4, T6, differential tests

Paste this whole file into your LLM. Also give it `docs/tasks/README.md` (team plan and shared
contract), `MVP.txt` sections 3, 5, 7 and 8, `CLAUDE.md`, and the TypeScript reference code
listed below.

## Context

We are building a heads-up no-limit Texas Hold'em web app for the Vibecheck 2026 hackathon. The
game engine is written in Lean 4.35 (`engine/`) and its properties are proven there. The bot has
two sliders, Risk (0-100) and Bluff (0-60%). It does not need to play well. It must do exactly
what MVP §5 says, provably.

A working, tested TypeScript version of the bot already exists. **Port it to Lean**; the
TypeScript stays as the reference to test the Lean against.

Reference code (TypeScript):
- `src/ai/slider/decide.ts`: `decideWithCounts`, `callPays`, `potRaiseTarget`, `potBetTarget`, clamping.
- `src/ai/slider/counts.ts`: `riverCounts` (exact, 990), `turnCounts` (exact, 45,540), `sampledCounts`.
- `src/ai/slider/preflopTable.ts`, `startingHands.ts`, `data/preflop.json` (169 hands, seed 20261031,
  50,000 samples each), `scripts/gen-preflop.ts`.

Lean you build on: `engine/Poker/Spec/Basics.lean` (`Card`, `State`, `Action`, `Legal`,
`State.toCall`, `State.minRaise`), `engine/Poker/Spec/HandRank.lean` (`showdown`, `bestScore`),
`engine/Engine/Deck.lean` (`nextSeed`, `mixSeed`, `shuffle`), `engine/Engine/Hand.lean`.

## Files you own

`engine/Engine/Equity.lean`, `engine/Engine/PreflopData.lean` (generated), `engine/Engine/Slider.lean`,
`engine/Engine/SliderTests.lean`, `engine/Engine/Proofs/Bot*.lean`, `engine/Engine/Proofs/Equity*.lean`,
`scripts/`, `data/`, `tests/`. Do not edit `engine/Poker/Spec/` (human-owned) or other lanes' files.

## Steps, in order

### 0. Stubs first (by 4:30 PM)

Push to `main` `Equity.lean` and `Slider.lean` with exactly the types and signatures in
`docs/tasks/README.md`. Stub bodies: `countsFor` returns `⟨1, 0, 1⟩`; `botDecide` checks when
`toCall = 0`, otherwise calls. No `sorry`. Om wires these into the game loop right away.

### 1. Equity counts (target 6:30 PM)

- `Counts` and `countsFor seed hole board`, dispatching on board length (0, 3, 4, 5).
- River: exact. Every opponent two-card hand from the 45 unseen cards, each once (990). Use the
  spec's `showdown`, so counts agree with the reference ranking by construction.
- Turn: every (river card, opponent hand) pair, 45,540 outcomes. **Benchmark the compiled Lean
  binary** (not `#eval`). If one decision takes more than about 1.5 s, switch to a fixed Monte
  Carlo count instead. Either way the mode is a constant, never chosen by machine speed (MVP §5).
  Write the timing and choice in a comment, as `counts.ts` does.
- Flop: 1,000 samples from `seed`, using `nextSeed`/`mixSeed`. Same seed, same counts.
- Preflop: write `scripts/gen-preflop-lean.ts` that turns `data/preflop.json` into
  `engine/Engine/PreflopData.lean` (a 169-entry table). That file is generated: never edit it by
  hand; regenerate it. Look up a hand by its starting-hand name (`AKs`, `T9o`, `77`).
- `#guard` tests: a few spots computed by the TypeScript code (river, turn, flop with a fixed
  seed, preflop AA and 72o) must give the same counts in Lean.

### 2. Slider bot (target 7:30 PM)

Port `decideWithCounts` exactly (MVP §5):
- Facing a bet (`toCall > 0`): if equity ≥ 75% (`100 · (2w + t) ≥ 2 · 75 · n`, as `equityAtLeast` in `counts.ts`) and
  a raise is legal, raise to the pot-sized target, clamped to the legal min/max street totals.
  Otherwise call if `100 · (2·w·P + t·(P − C)) ≥ 2 · (100 + 2·Risk) · l · C`; otherwise fold.
  P includes the matched opponent bet, with any uncallable excess returned first.
- No bet to face, preflop to turn: if equity ≥ 65% and a bet is legal, bet the pot (clamped);
  otherwise check.
- River, no bet to face: bet pot-sized (clamped) if `riverBets sl.bluffPct board hole` (Aarav's
  `Engine/River.lean`) is true, otherwise check. Use Aarav's stub until the real one lands.
- `reason`: one plain sentence, like the TypeScript reasons ("Fold: not worth calling 60 to win
  150 at Risk 50, with win chance 31%").
- Generate about 200 golden cases from the TypeScript `decideWithCounts` (random spots, fixed
  seed) into a generated Lean test file, and `#guard` that Lean gives the same action.

### 3. Proofs, Tier 1 (target 9:30 PM)

First write each statement in plain words, then in Lean. **Show it to a teammate and get a yes
before proving.** Put each in `engine/Engine/Proofs/Bot*.lean`.

- **T3, bot half:** whenever the bot is allowed to act (`s.MayAct`), `botDecide` returns a
  legal action: `Legal s (botDecide sl seed hole board s).action`. Om's old `botMove_legal`
  in `Engine/Bot.lean` shows the pattern. The clamping to legal min/max is the core of it.
- **T4 `risk_monotone`:** state it on the decision for given counts (factor `botDecide` as
  `countsFor` + `decideWithCounts`). For the same state, counts and bluff setting, if the bot
  continues (calls or raises) at Risk r₂, it also continues at every Risk r₁ ≤ r₂. Also show
  `countsFor` does not take Risk as input, so the counts really are the same.
- For each: `#print axioms` (only `propext`, `Classical.choice`, `Quot.sound`), one `example`
  with every hypothesis satisfied on a concrete spot, one `example` showing a wrong answer is
  rejected (for T4: a decision table that calls at Risk 100 but folds at Risk 0 fails the
  statement).

### 4. Sunday morning

- **T6 `enumeration_exact` (Tier 2):** the river enumeration visits every valid opponent hand
  exactly once (the list has no duplicates, has 990 entries, and contains every pair of unseen
  cards); same for the turn pairs.
- **Differential tests (MVP §7):** in `tests/`, pin `poker-calculations` to exactly `4.0.3`.
  Compare hand ranking on 100,000 random deals, exact equity on flop/turn/river spots, a few
  dozen preflop matchups, and Monte Carlo within 4 standard errors. Deal distinct cards
  yourself (the library accepts duplicates), pass cards as `"Ah"`, and never ask it for exact
  preflop equity. Commit the harness, the cases and the results.
- **Pitch owner:** you run the 5-minute pitch (MVP §14). Only claim theorems that pass the final
  audit.

## Checks before each merge to `main`

- `cd engine && lake build` passes; no `sorry` in your files (or listed in `docs/tasks/STATUS.md`).
- `#guard` tests against the TypeScript reference pass.
- No `Float` in any bot decision. No `native_decide`. No `partial def` in anything you prove about.

## Using the extra credits on this task

- Two sessions in separate worktrees: one for Equity + Slider code, one for proofs (T3 bot
  half, T4) once the code is on `main`.
- Generating the golden test cases and the differential-test harness is cheap, mechanical work:
  give it to a background agent with a cheaper model.
- Stuck lemma for 20+ minutes: fan out 3 attempts with different strategies, keep the first
  that builds.
- Overnight (10 PM): a cloud session runs the 100,000-deal differential test on Linux and
  attempts T6 on a branch. Review both in the morning.
- After Checkpoint B and again at about 11 AM Sunday: one `/code-review ultra` run on `main`
  for the whole team (billed; only these two).
