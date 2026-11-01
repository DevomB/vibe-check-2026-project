# Live demo walkthrough — November 1, 10:45 AM Pacific

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
4. Allow about two seconds for the result and automatic review. Expect **Mistake**,
   **−2.7 BB** for calling, **0 BB** for folding, and **19% equity vs 33% needed**.
5. The range panel should show **324 value + 486 bluffs**, with **73 blocked**. Of the
   remaining hands you beat **132**, tie **9** and lose to **596**.
6. Open **Why can I trust this?** Confirm the Proofs drawer opens. Close it and the review.
7. Click **Try again**, then **Fold**. The same decision should be graded **Best**.

If the review does not open automatically, try **Review** and report that the automatic
opening failed. Do not count the automatic-opening check as passed just because manual
Review works.

## Second test: a right decision can lose

1. **Leave table**, choose **Fast**, then select **Make the right decision and still lose**.
2. Click **Call 60**. The bot wins and your stack becomes **410** again.
3. This time expect **Best**, **+10.3 BB**, and **91% equity vs 33% needed**.
4. Expect the message **Right decision, unlucky result**.

Pitch line: "The same losing outcome can follow a good decision or a bad one. This grades
the choice against the bot's defined range, rather than rewarding luck."

## Third test: catch a bluff

1. Return to setup and select **Catch a bluff**.
2. Optionally turn on **Peek at bot's cards**. It should show **Ks 9d** and mark the cards
   as peeked. Turn it off again and verify the cards hide before showdown.
3. Click **Call 20**. Your pair of eights wins; your stack becomes **530**.
4. Expect **Best**, **+1.6 BB**, and **60% equity vs 33% needed**. A hand played with Peek
   on should carry the review warning.

## Fourth test: Risk changes a decision

1. Return to setup, pick **Ivy** (Risk **100**, Bluff **0%**), seed **1**, and **Start**.
2. Raise **to 150**. The bot folds; your stack becomes **510**.
3. Open **Review**. The human preflop raise should say **not graded yet**.
4. In the Risk explorer, select the bot's fold and move Risk between **0** and **100**.
   Expect **Call** at 0, **Fold** at 100, and:
   **Calls at Risk 0–29, folds at 30–100.**
5. Open the Risk guarantee link. It describes this fixed-decision comparison, not a promise
   about whole matches.

## Finish the release check

After those scenes, use the complete checklist in `DEMO.md`: one normal game through Next
Hand, all-in/short stack, game-over replay record, Mystery guessing after three completed
hands or game over, malformed-input behavior, and engine-loss recovery. Do not kill a game
process until you have identified the process belonging to the server you intend to test.

Record visual results here; leave unchecked until actually seen:

| Browser check | Pass | Fail / observation |
| --- | --- | --- |
| Practice loads at the expected river | [x] | User confirmed Fast → Avoid a bad call → Call 60 reached the expected review. |
| Bad call: Mistake and automatic review | [x] | User confirmed the review opens with Mistake, about −2.7 BB. |
| Retry/fold: Best | [ ] | |
| Right-and-lose: Best despite losing | [x] | User confirmed the bot wins but the review says Best, +10.3 BB. |
| Catch a bluff: win and Best | [x] | User confirmed a win and Best, about +1.6 BB, with Peek off. |
| Peek reveals and re-hides cards | [x] | User confirmed Ks 9d reveal, re-hide, and the review retains the Peek warning. |
| Range panel shows expected counts | [ ] | |
| Risk explorer works | [ ] | |
| Proof links open and close cleanly | [ ] | User supplied the rendered T1–T8 drawer text; T7 focus and closing remain unconfirmed. |
| Normal Next Hand, all-in and replay | [ ] | |
| Mystery hides settings, then reveals once | [ ] | |
| Engine loss offers recovery without live actions | [ ] | |

Use the next 15 minutes for this walkthrough, then fix observed blockers before adding
anything else. After fixes, repeat the affected scene and rehearse `PITCH.md` with a timer.
