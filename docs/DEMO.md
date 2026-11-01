# Demo record

For the short live walkthrough, start with [DEMO_QUICKSTART.md](DEMO_QUICKSTART.md).

This file records the demo hands, the practice-challenge spots and the morning checks.
Every hand here was played on the compiled Lean engine, with scripted human moves. The
user has now confirmed all three practice scenes in the browser with the expected grades
and outcomes. The remaining visual checks are tracked in `DEMO_QUICKSTART.md`.

One-slider recheck, November 1: the bot now has one setting, Risk. The hands were found with
the old two sliders, at the settings that map exactly to a Risk: Risk 0, Bluff 60 is now
Risk 100 (Vex), and Risk 100, Bluff 0 is now Risk 0 (Ivy). All six scenes and challenges
passed again on the one-slider engine below, with the same cards, moves, grades and
results. Only scene (b)'s reason changed, because it quotes the Risk. Rook (Risk 0, Bluff
0%) has no exact Risk, so checklist rows 3, 4 and 7 now use Mia (Risk 50), checked on the
same engine.

## What the hands were checked on

- **Engine.** `poker.exe` with SHA-256
  `3a392d797dac0ba47e19164482fc136cf6f244a7d91d337e917851c8e313f9d6`. It was linked on
  Nov 1, 2026 at 12:09 PM PST, from branch `sunday/one-slider-web` at commit `f81df9d`,
  which holds lane 1's one-slider engine (`sunday/one-slider` at `073e2e5`, with
  `sunday/review-fixes`). Later commits, up to `c11cf65`, change only comments, proofs and
  proof imports, not the code the program runs. If the demo machine rebuilds, record the new
  SHA here.
- **Checked on** Nov 1, 2026, 12:48 PM PST. Each river spot was replayed twice from
  `new_game`, with the same seed and moves: once ending in a call, once in a fold. Both
  replays reached the same river state and the same `worth_bb`.
- **Turn mode: exact.** The bot counts every river card and every opponent hand (45,540
  outcomes). The mode is a fixed constant in `engine/Engine/Equity.lean`, with its benchmark.
  The flop uses 1,000 seeded random deals. The river is exact.
- **Lean proofs CI**: the README's evidence line names the green run (audit, Comparator,
  `lake check` and a fresh-clone launch).
- **All hands are hand 1 of a new game, with an entered seed.** You (the human) are on the
  button: you post the small blind, act first before the flop and last after it.
- **Cards** are written as in the JSON: rank then suit, `T` is a ten. The table shows suit
  symbols instead.

Recheck everything with the program the app will run. From the repository root, in
PowerShell:

```powershell
$env:POKER_BIN = "$PWD\engine\.lake\build\bin\poker.exe"
node docs/demo/find-demo-hands.mjs --check
```

In bash: `POKER_BIN=engine/.lake/build/bin/poker node docs/demo/find-demo-hands.mjs --check`.

It prints `PASS` or `FAIL` for the three practice spots and the three scenes, and exits 1 on
a `FAIL`. `npm test` also replays scene (a) through the route (`src/app/api/game/demo.test.ts`).

## The three scenes

| Scene | Pitch time | Opponent | Seed | Your moves | What it shows |
| --- | --- | --- | --- | --- | --- |
| (b) | 0:30 | Ivy (Risk 0) | 1 | Raise to 150 | The bot folds a 58% hand to a big raise. |
| (c) | 1:30 | Vex (Risk 100) | 1 | Call, Check, Check, then Call | The bot bets king-high on the river as a designated bluff. |
| (a) | 2:30 | Vex (Risk 100) | 6 | Raise to 30, Check, Check, then Call | The review grades the river call Mistake. |

Ivy and Vex are named opponents on the setup screen. Picking one sets the Risk slider. Lean
sets the bluff share from Risk: 0% for Ivy, 60% for Vex. The table shows both at the top.

### Scene (b): Risk 0. The bot folds to a big bet.

- **Setup.** Pick Ivy (Risk 0). Enter seed `1`. Click Start.
- **You hold** 3c 8c. The bot holds Ks 9d (hidden).
- **Move 1.** Type `150` in the raise box. Click "Raise to 150".
- **The screen shows:**
  - Ivy folds. You win the blinds. Your stack is 510 (+10).
  - Click Review. "No graded move in this hand." "Lean grades one decision: your call or
    fold after the bot makes the first bet on the river. This hand ended before the river."
    Your raise has no badge in the move list.
  - Why the bot played this way: "Fold: not worth calling 140 to win 160 at Risk 0, with
    win chance 58%."
- **Optional contrast.** The same seed with Mia (Risk 50) or Vex (Risk 100) and the same
  raise: the bot calls 140. The review's Risk explorer for Ivy's fold says "Folds at Risk
  0-35, calls at 36-100." This is the direction T4 proves: more Risk can turn a fold into a
  call, never a call into a fold.

### Scene (c): Risk 100. The bot bluffs the river.

- **Setup.** Pick Vex (Risk 100). Enter seed `1`. Click Start. These are the same
  cards as scene (b).
- **You hold** 3c 8c. The bot holds Ks 9d.
- **Moves.**
  1. Preflop: click "Call 5". The bot checks.
  2. Flop 4h Qh 7c: the bot checks. Click "Check".
  3. Turn Tc: the bot checks. Click "Check".
  4. River 8d: the bot bets 20 into a pot of 20. Click "Call 20".
- **The screen shows:**
  - Showdown. Your pair of eights beats the bot's king-high. Your stack is 530 (+30).
  - Review: it opens on "You call 20", which carries the Best badge (★). The coach box:
    "Calling is Best." "You win 59.6% against the hands the bot bets here (a tie counts
    half). Calling needed 33.3% to break even." "Calling was worth +1.57 BB; folding was
    worth 0.00 BB. Best: worth as much as the best choice." (JSON: `worth_bb.call` 1.57,
    `equity_had` 0.596, `equity_needed` 0.333.)
  - Why the bot played this way, last line: "Bet 20: a bluff, picked at Bluff 60%."
- **Two ways to show the bluff.** Both work; pick one before the pitch.
  - **Peek off.** The audience sees the bet. The bot's cards appear
    only at the showdown, and the reasons after the hand say "a bluff, picked at Bluff 60%".
  - **Peek on (integrated).** Turn on "Peek at bot's cards" before the river. The
    audience sees Ks 9d while the bot bets 20: king-high, betting as a bluff. The moves, the
    showdown and the review are the same as with peek off.
- This spot is also the `catch-bluff` practice spot.

### Scene (a): the game review of a bad river call

- **Setup.** Pick Vex (Risk 100). Enter seed `6`. Click Start.
- **You hold** 4h Jh. The bot holds 6s 4c.
- **Moves.**
  1. Preflop: type `30` in the raise box. Click "Raise to 30". The bot calls.
  2. Flop 9s 5d 2c: the bot checks. Click "Check".
  3. Turn Ks: the bot checks. Click "Check".
  4. River 3d: the bot bets 60 into a pot of 60. Click "Call 60".
- **The screen shows:**
  - Showdown. The bot shows 6s 4c, a straight (2 to 6). You lose. Your stack is 410 (−90).
  - Review: it opens on "You call 60", which carries the Mistake badge (?). The coach box:
    "Calling is a Mistake." "You win 18.5% against the hands the bot bets here (a tie counts
    half). Calling needed 33.3% to break even. Folding was Best." "Calling was worth
    −2.67 BB; folding was worth 0.00 BB. Mistake: 2 to 5 big blinds worse than the best
    choice."
  - The exact values: `worth_bb` call −2.67, fold 0. `equity_had` 0.185, `equity_needed`
    0.333.
  - The three earlier moves have no badge.
  - Below, "The hands the grade counts": "On this board the bot bets with 810 two-card
    hands: 324 for value and 486 bluffs. Your cards block 73 of them. Of the 737 left, you
    beat 132, tie 9 and lose to 596."
  - Why the bot played this way, last line: "Bet 60: a value hand, among the strongest 30%
    on this board."
- **Folding the same spot** is graded Best, with the same worths.
- This spot is also the `avoid-bad-call` practice spot.

#### Scene (a) as `/api/game` requests (the Sunday fresh-clone script)

Send these bodies in order, each as a `POST` to `/api/game`. Every reply must have
`"ok":true`.

| # | Request body | Expected reply |
| --- | --- | --- |
| 1 | `{"cmd":"new_game","seed":"6","risk":100}` | hand 1, preflop, your cards `["4h","Jh"]` |
| 2 | `{"cmd":"act","action":"raise","amount":30}` | flop `9s 5d 2c`; the bot called, then checked |
| 3 | `{"cmd":"act","action":"check"}` | turn `Ks`; the bot checked |
| 4 | `{"cmd":"act","action":"check"}` | river `3d`; the bot bet 60; `legal.call` is 60 |
| 5 | `{"cmd":"act","action":"call"}` | `status` `handOver`; `result.outcome` `player1`; bot cards `["6s","4c"]` |
| 6 | `{"cmd":"review","hand":1}` | the last decision is the graded river call (below) |

The last entry of `review.decisions` must contain these fields. It also includes the
integrated `range` data:

```json
{"equity_had":0.185,"equity_needed":0.333,"label":"Mistake","street":"river","worth_bb":{"call":-2.67,"fold":0},"your_action":"call"}
```

With the server running (`make run`), this shell script plays it. It prints `PASS` if the
review has the Mistake label.

```bash
URL=http://localhost:3000/api/game
for body in \
  '{"cmd":"new_game","seed":"6","risk":100}' \
  '{"cmd":"act","action":"raise","amount":30}' \
  '{"cmd":"act","action":"check"}' \
  '{"cmd":"act","action":"check"}' \
  '{"cmd":"act","action":"call"}' \
  '{"cmd":"review","hand":1}'; do
  reply=$(curl -s -X POST "$URL" -H 'content-type: application/json' -d "$body")
done
echo "$reply" | node -e '
let input = "";
process.stdin.on("data", chunk => input += chunk);
process.stdin.on("end", () => {
  const reply = JSON.parse(input);
  const decision = reply.review?.decisions.at(-1);
  if (!reply.ok || decision?.label !== "Mistake" || decision.worth_bb.call !== -2.67) {
    throw new Error("Demo verdict did not match");
  }
  console.log("PASS");
});'
```

## Practice spots (`docs/demo/challenges.json`)

Each spot is hand 1 of a new game. `moves` are your moves before the river decision. The
file also has the river state, the bot's river reason, both results and how it was checked.

| `id` | Seed | Risk | Your moves | Best | Labels (call, fold) | `worth_bb` call | If you choose Best |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `catch-bluff` | 1 | 100 | call, check, check | call | Best, Inaccuracy | +1.57 | Pair of eights beats the bot's Ks 9d bluff: +30 chips. |
| `avoid-bad-call` | 6 | 100 | raise to 30, check, check | fold | Mistake, Best | −2.67 | You lose only your 30: −30 chips. Calling loses 90 to 6s 4c. |
| `right-and-lose` | 4 | 100 | call, check, call | call | Best, Blunder | +10.32 | Your three sevens lose to the bot's 6s 4c straight: −90 chips. |

- `right-and-lose` is a real, worthwhile call. With 6h 7d on 8c 2d 5s 7h 7s, you have three
  sevens. You win 90.7% against the hands the bot bets there, and need 33.3%. Folding would
  be a Blunder (−10.32 BB against calling). The bot holds one of the few hands that win.
- In `right-and-lose` the bot bets 20 on the turn and you call. That is the third move.
- `human_net_chips` is what you won or lost in hand 1, against your 500 at the start.

## Release checklist

### UI click-through (Devom)

Play each in the browser, with `make run` or the PowerShell steps in the README. The
expected results come from the engine replays above, and from reading the code where noted.

| # | Check | Opponent, seed | Moves | Expected | Pass | Fail |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Fold | Mia (Risk 50), seed 1 | Fold | Hand over. You 495, bot 505. Review: "No graded move in this hand." and "This hand ended before the river."; "The bot made no moves this hand." Next hand deals hand 2. | [ ] | [ ] |
| 2 | Showdown | Vex (Risk 100), seed 1 | Scene (c) | Both hands shown with names: Pair beats High Card. You 530. | [ ] | [ ] |
| 3 | All-in and game over | Mia (Risk 50), seed 1 | Click the All-in chip, then "All-in 500" | The bot calls 490 all-in. The board runs out to 8d. Your pair of eights wins. Game over: you have 1,000. Seed 1 is shown, with "Replay these cards". No Next hand. | [ ] | [ ] |
| 4 | Short stack | Mia (Risk 50), seed 1 | Hand 1: Call 5, Check, Check, Check. Next hand. Hand 2: click the All-in chip, then "All-in 510". | Hand 1: the bot checks every street (at Risk 50 its king-high is not in the river betting set); you win at showdown (510). Hand 2: the bot calls 5, you go all-in for 510, and the bot calls 480 all-in, all it has. The 20 it cannot match comes back to you. Board Qh 6c 6s 2s Th: your Ac Js beats its Ah 8s on the kicker. Game over: you have 1,000. | [ ] | [ ] |
| 5 | Graded review | Vex (Risk 100), seed 6 | Scene (a) | Mistake, −2.67 BB, 18.5% vs 33.3%. | [ ] | [ ] |
| 6 | Ungraded review | Ivy (Risk 0), seed 1 | Scene (b) | "No graded move in this hand." and "This hand ended before the river." The raise has no badge. | [ ] | [ ] |
| 7 | Replay by seed | Mia (Risk 50), seed 1 | After check 3, click "Replay these cards", then All-in 500 again | The same cards (3c 8c) and the same result. Starting seed 1 by hand gives the same cards too. | [ ] | [ ] |
| 8 | Rejected input | any, seed 1 | Type `15` in the raise box | The UI keeps raises inside Lean's bounds: the box goes back to 20 when it loses focus, so the UI cannot send 15. To see Lean reject it, send `{"cmd":"act","action":"raise","amount":15}` after `new_game` (seed 1): the reply is `{"error":"illegal move",...}` with the state unchanged (checked on the engine). | [ ] | [ ] |
| 9 | Engine restart error | any | Start a game. Stop the `poker.exe` that this server started. Click any action. | A Game lost dialog offers New game. No live action buttons remain available; subsequent requests continue to report the lost game until a new one starts. | [ ] | [ ] |
| 10 | Peek toggle | Vex (Risk 100), seed 1 | Scene (c), Peek on from the start | Off by default. When on, Ks 9d show, marked as peeked. Nothing else changes: the same bot moves, the same showdown and the same review (+1.57 BB, 59.6% vs 33.3%), plus "You peeked at the bot's cards this hand. The grade assumes you didn't know them." | [ ] | [ ] |

Stop only the `poker.exe` of your own server (Task Manager shows it under Node). Other
servers may run their own copies.

Also check the integrated features:

| # | Feature | Opponent, seed | Moves | Expected | Pass | Fail |
| --- | --- | --- | --- | --- | --- | --- |
| 11 | Range viewer | Vex (Risk 100), seed 6 | Scene (a), open the review | The bot's set on 9s 5d 2c Ks 3d has 324 value hands and 486 bluffs, before your cards are removed (T7: bluffs are the whole number nearest to 324 × 60 / 40). The box "The hands the grade counts" says 810 two-card hands, 324 for value and 486 bluffs; your cards block 73; of the 737 left you beat 132, tie 9 and lose to 596. That gives the 18.5% equity. | [ ] | [ ] |
| 12 | Risk explorer | Ivy (Risk 0), seed 1 | Scene (b), open the review | The bot's preflop fold reads "Folds at Risk 0-35, calls at 36-100." There is one change point: it folds at Ivy's Risk 0 and calls from Risk 36 up. | [ ] | [ ] |
| 13 | Proofs drawer | any | Click "What is guaranteed?" | It lists T1 to T9 in plain words, each with its Lean names. Every name in `engine/comparator.json` appears in it. | [ ] | [ ] |
| 14 | Practice challenges | buttons on the setup screen | Load each, then call or fold | Each stops at the river bet from the table above. The review gives the labels in the table. `right-and-lose` says "Right decision, unlucky result." | [ ] | [ ] |
| 15 | Mystery game | Mystery on | Play 3 hands, guess, reveal | No Risk, bluff share or bot reasons show before the reveal; the review says "The bot's reasons, the hands it bets and the Risk explorer stay hidden until its Risk is revealed." The guess is one number, Risk. The reveal shows your guess, the bot's real Risk and the difference, and the bluff share Lean set from that Risk. | [ ] | [ ] |

### After an engine change

1. Build the engine once, in one checkout.
2. Run `node docs/demo/find-demo-hands.mjs --check` with `POKER_BIN` set to that build. All
   six lines must say `PASS`.
3. On a `FAIL`, run `node docs/demo/find-demo-hands.mjs --write` to pick new hands. Then
   update this file, `docs/PITCH.md`, `src/app/api/game/demo.test.ts` and
   `src/lib/challenges.ts` together.
4. Run `npm test` with `POKER_BIN` set. `demo.test.ts` must pass.
5. Update "What the hands were checked on" above with the new engine hash and commit.

### Sunday check

| Item | Value |
| --- | --- |
| OS and machine | WSL2 Ubuntu 26.04.1 on Windows, kernel 6.18 microsoft-standard, 20 cores, 15 GB RAM (the demo machine) |
| Commit | 2c1ccac (rerun of the web half; the server reports `engineCommit` 2c1ccac, turn mode exact). The from-empty Lean build time below was measured on 45d13b3, whose engine code is the same; the incremental rebuild on 2c1ccac took 8.7 s. |
| Date and time | 2026-11-01, 14:43 to 14:47 PST, rerun about 15:05 PST |
| `make install && make run` on a fresh clone | [ ] pass [x] fail: GNU make is not installed in this WSL (`make: command not found`; apt has 4.4.1) and there is none on the Windows side. Every recipe step run by hand passed: `cd engine && lake build` from an empty `.lake` in 47.7 s wall (3 min 52 s CPU, 135 jobs, 119 MB binary); incremental rebuild 0.15 s; `npm ci` 8.8 s; `npm run build` 6.6 s; `npm start --port 3001` ready in about 2 s. Re-run the literal command after `sudo apt-get install -y make`. |
| Scene (a) script above | [x] PASS: six requests all ok; last decision Mistake, worth call −2.67 BB, fold 0, equity had 0.185, needed 0.333 |
| Full `npm test` against the fresh build | [x] PASS: 23 files, 466 tests, 29 s |
| Green Lean proofs CI run for this commit (link) | [Run 41358927590 on 2c1ccac](https://github.com/DevomB/vibe-check-2026-project/actions/runs/41358927590), success. Later commits change only `docs/DEMO.md`, which the workflow does not watch. The runs for 45d13b3 and 1f0768d show "cancelled": superseded by the next push under the workflow's concurrency rule, not failures. |

### Build-path notes for the Sunday check

These were seen and are not fixed yet; they are planned for after judging.

- `make run` depends on `lean` and runs `npm run build` every time. Its port check
  (`Makefile:37`) runs after the build, so a busy port shows up only after a full build.
- `Makefile:4` joins PATH with `:`. Native Windows GNU make uses `;`, so it may not find
  elan's `lake`. The Makefile says to use Git Bash on Windows.
- A fresh `lake build` from an empty `.lake` took 47.7 s wall on the demo machine (20 cores) on
  Nov 1; see the Sunday check table.
