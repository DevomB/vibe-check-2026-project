Build path changed: no. No build file was edited. The Lean build now also compiles three new modules (`Engine/Explain.lean`, `Engine/ExplainTests.lean`, `Engine/Proofs/Explain.lean`), under a minute more on this laptop, mostly the `#guard`s in `ExplainTests.lean`; `npm run build`, `make install` and `make run` do the same things as before.

# Job 4 report: river range viewer and Risk explorer (branch `review-insights`)

Worktree `C:\Coding-Projects\vc-insights`. Branched from `origin/web-hardening` at **65b16f9**,
after its committed `tasks/reports/devom-1-web.md` said "Ready for dependent jobs: yes" (checked
with a fresh fetch, not from the branch's existence). `node_modules` is a junction to the main
checkout; `engine\.lake` was copied from `..\vc-web`.

## Checks run on the final code (57d9424)

- `cd engine && lake build`: passes (99 jobs). No `sorry`, `admit`, `axiom`, `native_decide`,
  `maxHeartbeats` or `maxRecDepth` in the new Lean files.
- `npm run typecheck`: clean. No `any`, `@ts-` or lint suppressions in the new or changed TS.
- `npm test`: 15 files, 233 tests, all pass. Baseline on 65b16f9 was 14 files, 230 tests; the 3 new
  ones are in `src/app/api/game/insights.test.ts`.
- `#print axioms` of the new theorems: `propext`, `Quot.sound`, and `Classical.choice` for the two
  explorer theorems (as for T3 and T4). Nothing else.
- A render check, not committed (scratch only, no React test library in the repo): played seed 7
  through the route, then rendered `ReviewModal` to HTML with `react-dom/server`, with and without
  `hideSliderInfo` and `onShowProof`. It found the range sentence, the explorer, the summary, the
  reasons and three proof links when shown; none of the slider panels or reasons and one proof link
  (the grades) when hidden; no links without `onShowProof`.
- Not run: a look in a browser, `npm run build` (it needs job 1's temporary `turbopack.root`
  workaround in a worktree; the UI change is only components, already typechecked and rendered),
  `checks/audit.sh`, Comparator and `lake check` (Linux only).
- Heavy commands ran one at a time under the named mutex `Local\VibeCheckHeavyWork`, released in
  `finally`, and each `lake build` first waited until no other `lake`/`lean` process ran.

## Steps

| Step | Status | Commit |
| --- | --- | --- |
| 1. Baseline | done: lake build (93 jobs), typecheck, 230/230 | none |
| 2. Range viewer data in Lean (must) | done | b20e531 |
| 3. Risk explorer data in Lean (must) | done | 5c56998 |
| 4. UI (must) | done | 358ffdd |
| 5. Route tests (should) | done | 9b93fc2 |
| 6. Theorem (stretch) | done, statement needs Devom's OK | 57d9424 |

### What each step did

- **2.** `rangeOf : RiverSpot → RangeSummary` in `Engine/Explain.lean`. It uses the review's own
  `riverBettingSet`, `RiverSpot.blocks`, `RiverSpot.botHands` and `scoreCounts`. Each graded
  decision in the review JSON gets `"range": {value, bluffs, blocked, beat, tie, lose}`. Ungraded
  decisions have **no `range` key** (not `null`), so the existing `SessionTests` guard on the
  ungraded JSON is unchanged. Guards: exact numbers on four spots (for example the king-high
  straight in `exRiverSpot`: 324 value, 160 bluffs, 26 blocked, 449/9/0), and
  `value + bluffs - blocked` = the review's hand count on five spots.
- **3.** While the game plays, it only records each bot move's inputs (see the Session diff
  below). When a review is asked for, `exploreHand`:
  - works out the counts with `countsFor` once per different (seed, bot cards, board). All moves on
    one street of a hand share them, so a hand needs at most four, and the turn's ~0.5 s once;
  - gets the move at every Risk 0-100 with `decideWithCounts`, holding the betting state, seed,
    cards, board and Bluff fixed. With no bet to face the bot never looks at Risk, so it decides
    once and fills all 101 places (proved equal: `decideView_no_bet`; also checked by a guard
    against deciding at each Risk). Without this, each river opening move would rank the board's
    1,081 hands 101 times (~2 s);
  - classifies the move: `noBet` (no bet to face: opening bets, checks, river bets), `raises` (75%
    or more: raises before Risk is used), `callsAlways`, `foldsAlways`, or `callsUpTo k`; with
    `continuesUpTo`, `riskMatters` and a one-sentence `summary` made in Lean ("Calls at Risk 0-84,
    folds at 85-100.").
  The review JSON gets `"risk_explorer": [...]`, one entry per bot move: street, pot and toCall (as
  the bot saw them), counts, the game's Risk, the move made and the 101 moves (named as the table
  names them, "Call", "Bet 60"), continuesUpTo, riskMatters, effect, summary. It is **`null` while
  the hand is played** (like `bot_reasons`: the counts show how strong the bot's hand is). The
  review command stays read-only; `Session.review` itself is unchanged.
  Guards: one record of each effect kind; three real seeded hands (moves stop before the turn,
  because `#guard` runs in the interpreter) where every entry's move at the game's Risk is the move
  the bot made, the record equals what `botDecide` gives, and the 101 moves never go from fold back
  to call; the JSON fields of a real entry; `null` mid-hand.
- **4.** `RangeViewer.tsx`: "The bot bets 484 hands here: 324 for value and 160 bluffs. Your cards
  block 33. Of the 451 left, you beat 144, tie 0 and lose to 307." plus a thin beat/tie/lose bar.
  `RiskExplorer.tsx`: one button per bot move ("Preflop: Call"); for the chosen move, the situation
  and counts, a Risk slider 0-100 showing Lean's move at that Risk, a marker and "Back to Risk 50"
  for the Risk the bot used, and Lean's summary sentence. It starts on the first move where Risk
  matters. Both only draw what Lean sent. Styles are inline with the existing CSS variables, so
  `globals.css` is untouched (job 5 also adds components).
- **5.** `insights.test.ts` plays hand 1 of seed 7 (Risk 50, Bluff 33; raise to 30, then check or
  call) to a graded river call, and checks: `range` is present, adds up and agrees with
  `equity_had`; ungraded moves have none; `risk_explorer` has one entry per bot move and per
  reason; at the game's Risk each entry shows the move made; no fold-then-call; the effect kinds
  are consistent; the explorer is `null` mid-hand.
- **6.** See "Theorem for Devom to approve" below. Not added to `Checks/`.

## Session.lean: the exact lines changed (for the merge with job 2)

Only these two hunks, nothing else in the file:

```diff
@@ -43,6 +43,10 @@ structure HandLog where
   decisions : Array Decision := #[]
   /-- One plain sentence per bot move, in order. Shown only once the hand is over. -/
   reasons : Array String := #[]
+  /-- For each bot move, in order: what `botDecide` was given apart from the sliders (the
+  hand's seed, the bot's cards, the board, the chips) and the move made. The review's Risk
+  explorer (`Engine/Explain.lean`) decides again from these; nothing is worked out here. -/
+  botMoves : Array (Nat × List Card × List Card × State × Action) := #[]
 
 /-- What the game program remembers between commands. -/
 structure Session where
@@ -172,6 +176,7 @@ def Session.runBot : Nat → Session → Session
     | .error _ => s   -- never happens: see above
     | .ok next =>
       let next := next.logHand fun l => { l with reasons := l.reasons.push c.reason }
+      let next := next.logHand fun l => { l with botMoves := l.botMoves.push (handSeed s.game.seed s.game.handNo, h.hole bot, h.board, h.chips, c.action) }
       let h' := next.game.hand
       let opensRiver := h.board.length == 5 && h.chips.toCall == 0 && c.action matches .raiseTo _
       let next := if opensRiver && h'.ended.isNone && h'.chips.toAct == human then
```

Merge notes:
- The new line uses `s`, `h` (the hand before the move) and `c` (the move actually played). If job 2
  removes the `botMove` fallback, `c` is simply `s.botChoice`; keep the line right after the
  `reasons` line. The arguments must stay exactly what `Session.botChoice` passes to `botDecide`
  (`handSeed s.game.seed s.game.handNo`, `h.hole bot`, `h.board`, `h.chips`); the guards in
  `ExplainTests.lean` (`handOk`) fail if they drift.
- The field is a tuple of existing types, so `Session.lean` needed no new import or structure.
- Job 2's proofs that unfold `runBot` will see one more `logHand`. It only writes the log; no game
  state reads it.

Other shared files:
- `engine/Engine.lean`: three `import` lines appended (`Engine.Explain`, `Engine.ExplainTests`,
  `Engine.Proofs.Explain`). Job 2 may append its own; keep both.
- `engine/Engine/Protocol.lean`: one `import Engine.Explain` line and the review part only
  (`RangeSummary.json`, `RiskExplorerEntry.json`, `reviewJson`).
- `src/lean/protocol.ts`: types appended at the end only. `ReviewDecision` and `LeanReview` gain
  their fields by interface merging (`range?`, `risk_explorer?`), so no earlier line changed. Both
  are optional, so job 5's Mystery mode can delete them and the types stay sound.

## Contract with job 5

- `ReviewModal` props: `hideSliderInfo?: boolean` hides the range viewer, the Risk explorer and the
  bot's reasons (it shows "The bot's reasons, its betting range and the Risk explorer stay hidden
  until its settings are revealed." instead). `onShowProof?: (id: string) => void` shows "Why can I
  trust this?" links with ids `"review"` (under the graded decisions), `"bluff"` (in each range
  viewer) and `"risk"` (under the explorer). No links when it is not given.
- JSON names as agreed: `review.decisions[i].range` (graded decisions only) and
  `review.risk_explorer`. The range numbers reveal Bluff, and the explorer reveals Risk (its `risk`
  field and the moves), so both must be hidden in Mystery mode.

## Timing

One seeded game through the route (`POST` handler, as the tests use it): seed 2026, Risk 50, Bluff
33, the human checks or calls, 25 hands, 96 human moves, review after each hand (timed apart). Same
game before and after (identical hand and move counts). Before = job 1's binary at 65b16f9.

| Run | Play time | Review time per hand |
| --- | --- | --- |
| before (1st) | 11.3 s | max 60 ms |
| after step 3 | 11.0 s | ~0.47 s, max 0.68 s |
| before (2nd, back to back) | 10.9 s | max 41 ms |
| after (final, back to back) | 10.9 s | ~0.47 s, max 0.68 s |

- Play speed is unchanged: the game only records the inputs, it works out nothing extra.
- A review is slower by design: it works out the turn's counts once (~0.5 s on this machine) for
  hands that reached the turn. Far inside the 30 s bridge timeout. The worst case is one count per
  street, about 1 s. The review opens when asked for (R or the button), so play never waits for it.
- Conditions, honestly: Windows 11 laptop shared with other overnight jobs (other `node`/`lake`
  processes running, 1.7 GB of 15.7 GB memory free at the final run). Heavy work was serialized by
  the mutex, so the runs did not overlap other heavy work, but the machine was not idle. Not
  measured on the demo hardware.

## Theorem for Devom to approve (`Engine/Proofs/Explain.lean`)

In plain words:

- **`exploreHand_moves`: the Risk explorer shows the real bot.** Take the bot moves the game
  recorded in a hand, and the game's sliders. For each recorded move and each Risk from 0 to 100,
  the move the explorer shows at that Risk is exactly the move `botDecide` makes at that Risk, with
  the game's Bluff and the move's recorded seed, cards, board and betting state.
- **`exploreHand_risk_monotone`:** for each recorded move, if the explorer shows a call or raise at
  some Risk, it shows one at every lower Risk (T4 applied to the explorer).
- **`rangeOf_adds_up`:** in the range viewer, value hands + bluffs = blocked + beat + tie + lose.
- **`rangeOf_counts`:** the range viewer's beat, tie and lose are the counts the review grades with.

What it does not say: that the recorded inputs are the ones the bot really used. That is checked by
guards (`handOk`) and route tests, not proved. Examples in the file show the hypotheses hold on a
real record, and that a wrong explorer (repeating the bot's fold at every Risk) is rejected.
Definitions to review: `exploreHand`, `exploreMove`, `movesByRisk`, `countsIn`, `countsTable`,
`BotMoveRecord`, `rangeOf`, `RangeSummary`, and the existing `botDecide`, `RiskMonotone`,
`reviewRiver`.

## For Devom to look at

1. **Seed 7, Risk 50, Bluff 33.** Hand 1: raise to 30, then check (or call) to the river, and call
   the bot's river bet of 60. Open the review (R).
   - The river call is graded **Good**, with the range viewer under it: "The bot bets 484 hands
     here: 324 for value and 160 bluffs. Your cards block 33. Of the 451 left, you beat 144, tie 0
     and lose to 307." and a green/grey/red bar.
   - "What if the bot's Risk were different?" starts on **Preflop: Call**: "The bot had to call 20
     to win 40", the slider at 50 showing "Call (its real setting)", and "Calls at Risk 0-87, folds
     at 88-100." Drag to 88: "Fold". "Back to Risk 50" returns.
   - Pick **River: Bet 60**: "Risk doesn't change this move: with no bet to face, the bot doesn't
     look at Risk." The slider shows "Bet 60" everywhere.
   - Expect the review to take about half a second to open on hands that reached the turn.
2. **A hand with no river bet** (for example fold preflop): no range viewer; the explorer lists the
   bot's moves, or is absent if the bot made none.
3. **After job 5 merges:** a Mystery game's review shows no range viewer, no explorer and no
   reasons, only the hidden note; the "Why can I trust this?" links open the drawer at review,
   bluff and risk.
4. Check the slider's "bot's Risk" marker lines up with the thumb at Risk 0 and 100 (it is placed by
   percentage, so it can sit a few pixels off at the ends).

## For the docs

- **River range viewer.** Next to each graded river call or fold. It says how many hands the bot's
  river betting set has on that board (value hands and bluffs), how many of them use one of your
  cards (so the bot cannot hold them), and of the hands left, how many your hand beats, ties and
  loses to. These are the hands the review grades against. Backed by T7 `bluff_frequency` (the
  bluff count of that same set matches the Bluff slider), T5/T8 for the grade itself, and the new
  `rangeOf_adds_up` / `rangeOf_counts` (pending approval, not in `Checks/`).
- **Risk explorer.** After a hand, for each bot move: pick it, move a Risk slider from 0 to 100, and
  see what the bot would have done with everything else the same (same cards, board, chips, seed
  and Bluff). It says in one sentence where the bot changes from calling to folding ("Calls at Risk
  0-84, folds at 85-100."), or that Risk does not affect the move (no bet to face; or raises with a
  win chance of 75% or more; or the same at every Risk). Backed by T4 `risk_monotone` (only one
  change point, from call to fold) and the new `exploreHand_moves` (the explorer's moves are the
  real bot's moves; pending approval, not in `Checks/`).
- Both are hidden in Mystery mode until the reveal, and computed by Lean when the review is opened.
