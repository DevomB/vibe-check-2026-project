Build path changed: no

# Job 3 report: demo hands, pitch, honest docs

Branch `release-docs` (from `origin/main` at `df6904a`), worktree `C:\Coding-Projects\vc-release`.
Pushed to `origin/release-docs` only. Nothing was merged or pushed to `main`. No installs, no
Lean builds, no servers, and no change to `Makefile`, `package.json`, `package-lock.json`,
toolchain files or `scripts/`. All engine runs and test runs held the `Local\VibeCheckHeavyWork`
mutex, released in `finally`.

## The three demo scenes, short form

All are hand 1 of a new game with an entered seed. You are on the button (small blind).

| Scene | Opponent | Seed | Your moves | Result |
| --- | --- | --- | --- | --- |
| (a) review | Vex (Risk 0, Bluff 60) | 6 | raise to 30, check, check; the bot bets 60 on the river; call | You (4h Jh) lose to 6s 4c, a straight. Review: **Mistake**, `worth_bb` call −2.67 / fold 0, `equity_had` 0.185, `equity_needed` 0.333. Folding is Best. |
| (b) Risk 100 | Ivy (Risk 100, Bluff 0) | 1 | raise to 150 | The bot folds Ks 9d: "Fold: not worth calling 140 to win 160 at Risk 100, with win chance 58%." The same seed at Risk 0 calls. |
| (c) Bluff 60 | Vex (Risk 0, Bluff 60) | 1 | call, check, check; the bot bets 20 on the river; call | The bot bets Ks 9d: "Bet 20: a bluff, picked at Bluff 60%." Your pair of eights wins (+30). Review: call Best (+1.57 BB), fold Inaccuracy. |

Scenes (b) and (c) use the same cards, which makes a neat story: the same king-high folds at
Risk 100 and bluffs at Bluff 60.

## Fixture provenance (`docs/demo/challenges.json`, `docs/demo/scenes.json`)

- **Engine:** `C:\Coding-Projects\vibe-check-2026-project\engine\.lake\build\bin\poker.exe`,
  SHA-256 `19a7b9be2c2528587d86eb8bba22e1d0ab9e48de028a44eaa3802d3ed609dbf4`.
  - It was linked Oct 31 at 18:42 PDT, in the main checkout at `3356666`, with no engine
    files changed in that checkout.
  - The only engine source newer than the binary is `Engine/River.lean`: commit `6384ca5`
    added a doc comment at 18:46. The other two newer files (`RiverBench.lean`,
    `lakefile.toml`) are not part of `poker`.
  - `3356666..df6904a` touches only `engine/Checks/Challenge.lean` and
    `engine/comparator.json`. So the binary matches the engine on `main` at `df6904a`.
- **Finder:** `docs/demo/find-demo-hands.mjs`, plain Node, one engine process per run, JSON
  lines (no server).
- **Search bounds:**
  - Seeds 1 to 40. Sliders (0, 60), then (50, 33), then (100, 0).
  - Two scripted lines: "passive" (call the blind, then check, or call any bet) and
    "raise30" (raise to 30 preflop, then passive).
  - It stopped at seed 6, once every spot was found: 36 river attempts, about 25 s.
  - Scene (b): seeds 1 to 40, a raise to 150 at Risk 100 then at Risk 0. It kept the first
    seed where the bot folds at Risk 100 with a win chance of at least 50% and calls at
    Risk 0. That was seed 1.
- **Replays:** each kept river spot was replayed twice from `new_game`, with the same seed
  and moves: once ending in a call, once in a fold.
  - The two river states had to be identical, and the two reviews had to give the same
    `worth_bb`.
  - The labels, values, outcomes and chip results in the file come from those replays.
- **Independent recheck:** `node docs/demo/find-demo-hands.mjs --check` (a separate run that
  replays the recorded files) printed `PASS` for all three spots and all three scenes.
- **The check rejects bad records:** on a scratch copy, I changed `right-and-lose`'s fold
  label to Mistake and scene (b)'s bot reason. `--check` printed `FAIL` for exactly those
  two, with the recorded and actual values, and exited 1.
- **The three spots:**

| `id` | Seed | Risk, Bluff | Moves before the river decision | Best | Labels (call, fold) | `worth_bb` call | `equity_had` / `equity_needed` | Actual result of Best |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `catch-bluff` | 1 | 0, 60 | call, check, check | call | Best, Inaccuracy | +1.57 | 0.596 / 0.333 | Bot shows Ks 9d (its reason: a bluff). You win, +30. |
| `avoid-bad-call` | 6 | 0, 60 | raise 30, check, check | fold | Mistake, Best | −2.67 | 0.185 / 0.333 | You lose your 30 (−30). Calling would lose 90 to 6s 4c. |
| `right-and-lose` | 4 | 0, 60 | call, check, call | call | Best, Blunder | +10.32 | 0.907 / 0.333 | Your three sevens (6h 7d) lose to the 6s 4c straight: −90. |

- `right-and-lose` meets the brief: it is a graded decision, not a tie. The call is worth
  +10.32 BB under the review's range model, and folding would be a Blunder. Yet the bot
  holds a value hand that beats you at the real showdown.
- **Exact human moves** are in each record's `moves`, using names the route accepts (`call`,
  `check`, `raise` with `amount`). Each record also has the river state, the bot's river
  reason, `result_if_best`, `result_if_other` and `verified` (engine hash, build time,
  checkout commit, check time).
- **For job 5:** the file has been on `origin/release-docs` since commit `f55a3ee` and is
  unchanged since.

## What I added

| Artifact | Commit |
| --- | --- |
| `docs/demo/find-demo-hands.mjs`, `docs/demo/challenges.json`, `docs/demo/scenes.json` | `f55a3ee` |
| `src/app/api/game/demo.test.ts`: replays scene (a) through the route; checks the cards, the bot's bet, the Mistake label and its numbers, and that folding is Best | `bc016db` |
| `docs/DEMO.md`: engine identity, turn mode (exact), scenes, scene (a) as `/api/game` bodies with a curl script, the practice spots, the UI checklist with seeds, moves and pass/fail boxes, after-merge, Sunday and build-path notes | `469b9b5` |
| `docs/PITCH.md`: the 5-minute script on the demo seeds, scene (c) with and without Peek, the claim table | `469b9b5` |
| Doc fixes (below) | `6ef2b5c` |
| This report | `639bd0a` and the commit after it |

**Checks I saw pass:**

- `npm test` with `POKER_BIN` set: 220 of 220 (14 files). That is 217 before, plus my 3.
- `npm run typecheck`: clean.
- `--check`: six `PASS` lines.
- The Lean proofs CI on `main` at `df6904a` is green (audit, Comparator, `lake check`):
  [run 41281639578](https://github.com/DevomB/vibe-check-2026-project/actions/runs/41281639578).
  The allocation's run 41262441215 is older (it ran on `6a68273`).

**The checklist hands I added** were replayed on the engine; only the UI parts are untried:

- Fold at seed 1 (495/505).
- All-in 500 at seed 1 with Rook: the bot calls; game over, you have 1,000.
- Short stack at seed 1 with Rook: hand 1 is checked down, then in hand 2 you shove 510 and
  the bot calls all-in for 480. You get 20 back and win the game.
- A raise to 15: Lean replies "illegal move" with the state unchanged.

The engine-loss row describes `main`'s code (`route.ts`, `useGame.ts`). It was not tried in
a browser.

## What I changed in each doc

**MVP.txt** (line by line; §8 not touched):

- :14: §15 is "the release checks and the settled integration details", not open decisions.
- :21: the theorems cover the betting steps, shuffle, bot and review. The session loop
  (`Engine/Session.lean`) and the JSON layer (`Engine/Protocol.lean`) are not yet covered.
- :112: the layout is settled (§15). The TypeScript prototype stays under `src/` as a test
  reference.
- :117: replaced the old "48 of 48" line. The harness, cases and results are in `tests/diff/`.
  The recorded run passed 11 of 11 checks, including hand ranks on 100,000 random deals.
- :118: "36 preflop starting hands each against a random hand (not hand against hand)".
- :171 and :251: added the green CI run and its commit.
- :178-179: pointers to the checklist in `docs/DEMO.md` and to `docs/PITCH.md`. The items
  stay open: recheck on the final build; rehearse.
- :252: the browser gets every state from Lean. It still imports display helpers (`potTotal`,
  `rankOf`, `suitOf`) and types from the TypeScript prototype. Its Fold button is off when
  there is nothing to call, although Lean allows that fold.
- :254: engine loss is only partly handled: a raw error in flight, then "game was lost", and
  the old table keeps live buttons.

**README.md** (line by line):

- :28: Lean names the made hands from the flop on. The preflop description comes from the
  browser.
- :36: added the CI run link.
- "Still needed": points to `docs/DEMO.md` and `docs/PITCH.md`.
- :57: §15 wording.
- "We trust these definitions":
  - Added `BluffSpec.lean` (`NearestWhole`) and `ReviewSpec.lean` (`callResult`,
    `choiceTotal`, `RiverSpot.total`, `Frac.LE`, `SameForHuman`).
  - Named the definitions in `BotSpec.lean` and `EquitySpec.lean`.
  - Replaced "the engine code is not trusted" with the list of engine definitions that
    statements name directly, and that a reader must check: `Game.Reachable`/`Hand.Reachable`
    (`newGame`, `Game.act`, `Game.nextHand`, `startHand`, `step`), `riverBettingSet`,
    `RiverSpot.botHands`/`prize`/`cost`, `riverSpotOf`, `labelFor`.
- "Not covered":
  - The JSON code is in `Engine/Protocol.lean`.
  - Added `Session.lean`, `legalOptions` vs `Legal`, and `Task.spawn` in `turnCounts`.

**SPEC.md:**

- Dropped "(draft)".
- "Proof targets" now lists T1 to T8 with their Lean names from `Checks/Challenge.lean`,
  and T9/T10 as stretch.
- Says plainly that there is no separate fast evaluator: the game scores hands with the
  spec's `bestScore`.
- "Where things are", "What is proven so far" (with the CI run) and "Still to write" (the
  session theorems, `legalOptions`, T9, T10 if kept, the JSON layer) now match `main`.

**docs/MVP_REVIEW.md:** added the header "Historical log. MVP.txt §11 is the current status."

**docs/proofs-bot-equity.md:35:** now says "Both assume the pot is at least the call. No
theorem yet proves that this holds in every real hand."

- The allocation suggested "checked in tests, not proved". I found no test that checks it
  (I searched the Lean tests and `src/**/*.test.ts`), so I did not write that.
- Job 2's `viewOf_toCall_le_pot` would replace this sentence (see below).

## Apply after merges

Proposed wording only. Apply each item once its branch is merged and its checks pass.

### Job 1 (`web-hardening`)

- **MVP §2, new line after "Table screen"** (Devom added Peek on Oct 31):
  `- Peek: a "Peek at bot's cards" toggle on the table, off by default, shows the bot's two cards, sent by Lean. It changes nothing else, and the review marks a hand that was peeked.`
- **MVP §15 :252** (only if job 1's prototype-import grep is clean and Fold uses `legal.fold`):
  `- Next.js lives under src/; the shipping Lean engine lives under engine/. The browser uses src/lean/protocol.ts and the Node bridge, not the TypeScript game implementation: src/app, src/components, src/hooks and src/lib import no values from src/engine, src/ai or src/review. The Fold button follows Lean's legal.fold.`
- **MVP §15 :254:**
  `- Preflop counts, review history, post-hand reasons, explicit next_hand, rejected-input replies and engine-loss errors are implemented. When the engine stops or hangs, the reply says the game was lost and the table offers only a New game button. One local active game is supported. A lost engine requires a new game; browser refresh does not resume the UI's previous game.`
- **MVP §15 :255 and §5 turn line:** "The state JSON carries `turnMode` ("exact"), and the
  game-over screen shows the replay record: seed, Risk, Bluff, turn mode and engine commit."
- **README "Not covered", JSON bullet:** add "The `peek` flag only adds the bot's cards to a
  reply; like the rest of `Protocol.lean`, it is tested, not proved."
- **docs/DEMO.md checklist row 9:** keep only the after-job-1 expectation.
- **Scene (c):** delete the Peek version Devom does not pick, in both `docs/DEMO.md` and
  `docs/PITCH.md`.
- **README build notes:** job 1 makes `npm run build` work offline (no Google font fetch).
  Job 1's report says how the build path changed.

### Job 2 (Session proofs)

Apply only the theorems that land in `comparator.json` with a green CI run.

- **docs/proofs-bot-equity.md:35:** "Both assume the pot is at least the call.
  `viewOf_toCall_le_pot` proves this whenever the bot acts in a reachable hand."
- **MVP :21:** "...not a model of it. The session loop is covered by
  `handle_error_unchanged`, `handle_keeps_reachable` and `bot_move_accepted`. The JSON layer
  (engine/Engine/Protocol.lean) is not covered by any theorem."
- **README "Not covered", session bullet:**
  > The session loop: `handle_keeps_reachable` proves every game a session plays is
  > `Game.Reachable`, so T1-T3 cover the app's games. `handle_error_unchanged` proves a
  > rejected command changes nothing. `bot_move_accepted` proves the engine accepts the bot's
  > move, so `runBot` has no fallback. Not proved: when the review spot is recorded, and the
  > reasons text.
- **SPEC "Still to write":** remove each session item that is proved.
- **docs/PITCH.md claim table:**
  - T1/T2 rows: drop "No theorem yet says the app's session only builds such games".
  - T3 row: add `bot_move_accepted`.
  - Scene (b) row: cite `viewOf_toCall_le_pot` instead of "no theorem proves it".
- **docs/PITCH.md 3:30:** "The loop that runs a session is tested, not proved yet" becomes
  "The game loop's key steps are proved too; the web page and the JSON layer are tested."
- **README "How the proofs are checked", step 1:** if the stricter `audit.sh` lands, add
  "`implemented_by`, `unsafe`, `@[extern]`, `debug.skipKernelTC`, and any `maxHeartbeats`
  without a comment".

### Aarav (T5/T7 links, diff record, T9)

- `review_lost` is already on `main` (`df6904a`) and is in the claim table.
- **T7 tied to `botDecide`, and `rankRiverHands` sorted:** in the PITCH T7 rows, replace
  "No theorem on `main` says the bluffs are the weakest hands" with the new theorem names,
  and "the bot's river role" with "the bot's actual river move (`botDecide`)".
- **Diff record:** once `tests/diff/results.json` records the commit and toolchain, MVP :117
  becomes "Its recorded run (date, commit, Lean toolchain) passed N of N checks...". Use the
  new numbers.
- **T9, if proved and CI-checked:**
  - MVP §11: "T9 every_hand_ends is proved (theorem name)."
  - SPEC T9: drop "Not proved yet".
  - PITCH: an optional spoken line, "Every hand ends in a bounded number of moves", with a
    claim-table row.

### Job 4 (range viewer, Risk explorer)

- **MVP §2, Review screen, new sentence:** "A graded decision also shows the bot's range:
  its value and bluff hands on that board, the hands your cards block, and how many you
  beat, tie and lose to. A Risk explorer shows what the bot would do at every Risk, for
  each of its decisions."
- **MVP §13 review response:** mention the `range` and `risk_explorer` fields.
- **README "Not covered":** "The range viewer and Risk explorer numbers (`Engine/Explain.lean`)
  are tested with `#guard`, not proved. They reuse `riverBettingSet`, `botHands`,
  `countsFor` and `decideWithCounts`."
- **docs/PITCH.md 2:30, optional line:** "The bot bets 810 hands on this board. My cards
  block N, and I beat W, tie T and lose to L." Fill in N, W, T and L from the merged UI.
- **docs/DEMO.md** rows 11 and 12 become current checks.

### Job 5 (Proofs drawer, practice challenges, Mystery)

- **MVP §10:** "S1 Proofs screen: built as the 'What is guaranteed?' drawer" and
  "S9 Mystery bot: built". Keep §9 as the historical gate.
- **MVP §2, Setup screen:** "...and a Start button. Three practice challenges load rehearsed
  river decisions (`docs/demo/challenges.json`), and a Mystery opponent hides the sliders
  until you guess."
- **docs/PITCH.md 4:30:** "Next, we would build the Proofs screen, and a bot that reads you"
  becomes "Next, we would build a bot that reads you, and finish the proofs for the game
  loop". Optional at 3:30: open "What is guaranteed?" while listing the claims.
- **README "What is ready":** add the drawer, the challenges and Mystery mode.
- **docs/DEMO.md** rows 13 to 15 become current checks.
- **If a spot changes** after the merges, update `src/lib/challenges.ts` along with
  `challenges.json`.

## Proposed T10 wording (Devom's call; not applied)

MVP §8, Tier 3:

> - T10 evaluator_equals_spec: not needed. The engine has no separate fast evaluator:
>   showdowns, equity counts and the river betting set all score hands with the spec's
>   reference `bestScore` (best of the 21 five-card hands). The code that runs is the
>   reference itself, so there is nothing to prove equal. If a faster evaluator is ever
>   added, it must be proved equal to `bestScore` on every `ValidDeal` before the game uses it.

MVP §10: "S8 T10: not needed while the game uses `bestScore` (see section 8)."
MVP §11: "T9 hand termination is optional stretch work. T10 does not apply (no fast evaluator)."

## Still open from MVP §11, with owners

| Item | Owner | Status |
| --- | --- | --- |
| Fresh-clone `make install && make run` on the demo setup | Devom (Sunday cloud check, after the last merge) | Not run by this job (frozen). Build-path notes are in `docs/DEMO.md`. |
| Final UI playthroughs | Devom | Checklist ready in `docs/DEMO.md`, rows 1 to 10, plus 11 to 15 after jobs 4 and 5. |
| Demo record recheck on the final build | Devom (or any morning job) | Run `find-demo-hands.mjs --check` and `npm test` on the merged binary. |
| Pitch rehearsal and the choice of scene (c) version | Devom and the team | Script ready in `docs/PITCH.md`. |
| Claim review update after merges | Devom | Apply the items above. |
| Green Lean proofs CI on the final submitted commit | Devom | `df6904a` is green. The final commit needs its own run. |
| Session theorems (`handle_*`, `bot_move_accepted`, `viewOf_toCall_le_pot`) | Job 2 | Not on `main`. |
| Engine-loss UI, pot display, Fold from Lean, replay record, Peek, no prototype imports | Job 1 | Not on `main`. |
| T7 tied to `botDecide`, ranked set, diff record with commit | Aarav | `review_lost` landed; the rest is not on `main`. |
| T9 (stretch) | Aarav or a cloud job | Not started on `main`. |
| T10 decision | Devom | Proposal above. |

## Remaining release checks

1. Merge jobs 1, 2, 4 and 5 and Aarav's branch. Then rebuild once, and run `--check` and
   `npm test` with `POKER_BIN` set.
2. Apply the "Apply after merges" wording for the branches that landed.
3. Click through the UI checklist and tick the boxes.
4. Sunday: run the fresh clone and the scene (a) script. Record the OS, commit, date and
   result in `docs/DEMO.md`. Link the green CI run for the final commit.
5. Rehearse the pitch. Say only what the claim table backs.
