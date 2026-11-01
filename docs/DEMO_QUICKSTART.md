# Live demo walkthrough — November 1, 10:45 AM Pacific

> **Record of the morning build.** The checkmarks below were earned on the two-slider build
> (`507b21c`, UI `0b62296`). The one-slider build that the 6:30 PM demo shows (main at
> `c11cf65` or later) still needs its own click-through; the Mystery row's two-number guess
> cannot happen in the one-slider UI. [DEMO.md](DEMO.md)'s scenes are already recorded on the
> one-slider engine.

## One-slider click-through (build: ____, time: ____, tester: ____)

Expected values are from [DEMO.md](DEMO.md)'s recorded scenes (checked on the one-slider
engine) and its checklist rows. One tab, Peek off except row 6. Fill in build, time and tester
above, and tick "Seen" only for what you saw.

| # | Check | Opponent, seed | Moves | Expect | Seen |
| --- | --- | --- | --- | --- | --- |
| 1 | Setup screen | — | — | One Risk slider, 0 to 100, no Bluff slider anywhere. Five presets: Ivy 0 (Rock), Rook 25, Dex 40, Mia 50 (Ideal), Vex 100 (Maniac); clicking one moves the slider. The table header shows the Risk and the bluff share Lean reports: 0% for Ivy, 33% for Mia, 60% for Vex. | [ ] |
| 2 | Scene (b), fold to a big bet | Ivy (Risk 0), seed 1 | Type 150, "Raise to 150" | Ivy folds; you 510. Review: "No graded move in this hand." The reason: "Fold: not worth calling 140 to win 160 at Risk 0, with win chance 58%." | [ ] |
| 3 | Risk explorer on that fold | same, open the review | move the explorer slider | "Folds at Risk 0-35, calls at 36-100." The move flips at 36 and nowhere else. | [ ] |
| 4 | Contrast | Mia (Risk 50), seed 1 | "Raise to 150" | The bot calls 140 (same cards as row 2; more Risk turned the fold into a call). | [ ] |
| 5 | Scene (c), the river bluff | Vex (Risk 100), seed 1 | Call 5, Check, Check, Call 20 | Showdown: your pair of eights beats king-high; you 530. Review opens on "You call 20" with the Best badge: 59.6% against 33.3% needed, +1.57 BB. Last reason: "Bet 20: a bluff, picked at Bluff 60%." | [ ] |
| 6 | Peek | Vex (Risk 100), seed 1, Peek on from the start | as row 5 | Ks 9d shown and marked as peeked while the bot bets 20; same moves, showdown and review as row 5. | [ ] |
| 7 | Scene (a), the graded mistake | Vex (Risk 100), seed 6 | Type 30, "Raise to 30", Check, Check, Call 60 | Bot shows 6s 4c, a straight; you 410. Review opens on "You call 60" with the Mistake badge: 18.5% against 33.3%, −2.67 BB; earlier moves have no badge. "The hands the grade counts": 324 value hands and 486 bluffs, your cards block 73, of the 737 left you beat 132, tie 9, lose to 596. Last reason: "Bet 60: a value hand, among the strongest 30% on this board." | [ ] |
| 8 | Fold at once | Mia (Risk 50), seed 1 | Fold | You 495, bot 505. Review: "No graded move in this hand." Next Hand deals hand 2. | [ ] |
| 9 | All-in and Game Over | Mia (Risk 50), seed 1 | All-in chip, "All-in 500" | Bot calls 490; board runs out to 8d; your pair of eights wins; Game Over at 1,000; seed 1 shown with Replay. All Game Over buttons visible without horizontal scrolling. | [ ] |
| 10 | Replay by seed | from row 9 | "Replay these cards", then All-in 500 | Same cards (3c 8c), same result. Typing seed 1 at setup gives the same cards. | [ ] |
| 11 | Rejected input | any, seed 1 | type 15 in the raise box, click away | The box snaps back to 20; nothing is sent. | [ ] |
| 12 | Engine loss | any | start a game, stop this server's poker.exe, click any action | "Game lost" dialog offers New game; no live action buttons remain. | [ ] |
| 13 | Proofs drawer | any | "What is guaranteed?" | Rows T1 to T9 (and T1b, T2b if the drawer has them), each with Lean names. T4 reads "More Risk never turns a call into a fold, or a bet into a check"; T7 "Risk sets the bluffs in the river betting set" and, after the river-game push, its textbook-test lines. | [ ] |
| 14 | Practice challenges | the three buttons on setup | load each, then call or fold | Each stops at the river bet; labels as in docs/DEMO.md's practice table; right-and-lose says "Right decision, unlucky result". | [ ] |
| 15 | Mystery | Mystery on | play 3 hands, guess, reveal | No Risk, bluff share or bot reasons before the reveal; the guess is one Risk slider; the reveal shows the true Risk and how far off you were, once. | [ ] |
| 16 | Showdown label | Vex (Risk 100), seed 1 | as row 5 | The showdown names both hands: "Pair beats High Card". | [ ] |

Open **http://localhost:3000**. Use one tab. The production server is running the integrated
implementation from `507b21c`; all required MVP features are implemented. The open release
work is the visual walkthrough, any fixes it reveals, and a timed pitch rehearsal.

The production API was exercised on a separate server on port 3001 so these checks did not
replace your game on port 3000. All three challenges and the Risk contrast passed. This is
API evidence; it does not mark the browser checks below as passed.

## First test: a bad call

1. On setup choose **Fast**. Under **Practice**, click **Avoid a bad call**.
2. It should load directly at a river decision, with **Call 60** available.
3. Click **Call 60**. You lose the hand; your stack becomes **410**.
4. Allow about two seconds for the result and automatic review. Expect **Calling is a
   Mistake.**, **You win 18.5%** against a needed **33.3%**, and **Calling was worth
   −2.67 BB; folding was worth 0.00 BB.**
5. The box **The hands the grade counts** should say the bot bets with **810** two-card
   hands, **324 for value and 486 bluffs**, and your cards block **73**. Of the **737** left
   you beat **132**, tie **9** and lose to **596**.
6. Open **Why can I trust this grade?** Confirm the Proofs drawer opens. Close it and the
   review.
7. Click **Try again**, then **Fold**. The same decision should be graded **Best**.

If the review does not open automatically, try **Review** and report that the automatic
opening failed. Do not count the automatic-opening check as passed just because manual
Review works.

## Second test: a right decision can lose

1. **Leave table**, choose **Fast**, then select **Make the right decision and still lose**.
2. Click **Call 60**. The bot wins and your stack becomes **410** again.
3. This time expect **Calling is Best.**, **You win 90.7%** against a needed **33.3%**,
   and **Calling was worth +10.32 BB**.
4. Expect the message **Right decision, unlucky result**.

Pitch line: "The same losing outcome can follow a good decision or a bad one. This grades
the choice against the bot's defined range, rather than rewarding luck."

## Third test: catch a bluff

1. Return to setup and select **Catch a bluff**.
2. Optionally turn on **Peek at bot's cards**. It should show **Ks 9d** and mark the cards
   as peeked. Turn it off again and verify the cards hide before showdown.
3. Click **Call 20**. Your pair of eights wins; your stack becomes **530**.
4. Expect **Calling is Best.**, **You win 59.6%** against a needed **33.3%**, and **Calling
   was worth +1.57 BB**. A hand played with Peek on should carry the warning **You peeked
   at the bot's cards this hand.**

## Fourth test: Risk changes a decision

1. Return to setup, pick **Ivy** (Risk **0**, the Rock), seed **1**, and **Start**.
2. Raise **to 150**. The bot folds; your stack becomes **510**.
3. Open **Review**. Expect **No graded move in this hand.** and **This hand ended before
   the river.** The raise has no badge.
4. In the Risk explorer, select the bot's fold and move Risk between **0** and **100**.
   Expect **Fold** at 0, **Call** at 100, and:
   **Folds at Risk 0-35, calls at 36-100.**
5. Open **Why can I trust the Risk explorer?** It describes this fixed-decision comparison,
   not a promise about whole matches.

## Finish the release check

After those scenes, use the complete checklist in `DEMO.md`: one normal game through Next
Hand, all-in/short stack, game-over replay record, Mystery guessing after three completed
hands or game over, malformed-input behavior, and engine-loss recovery. Do not kill a game
process until you have identified the process belonging to the server you intend to test.

Record visual results here; leave unchecked until actually seen:

Browser tester follow-up: all 13 functional checks below passed on the previous demo
(engine `507b21c`), including the operator-assisted engine-loss test. The report also found
clipped Game Over buttons and a missing losing-hand label. Both fixes were visually
confirmed on UI build `0b62296`: all four Game Over buttons are fully visible without
horizontal scrolling, New game works, and the showdown says "Pair beats High Card".
These results do not validate the subsequent one-slider engine/UI changes.

| Browser check | Pass | Fail / observation |
| --- | --- | --- |
| Practice loads at the expected river | [x] | User confirmed Fast → Avoid a bad call → Call 60 reached the expected review. |
| Bad call: Mistake and automatic review | [x] | User confirmed the review opens with Mistake, about −2.7 BB. |
| Retry/fold: Best | [x] | Browser tester confirmed Best with identical call/fold worths. |
| Right-and-lose: Best despite losing | [x] | User confirmed the bot wins but the review says Best, +10.3 BB. |
| Catch a bluff: win and Best | [x] | User confirmed a win and Best, about +1.6 BB, with Peek off. |
| Peek reveals and re-hides cards | [x] | User confirmed Ks 9d reveal, re-hide, and the review retains the Peek warning. |
| Range panel shows expected counts | [x] | 810 = 324 value + 486 bluffs; 73 blocked; beat 132, tie 9, lose 596. |
| Risk explorer works | [x] | Tester moved the slider: 0/29 Call, 30/100 Fold (the old two-slider engine; the one-slider engine gives Fold at 0-35, Call at 36-100). |
| Range proof link opens at T7 | [x] | User confirmed T7/Bluff is in view and highlighted. |
| Proof drawer closes back to the review | [x] | T4/T5/T7 links open correctly and close to the intact review. |
| Normal Next Hand, all-in and replay | [x] | Includes short-stack 20-chip return. On UI `0b62296`, user confirmed all four Game Over buttons are visible and New game works. |
| Mystery hides settings, then reveals once | [x] | One observed guess 50/30 vs 17/39 correctly showed differences 33/9. |
| Engine loss offers recovery without live actions | [x] | Stopped only port-3000 engine PID 15380; user confirmed Game lost, blocked actions and successful New game. |

Use the next 15 minutes for this walkthrough, then fix observed blockers before adding
anything else. After fixes, repeat the affected scene and rehearse `PITCH.md` with a timer.
