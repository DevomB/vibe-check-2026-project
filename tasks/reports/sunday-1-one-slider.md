# Lane 1 report: one Risk slider (Sun Nov 1, 2026)

Branch `sunday/one-slider`, from main at 70a7b84. Brief: the Sunday lane 1 message (one
slider, Risk, sets both internal settings; Risk 50 is the textbook setting).

## Commits, in order

| Commit | What |
| --- | --- |
| 34e7886 | Engine: `Sliders.ofRisk`, the protocol, the bot's reasons, the Risk explorer over the player's Risk, nine new theorems registered in Challenge and Comparator |
| 25db575 | `docs/THEORY.md`, `src/lib/citations.ts`, research notes F01-F03 and their INDEX rows (written by the helper session) |
| 073e2e5 | `tasks/reports/sunday-1-lane2-contract.md`: every web, test and demo-record file the protocol touches, per file with lines (written by the second helper session) |
| 003427c, cae2e15 | Merges of `sunday/review-fixes` (2fa13e1, c35f3fc): the helper's docstrings, `review_sound` comment fix, and `value_strongest`, `bluffs_weakest`, `botHands_ne_nil_of_board` registered |
| a67afdf, 64b2e3d | Docstrings: the two `exploreHand` theorems are about the caution sweep; about thirty docstrings that said "Risk" for the internal number now say caution; `botDecide_no_bet_off_river` added and registered |
| 11f50a0, 299d87d, c846e9a | THEORY.md with line references and the theorem list; README, SPEC.md and MVP.txt say one Risk slider with higher = more risk-seeking (asked for by Aarav, written by the helper session) |
| e3c6691, 71ee280 | `Engine/Proofs/OneSliderRiver.lean`: `more_bluff_never_checks_a_bet` and `more_risk_never_checks_a_bet`, the river half of the slider's direction, registered (61 names). The second commit replaces a 60-step `decide` and a no-card-twice hypothesis with the general arithmetic lemma `bluffCount_mono` (written by the second helper session) and a real rejected-output example |

## Checks on the branch head, 71ee280 (WSL2, Linux x64, Lean v4.35.0)

- `checks/audit.sh`: build clean (111 jobs), no banned words, no escape hatches, every
  `maxHeartbeats` commented, all 61 Comparator names use only `propext`, `Classical.choice`,
  `Quot.sound` (`ideal_is_textbook` uses none). AUDIT PASSED.
- `lake comparator`: "Your solution is okay!" for all 61 statements.
- `lake check`: the kernel accepts the whole engine; axioms `propext`, `Quot.sound`,
  `Classical.choice`; 5 min 56 s.
- The same three passed on 34e7886 (55 names), after the review-fixes merge, and on 64b2e3d
  (59 names). `npm test` is red by design until lane 2 lands (see below).
- 70b0949 merges `origin/main` (19 web and docs commits, no engine files) into this branch;
  the Lean results above carry over unchanged. Conflicts were in README.md and MVP.txt only
  (main's restructure plus the one-slider wording). The web on main still sends `bluff_pct`.

## Baseline (step 1), on main at 70a7b84

- `cd engine && lake build`: clean, no warnings, 1 min 6 s incremental.
- `npm test` with `POKER_BIN` set: 19 files, 296 tests, all passing, 35 s.

## What changed in the engine (steps 2, 4, 5)

**The mapping** (`Slider.lean`): `Sliders.ofRisk` exactly as the brief wrote it, with `#guard`s
at 0, 25, 50, 75, 100 and 250: (100, 0), (50, 17), (0, 33), (0, 47), (0, 60), (0, 60). The
internal `Sliders` structure is unchanged.

**The protocol** (`Protocol.lean`, `Session.lean`): `new_game` is `{"cmd":"new_game","seed":"42",
"risk":50}`. Any `bluff_pct` field, even in range, is the error `bluff_pct was removed; Risk
sets both`. The state's `sliders` is `{"risk": 50, "caution": 0, "bluffPct": 33}`. `Command.newGame`
takes `(seed risk)`; `Session` gains a `risk` field (the player's value) next to `sliders`.

**The reasons quote the player's Risk.** `View` gains `shownRisk : Option Nat := none`;
`viewOf`, `decideWithCounts` and `botDecide` gain a trailing optional parameter for it, and
`Session.botChoice` passes `some s.risk`. Only the call and fold reason text reads it
("Fold: not worth calling 50 to win 150 at Risk 0, ..."). Every existing call of these
functions elaborates as before; `botDecide_action_shown` says the move never depends on it.
The river bluff reason still says "a bluff, picked at Bluff 60%": `SliderGolden.lean` pins that
text against the TypeScript reference (`decide.ts`), and that file is generated. Changing the
wording is a decision for Devom; the demo record's `roleOf` regex depends on it.

**The Risk explorer** (`Explain.lean`): the app now calls `exploreHandAt risk ms`, which sweeps
the player's Risk 0-100 through `Sliders.ofRisk`. So on the river with no bet to face the
Bluff share changes with Risk, and the move can too. The board is ranked once per move
(`rankRiverHands`, about 20 ms compiled) and the betting set is cut from that ranking at each
Risk (`riverMoveRanked`, proved equal to `riverOpening`'s move). The old sweep over the internal
caution is kept as `exploreHand sl ms`; both are `exploreHandWith` with different settings per
Risk, so the two old theorems keep their statements and the app has no dead code path of its
own. JSON changes: `risk` is the player's Risk; `continuesUpTo` is replaced by `continuesFrom`
(the lowest Risk at which the bot calls, raises or bets, or null); `effect` is one of `noBet`,
`raises`, `callsAlways`, `foldsAlways`, `callsFrom`, `betsAlways`, `checksAlways`, `bluffsFrom`,
`varies` (`callsUpTo` still exists for the caution sweep; the app never produces it, by
`exploreHandAt_more_risk_continues`);
summaries flip direction, for example "Folds at Risk 0-7, calls at 8-100." and "Checks at Risk
0-40, bluffs at 41-100: more Risk, more bluffs."

**Tests updated**: `SessionTests.lean` (start at Risk 50; `bluff_pct` rejected with the exact
message; the three-number `sliders`), `ExplainTests.lean` (the new direction, the river no-bet
cases, the shortcut checked against deciding at each Risk), `Proofs/Examples.lean` (the
session examples at Risk 50). `SliderGolden.lean` and `SliderTests.lean` pass unchanged.

## Statements to approve (plain words, then the Lean as written in `Checks/Challenge.lean`)

All twelve are proved in `Engine/Proofs/OneSlider.lean`, `Engine/Proofs/OneSliderRiver.lean`
and `Engine/Proofs/Explain.lean` with the standard axioms only, and registered in
`comparator.json` (61 names in all, with the three from `sunday/review-fixes`). Two proofs
rely on reduction (`ideal_is_textbook` by `decide`; `ideal_river_set` uses `rfl` for the 33):
fine on v4.35, and the kind of proof CLAUDE.md says to re-check after a toolchain change.

### The Risk quoted in a reason never changes the move

Plain words: `botDecide` with any Risk number to quote makes the same move as `botDecide`
without one. The link to the app's session is `Session.botChoice_accepted`
(`Engine/Proofs/Session.lean`), which rewrites with this theorem; it is proved but not itself a
Comparator statement. The registered chain is `bot_move_accepted`, `handle_keeps_reachable`,
`app_game_reachable`.

```lean
theorem botDecide_action_shown (sl : Sliders) (seed : Nat) (hole board : List Card) (s : State)
    (shown : Option Nat) :
    (botDecide sl seed hole board s shown).action = (botDecide sl seed hole board s).action
```

### The mapping

Plain words: at every Risk the bluff share is at most 60 (so T7 `bluff_frequency` applies at
every Risk); more Risk never bluffs less; more Risk never weighs a lost chip more.

```lean
theorem ofRisk_bluff_le_60 (r : Nat) : (Sliders.ofRisk r).bluffPct ≤ 60

theorem ofRisk_bluff_monotone {r r' : Nat} (h : r ≤ r') :
    (Sliders.ofRisk r).bluffPct ≤ (Sliders.ofRisk r').bluffPct

theorem ofRisk_caution_antitone {r r' : Nat} (h : r ≤ r') :
    (Sliders.ofRisk r').risk ≤ (Sliders.ofRisk r).risk
```

### More Risk never folds a call

Plain words: facing a bet in one spot (the same seed, cards, board and chips), if the bot calls
or raises at Risk `r`, it also calls or raises at every higher Risk `r'`. It follows from T4
(`botDecide_risk_monotone`), `ofRisk_caution_antitone`, and a lemma that facing a bet the move
does not read Bluff (`botDecide_facing_bet_bluff`). No counterexample.

```lean
theorem more_risk_never_folds_a_call (seed : Nat) (hole board : List Card) (s : State)
    {r r' : Nat} (hr : r ≤ r') (hbet : 0 < s.toCall)
    (hc : (botDecide (Sliders.ofRisk r) seed hole board s).action.continues) :
    (botDecide (Sliders.ofRisk r') seed hole board s).action.continues
```

"Facing a bet" is `0 < s.toCall`. The other half of the slider's direction, the river with
no bet to face, is `more_risk_never_checks_a_bet` below.

### More Risk never checks a bet (the river half)

Plain words: on a river board, with nothing to call and a bet allowed, if the bot bets its two
cards at one setting, it bets them at every setting with a Bluff share at least as big (and
below 100); so along the slider, if it bets at Risk `r` it bets at every higher Risk `r'`. The
value hands are the same at every setting; the bluffs are the last `bluffCount values b`
ranked hands, and that count never falls as `b` rises (`bluffCount_mono`, plain arithmetic on
the rounding formula, written by the second helper session and checked here). With
`more_risk_never_folds_a_call` this covers every place the slider acts; before the river with
no bet to face, the bot reads neither setting (`botDecide_no_bet_off_river`).

```lean
theorem more_bluff_never_checks_a_bet (sl sl' : Sliders) (seed : Nat) (a b : Card)
    (board : List Card) (s : State) (h5 : board.length = 5) (h0 : s.toCall = 0)
    (hbet : ∃ n, Legal s (.raiseTo n)) (hb : sl.bluffPct ≤ sl'.bluffPct)
    (hb' : sl'.bluffPct < 100)
    (hc : ∃ n, (botDecide sl seed [a, b] board s).action = .raiseTo n) :
    ∃ n, (botDecide sl' seed [a, b] board s).action = .raiseTo n

theorem more_risk_never_checks_a_bet (seed : Nat) (a b : Card) (board : List Card) (s : State)
    (h5 : board.length = 5) (h0 : s.toCall = 0) (hbet : ∃ n, Legal s (.raiseTo n))
    {r r' : Nat} (hr : r ≤ r')
    (hc : ∃ n, (botDecide (Sliders.ofRisk r) seed [a, b] board s).action = .raiseTo n) :
    ∃ n, (botDecide (Sliders.ofRisk r') seed [a, b] board s).action = .raiseTo n
```

"A bet is allowed" is the spec's `∃ n, Legal s (.raiseTo n)`, as in
`botDecide_river_follows_set`, which this proof rests on. Example with every hypothesis met,
on the A K 2 5 7 board with 100 in the pot: the bot cannot bet queen-jack at Risk 50 and check
it at Risk 100; it does the opposite (`#guard`s in `OneSliderRiver.lean`), which is allowed.

### No bet to face before the river: Risk plays no part

```lean
theorem botDecide_no_bet_off_river (sl sl' : Sliders) (seed : Nat) (hole board : List Card)
    (s : State) (hc : s.toCall = 0) (h5 : board.length ≠ 5) :
    (botDecide sl seed hole board s).action = (botDecide sl' seed hole board s).action
```

This is why the explorer's `noBet` entries say Risk does not change the move.

### Risk 50 is the textbook setting

Plain words: Risk 50 is plain chip profit (caution 0) with a 33% bluff share; on every river
board with no card twice, that is 324 value hands and 160 bluffs, 160 of 484 bets. The 160
comes from T7 `bluff_frequency`: the whole number nearest to 324 × 33 / 67.

```lean
theorem ideal_is_textbook : Sliders.ofRisk 50 = ⟨0, 33⟩

theorem ideal_river_set (board : List Card) (h5 : board.length = 5) (hd : board.Nodup) :
    (riverBettingSet (Sliders.ofRisk 50).bluffPct board).value.length = 324 ∧
    (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs.length = 160
```

What this does and does not say: 160 of 484 is 33.1%, the textbook break-even share for a
pot-sized bet to the nearest percent, inside the bot's own board-only river set. It is not a
claim that the bot plays well; see `docs/THEORY.md` section 3.

### The Risk explorer over the player's Risk

Plain words: for move `i` of a hand's recorded bot moves and every Risk `r` from 0 to 100, the
explorer's move at `r` is what `botDecide` returns with `Sliders.ofRisk r` and the recorded
seed, cards, board and chips. And facing a bet, if the explorer shows a call or raise at Risk
`r`, it shows one at every higher Risk up to 100 (past 100 there is no entry, hence `hr'`).

```lean
theorem exploreHandAt_moves (risk : Nat) (ms : List BotMoveRecord) (i r : Nat)
    (hi : i < ms.length) (hr : r ≤ 100) :
    ((exploreHandAt risk ms)[i]?.bind fun e => e.moves[r]?) =
      some (botDecide (Sliders.ofRisk r) ms[i].seed ms[i].hole ms[i].board ms[i].state).action

theorem exploreHandAt_more_risk_continues (risk : Nat) (ms : List BotMoveRecord) (i : Nat)
    (hi : i < ms.length) (hbet : 0 < ms[i].state.toCall) (r r' : Nat) (hr : r ≤ r')
    (hr' : r' ≤ 100)
    (h : (((exploreHandAt risk ms)[i]?.bind fun e => e.moves[r]?).getD Action.fold).continues) :
    (((exploreHandAt risk ms)[i]?.bind fun e => e.moves[r']?).getD Action.fold).continues
```

The old `exploreHand_moves` and `exploreHand_risk_monotone` keep their statements and proofs
(about the caution sweep, now a special case of the same function).

### Examples with every hypothesis met, and bad outputs rejected

- `more_risk_never_folds_a_call` on `exStart` with nine-two offsuit: the call at Risk 26 gives
  the call at Risk 100 (`OneSlider.lean`).
- `exploreHandAt_moves` and `exploreHandAt_more_risk_continues` on `exRecord` (`Proofs/Explain.lean`).
- `ideal_river_set` on the A K 2 5 7 board (`OneSliderRiver.lean`), and
  `botDecide_no_bet_off_river` before the flop with the rock and the maniac
  (`Proofs/Explain.lean`).
- Rejected: a mapping `badMap r = ⟨r, 100 - r⟩` fails all three mapping statements; an explorer
  that showed the Risk-50 fold at every Risk is wrong at Risk 100, where the bot calls; a bet
  with queen-jack at Risk 50 together with a check at Risk 100 is impossible.
- Limit: for the two river theorems the premise (the bot bets at the lower setting) is shown
  by `#guard` in the interpreter, since a river decision ranks 1,081 hands and `decide` in the
  kernel would be too slow; the example takes it as a hypothesis and discharges every other
  one by `decide`. `more_bluff_never_checks_a_bet` is exercised through the `ofRisk` example;
  `bluffCount_mono` and `mem_bettingSet_mono` are lemmas, not registered.

## Trusted surface added

New definitions a reviewer must read: `Sliders.ofRisk` (`Slider.lean`), `View.shownRisk` and
the optional parameter on `viewOf`, `decideWithCounts`, `botDecide`; `Session.risk`;
`exploreHandAt`, `exploreHandWith`, `exploreMoveWith`, `movesBySetting`, `riverMoveRanked`,
`bettingSetRanked`, `riverRoleRanked` (`Explain.lean`). The two explorer statements read only
`.moves`, but `exploreHandAt`'s body also computes `effect`, `continuesFrom` and `riskMatters`,
so `riskEffect`, `RiskEffect`, `continuesFrom`, `continuesUpTo`, `Action.same`, `streetOfBoard`,
`countsTable`, `countsIn` and `BotMoveRecord.countsKey` are in the transitive surface
(`#spec_surface` would list them). Everything else in the statements already existed. Existing theorem statements in `Checks/Challenge.lean` are unchanged in text;
their meaning changes only where `botDecide`, `viewOf`, `Command` and `Session` changed as
described above, and `Session.botChoice` is covered by `botDecide_action_shown`.

## Not done, and decisions for Devom

- **One engine commit, not protocol-first.** The brief asked for the protocol change as its
  own commit with the theorems following. The Session proofs needed `botDecide_action_shown`
  to stay green, so 34e7886 carries protocol, explorer and theorems together. Lane 2 should
  build on the branch head (the protocol has not changed since 34e7886; the later commits are
  docstrings, theorems and docs).
- **Step 7 checks.** F01-F03: title, authors, venue, year and pages verified against the
  publisher or Semantic Scholar and the scanned articles (Kyle's page range differs by one
  between sources; noted). The symbol-level Avellaneda-Stoikov formulas are marked UNVERIFIED
  in the notes (Greek letters lost in extraction; taken from a vendor write-up). Chen and
  Ankenman is not cited: A03 never opened it. Minimum defence frequency confirmed absent from
  `engine/`. THEORY.md's line references are pinned to 64b2e3d and re-checked against 71ee280.

- **Presets** (step 6): the brief's ladder stands (Mia 50, Dex 40, Rook 25, Ivy 0, Vex 100);
  `docs/THEORY.md` section 5 gives the reasons from the sources. One wording point: above Risk
  50 caution is already 0, so Vex calls exactly as Mia does and differs only in bluffing. The
  UI should say that, or "more Risk" above 50 reads as "calls more".
- **Mystery reveal**: lives in `src/app/api/game/route.ts`, not Lean. The route picks one
  hidden Risk. As shipped by lane 2 the request is `{"cmd":"reveal","risk":n}` and the reply
  is `{risk, guess, off}` with `guess` a number (not the brief's `{"guess":{"risk":n}}` and
  `{risk, off}`); a `bluff_pct` field is refused with 400.
- **River bluff reason text**: unchanged, see above.
- **The explorer's `bluffsFrom` pattern** ("checks below Risk k, bluffs from k up") is backed
  by `more_risk_never_checks_a_bet`; the classifier still falls back to
  `varies` for any other shape, so the JSON never claims a pattern the moves do not show.
- **Proofs drawer and README should cite `exploreHandAt_moves` and
  `exploreHandAt_more_risk_continues`** as the app's explorer theorems; `exploreHand_moves` and
  `exploreHand_risk_monotone` are about the caution sweep the app no longer shows.
- **Suggested `guarantees.ts` T4 entry** (from the helper): title "More Risk never turns a call
  into a fold"; says: facing a bet in one spot, if the bot calls or raises at some Risk it does
  at every higher Risk, and on the river with no bet to face, more Risk never turns a bet into a
  check; Risk sets a caution that falls and a bluff share that rises and never
  passes 60; the bot calls exactly when the call, with a lost chip counted 1 + caution/50 times,
  is worth at least folding (at Risk 0 a lost chip counts three times, at Risk 25 twice, from 50
  up once); a call that can never lose chips is taken at every Risk. Theorems:
  `more_risk_never_folds_a_call`, `more_risk_never_checks_a_bet`, `ofRisk_caution_antitone`,
  `ofRisk_bluff_monotone`, `ofRisk_bluff_le_60`, `risk_monotone`, `botDecide_risk_monotone`,
  `callPays_iff_takes`, `bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it`,
  `more_risk_takes_fewer_gambles`, `no_loss_always_taken`. Assumes: the same spot (state, cards,
  seed, counts), and the call at most the pot.
- **Minimum defence frequency**: the engine computes it nowhere; `docs/THEORY.md` says so.
- **The app CI job is red on this branch** until lane 2's web change lands: `route.ts` still
  sends `bluff_pct`, which the engine now refuses. The proofs job is independent.
- **Demo record**: `docs/demo/find-demo-hands.mjs`, `scenes.json`, `challenges.json` and
  `src/app/api/game/demo.test.ts` send `bluff_pct` and must be rerun after the web change. Scenes
  (a), (c) and the practice spots are Risk 100 exactly; scene (b) is Risk 0 exactly (its reason
  text becomes "at Risk 0"); the old (50, 33) and (0, 0) settings are not on the line and their
  rows must be re-recorded at Risk 50 (the contract file has the full list).
- **`sunday/review-fixes`** (2fa13e1, the helper's three items: six Challenge docstrings, the
  stale `review_sound` comments, and `value_strongest`, `bluffs_weakest`,
  `botHands_ne_nil_of_board` registered): merged into this branch as 003427c, no conflicts;
  58 Comparator names after the merge. Its two docstrings for `exploreHand_moves` and
  `exploreHand_risk_monotone` described the explorer the app shows, which is now
  `exploreHandAt`; reworded to say "the caution sweep" (statements unchanged). Once this
  branch is in main, delete `sunday/review-fixes` and its worktree at
  `~/vibe-check-review-fixes`.

## Web tests against the new engine (expected red until lane 2 lands)

`npm test` with `POKER_BIN` set to the new build: 6 files fail, 37 of 296 tests. Every failure
is `bluff_pct was removed; Risk sets both`: `route.ts` still sends `bluff_pct` on `new_game`,
and the Mystery route picks a (risk, bluff) pair. Failing files: `insights.test.ts`,
`program.test.ts`, `demo.test.ts`, `challenges.test.ts`, `route.test.ts`, `mystery.test.ts`.
The other 13 files (259 tests) pass. The per-file fixes are in
`tasks/reports/sunday-1-lane2-contract.md`.
