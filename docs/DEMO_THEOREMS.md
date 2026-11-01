# The three demo proof headlines

Chosen November 1, 2026. Show three understandable promises rather than reading the full
theorem list. Keep the existing five-minute scene order in `PITCH.md`.

## 1. The grade judges the decision without seeing the bot's cards

**Theorem:** `no_hindsight` (`Engine/Proofs/Review.lean`).

Say: **"The same decision gets the same grade even if the bot's hidden cards change."**

Show Practice / Make the right decision and still lose: Call 60, lose the hand, receive
Best at +10.32 BB. Open the T8 proof link. This is the strongest audience hook: an outcome
and a decision grade can disagree for a reason that is checked mathematically.

Precise limit: the human-visible state, bot setting and choice are fixed. The theorem is
about the Lean review function. In Mystery mode the review uses the revealed setting;
it does not model what the player believed about the hidden setting during play.

## 2. Best has an exact mathematical meaning

**Headline theorem:** `review_best_iff`.
**Supporting theorems:** `review_worth`, `review_lost`, `review_call_best_iff_equity`,
`review_label_monotone` (`Engine/Proofs/Review.lean`).

Say: **"Best means you lost zero expected value against the better of call and fold,
under this declared opponent-range model."**

Show Practice / Avoid a bad call: Call 60, Mistake at -2.67 BB versus folding at 0.
Retry and Fold: Best, with the same call/fold values. Point at the equity versus price,
then the model explanation. Open the T5 proof link.

Precise limit: responses to an opening river bet only. Raises are not compared. Every
compatible hand in the bot's board-only betting set has equal weight; earlier betting
does not update those weights. Exact grading arithmetic does not make that range a
complete model of the full hand.

## 3. The slider and the explanation describe the real bot

**Theorems:** `more_risk_never_folds_a_call`, `exploreHandAt_moves`,
`exploreHandAt_more_risk_continues` (`Engine/Proofs/OneSlider.lean`, `Explain.lean`).

Say: **"In the same decision, increasing Risk never turns a call into a fold, and the
explorer displays exactly the action the bot would choose at each Risk."**

Show Ivy, Risk 0, seed 1, raise to 150. Open Review and the Risk explorer. In this fixed
decision the boundary is Fold at 0-35 and Call at 36-100. Move the explorer across it.
Open the T4 proof link. Use the new one-slider expectation, not the old two-slider one.

Precise limit: identical recorded state, cards and seed. This is not a claim that higher
Risk wins more games or makes a whole match follow the same trajectory.

## Supporting promises: keep to about 20 seconds

- **The range belongs to the actual bot:** `botDecide_river_follows_set`,
  `bluff_frequency`, `rangeOf_counts`, `rangeOf_adds_up`. Point at the range panel already
  visible in the bad-call review. The bluff share targets the defined betting set, not a
  frequency guaranteed in played games.
- **The engine keeps the game honest:** `chips_always_1000`, `no_card_dealt_twice`,
  `showdown_pays_better_hand`, `fold_pays_other_player`, `legalOptions_exact`.
  The payout theorem adds something chip conservation alone does not: the right player
  wins according to the declared hand-ranking rules. Browser rendering remains tested.
- **Liveness, if asked:** `every_hand_ends` bounds a hand by 200 moves. It does not bound
  human thinking time, request latency or the number of hands in a match.

## New game-theory result: Q&A bonus

Commit `6230d04` adds ten registered bluff-catcher theorems, taking the list from 69 to 79;
`f5a016b` adds them to the proof drawer and docs.
[Its CI passed](https://github.com/DevomB/vibe-check-2026-project/actions/runs/41356539142),
including the proof audit, Comparator, kernel recheck and app checks. This does not establish
human approval of the new `BluffCatcherSpec.lean`; its assumptions still need that review.

The most useful one is `review_both_best_iff_one_third`, supported by
`one_third_bluffs_indifferent`: **when a hand beats every bluff and loses to every value
hand, a full pot-sized call breaks even exactly when one third of the compatible hands
are bluffs.** There are no ties and the caller can afford the bet.

Two useful findings accompany it:

- `risk50_two_bluffs_short`: the board-only Risk 50 range has 324 value hands and 160
  bluffs. Exact one-third would require 162. Thus it is approximately textbook-balanced,
  not exactly indifferent; this is not a proof of Nash equilibrium or optimal full-game play.
- `risk50_bluff_catcher_call_loses`: for a pure bluff catcher against that whole unblocked
  range, calling a pot-sized bet loses `cost / 121` chips on average. Hero card blockers
  can change both the bluff ratio and the answer.

The proof file includes executable real-board examples on A-spades, K-hearts, 2-clubs,
5-diamonds, 7-clubs: T-clubs T-diamonds leaves 312 value / 152 bluffs and folds; Q-clubs
T-clubs leaves 309 value / 156 bluffs and calls. These examples are compiled `#guard`
checks, not separate registered theorems. Do not claim a rehearsed browser fixture exists
for that board: use it as a Q&A explanation, not a new live scene.

Commit `8f50833` adds eight more registered statements (87 total), including
`half_calls_bluff_breaks_even`, `river_equilibrium_iff` and `bot_river_bet_is_pot_sized`.
The first two describe a restricted one-bet payoff model: calling half the time makes a
pot-sized pure bluff break even. The last connects the bet size to the real bot when the
pot-sized total is legal. `RiverEquilibrium` packages three conditions about call/fold and
checking versus betting; it does not quantify over all Hold'em strategies, bet sizes or
earlier streets. Do not turn this into the claim "our bot is Nash/GTO". Human review of the
new `EquilibriumSpec.lean` remains part of its acceptance.
[CI for 8f50833 passed](https://github.com/DevomB/vibe-check-2026-project/actions/runs/41357333527).

While this audit ran, `3e01c5b` added three further registered river statements (90 total):
`more_bluffs_more_call_total`, `maniac_bluff_catcher_total` and `rock_bluff_catcher_total`.
They keep the pure-bluff-catcher assumption; the endpoint totals are before hero blockers.
They do not change the chosen live-demo headlines. Check their final CI before counting
them as release-checked evidence.

This pass corrected the blocker explanation in `BluffCatcher.lean` and `THEORY.md`:
T-clubs T-diamonds removes 12/324 value hands and 8/160 bluffs, reducing the bluff share;
Q-clubs T-clubs removes 15/324 value hands and 4/160 bluffs, increasing it. The original
counts, proof bodies and executable checks were unchanged.

## Audit of the pasted follow-up

### Comparator and specification meaning

The limitation still applies: Challenge and Solution share imported definitions.
`checks/audit.sh` checks builds, prohibited shortcuts and axioms; it has no independent
definition lock. The old mutation experiment was reported on `2e1bcce`; this review has
not repeated that exact mutation on the newer proof set.

The current definitions themselves are sensible on inspection: `FairDeck` means a
permutation of `fullDeck`, and checking requires zero to call. Human review must cover
meaning-giving definitions, not only theorem statements. `CONTRIBUTING.md` now explicitly
names the spec paths and notes that definitions such as `step` outside those paths matter.

### Proposed named rejection guards: not implemented

Missing-card, duplicate-card and illegal-check examples exist, but they are not named
Comparator entries. Deleting ordinary examples does not change the registered contract.
The proposed extra safeguard therefore remains open and needs human agreement on its
new statements. Existing theorem statements should remain unchanged.

Prefer general guards, with concrete rejected examples as corollaries:

1. Every fair deck has length 52: a missing card cannot be accepted as fair.
2. Every fair deck has no duplicates: a repeated card cannot be accepted as fair.
3. Any state with a positive amount to call makes checking illegal.

Register the agreed statements, prove them, and rerun the mutation probes. Those guards
catch those classes of weakening; they still do not freeze all shared definitions or
replace human review of the trusted surface.

### Fuzzing

The real-engine fuzzer exists and supports the one-slider protocol. The historical cloud
report is recoverable with `git show 3f7c4e2:tasks/reports/cloud-fuzz.md`: 2,232 games,
64,573 hands, 257,876 requests and zero reported failures on `df6904a`.

The retained integration record is a separate run: 17 games, 548 hands, 2,243 requests,
zero failures, in `validation/integration-fuzz.json`. It stopped at its time budget.
I could not verify the separate claim of 40 completed games at `2e1bcce` from a retained
run artifact; do not substitute a target count for a completed count.

The body of commit `7052bf9` also retains a one-slider rerun's progress output: 12 games,
252 hands, 1,065 requests and zero failures at 88 seconds. This is evidence of a rerun after
the one-slider change; it is not evidence of 300 completed games.

The most recent change to Session, Protocol or Main in the reviewed history is `34e7886`
(the one-slider integration). The fresh run for this audit completed with:

- **187 games, 3,924 hands, 16,260 requests and zero failures.**
- 1,130 deliberately bad requests, 11 matching replays, no process restarts or hand-cap stops.
- 60 graded decisions: Best 24, Good 5, Inaccuracy 11, Mistake 3, Blunder 17.
- Two slow reviews, 3.392 and 3.041 seconds, below the bridge's normal 10-second timeout.
- A 902-second wall time: the 15-minute limit stopped the run before its 300-game target.
  Do not describe this as 300 completed games.

[The saved artifact](validation/fuzz-2026-11-01.json) contains the untouched result values
and provenance: command parameters, seed, source commits, native build commit `c0a464d`
and SHA-256. Engine changes from that native build through `8f50833` are proof modules,
proof imports and Comparator registrations; Session, Protocol and Main are unchanged.
The run exercises the current game behavior, not the newly compiled proof modules or
browser UI. Fuzzing is testing, not a proof.

### Old branch cleanup: complete

Neither `cloud-engine-fuzz` nor `claude/lean-game-smoke-test-0hvmi4` exists as a local
branch or a remote branch on origin at this check. No unrelated branch was deleted.
