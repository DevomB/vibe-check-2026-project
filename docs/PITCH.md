# The 5-minute pitch

This script uses the hands in [DEMO.md](DEMO.md). Say only what the claim table at the end
backs. Each line there names its Lean theorems in `engine/comparator.json`. The script
started from MVP §14; the end of this file lists the claims we cut or softened.
The three proof headlines and their demo limits are in [DEMO_THEOREMS.md](DEMO_THEOREMS.md).

Before you start: have the setup screen open. Check that `node docs/demo/find-demo-hands.mjs
--check` printed six `PASS` lines on the build you will use.

| Time | Part | Opponent | Seed | Your moves |
| --- | --- | --- | --- | --- |
| 0:00 | The hook | | | |
| 0:30 | Build your opponent: scene (b) | Ivy (Risk 0) | 1 | Raise to 150 |
| 1:30 | Change its personality: scene (c) | Vex (Risk 100) | 1 | Call 5, Check, Check, Call 20 |
| 2:30 | The game review: scene (a) | Vex (Risk 100) | 6 | Raise to 30, Check, Check, Call 60 |
| 3:30 | What is proven | | | |
| 4:30 | The close | | | |

## 0:00 The hook (30 seconds)

> "This is FoldProof. Build your opponent, play it, and review your river calls and folds. The game runs in Lean,
> and our Lean proofs check properties of that code and of the review's stated model."

## 0:30 Build your opponent (1 minute): scene (b)

Pick Ivy: Risk 0, the Rock. Enter seed 1 and start. Type 150 and click "Raise to 150".

> "Risk is the bot's appetite for risk, from 0 to 100. Ivy is at 0, the Rock: a lost chip
> counts three times as much as a won chip, and it never bluffs. I raise to 150 from the
> small blind. Ivy folds."

Click Review and point at the bot's reason: "Fold: not worth calling 140 to win 160 at Risk
0, with win chance 58%."

> "It had a 58% hand, and it still folded: at this Risk, the call was not worth it. The bot
> folds only when that is true, and we proved it."

Optional, if time allows: the same seed with Mia (Risk 50, the textbook setting) and the same
raise. The bot calls.

> "Same cards, same raise, more Risk: now it calls. Raising Risk can turn a fold into a call.
> It can never turn a call into a fold."

## 1:30 Change its personality (1 minute): scene (c)

Pick Vex: Risk 100, the Maniac. Enter seed 1 again: the same cards. Click "Call 5", "Check",
"Check". On the river the bot bets 20.

Both versions work on the current build. Peek on shows the bluff before the bet; Peek off
keeps the surprise for the showdown.

- **Peek off.**
  > "At Risk 100, 60% of its board-only river betting set is designated bluffs, before my
  > cards remove any hands. Is this one?"

  Click "Call 20". The showdown shows the bot's king-high. Your pair of eights wins. Open
  the review: "Bet 20: a bluff, picked at Bluff 60%." (That is the bot's internal bluff share;
  Risk 100 sets it to 60%. There is no Bluff setting for the player.)
  > "It was a bluff, and the bot tells us so after the hand. Not before: during the hand
  > its messages stay generic."
- **Peek on.** Turn on "Peek at bot's cards" at the start of the hand.
  The audience sees Ks 9d.
  > "I'm peeking, so you can see its cards: king-high. Watch the river." The bot bets 20.
  > "King-high, betting: that's a designated bluff. On every river, the bot's betting set
  > has 324 value hands. At 60%, it adds 486 bluffs, picked from its weakest hands, and this
  > is one of them."

  Click "Call 20". The pair of eights wins. Peeking changes nothing else: the same moves and
  the same review.

## 2:30 The game review (1 minute): scene (a)

Pick Vex again. Enter seed 6. Type 30 and click "Raise to 30". Click "Check", "Check". On
the river, Vex bets 60 into 60. I hold jack-high.

> "Vex bluffs a lot. Maybe this is a bluff. So I call."

Click "Call 60". The bot shows 6s 4c, a straight. Open the review. "You call 60" has the
Mistake badge: "Calling is a Mistake. You win 18.5% against the hands the bot bets here (a
tie counts half). Calling needed 33.3% to break even." "Calling was worth −2.67 BB; folding
was worth 0.00 BB."

Point at the box below, "The hands the grade counts": 324 value hands and 486 bluffs, 73
blocked by my cards; of the 737 left I beat 132, tie 9 and lose to 596.

> "The review looks at every hand Vex bets on this board, its strong hands and its bluffs,
> minus the hands my cards block. Against those, jack-high wins only 18.5% of the time,
> with a tie counting half. The call needed 33%. So, on average, calling lost 2.67 big
> blinds: a Mistake. The labels are chess.com's, and the unit is the big blind, as in poker
> review tools. The grade would be the same whatever cards the bot really held. It grades
> the decision, not the luck. People tend to judge a decision by how it turned out;
> psychologists call that outcome bias. This grade can't: it never depends on the bot's
> cards."

Click "Why can I trust this grade?". The Proofs drawer opens at the review's guarantee;
leave it open for the next part. (The link next to it, "Does the grade use the bot's cards?
No. See the proof.", opens T8.)

The review ignores the earlier betting. If asked: "It's exact for that set of hands. That set
is a simple model of what the bot holds, and we say so."

Optional, instead of the hand counts, if time allows: Practice, "Make the right decision and
still lose". Call 60. The bot wins, yet the call is graded **Best** (+10.32 BB), with "Right
decision, unlucky result."

> "Same lost chips as before, opposite grade: this time the call was right."

## 3:30 What is proven (1 minute)

> "Three promises matter here. First, the grade never depends on the bot's real cards: a
> right decision can lose. Second, Best means the better of call and fold against the
> stated range model, with exact expected-value arithmetic. Third, the Risk explorer
> shows the real bot: in the same spot, more Risk never turns its call into a fold."
>
> "Underneath, the engine conserves all 1,000 chips, never deals a card twice, pays the
> winner according to its hand-ranking rules, and accepts only legal moves."
>
> "Lean's kernel checks the proofs. Comparator matches the agreed theorem statements;
> people must still review the definitions they use. The browser, Node bridge and JSON
> transport are tested, not proved."

## 4:30 The close (30 seconds)

> "Next, we would grade more of the hand, river raises and all-ins, with the same exact
> math, and split each result into skill and luck, with a proof that the two add up. Thank
> you."

## Claim table

Every spoken claim, the theorems that back it, what they say, and where they stop. The
theorems are in `engine/comparator.json` unless a row says otherwise. The CI evidence (audit,
Comparator, `lake check`, fresh-clone launch) is the one line in the
[README](../README.md#run-it); the final commit needs its own green run.

| Spoken claim | Lean theorems | What they say, in one sentence | Limit |
| --- | --- | --- | --- |
| "The theorems are about the Lean code the game runs." | All below | The statements name the engine's own functions (`step`, `shuffle`, `botDecide`, `reviewRiver`), not copies. | The Lean app's game is proved reachable (`app_game_reachable`), and a rejected command changes nothing (`handle_error_unchanged`, `respond_keeps_session_unless_accepted`). The JSON text and the browser/Node transport are tested, not proved. |
| "Lean's kernel checks every proof. Comparator checks each statement." | (CI) | The audit allows only `propext`, `Classical.choice` and `Quot.sound`; Comparator matches each proof to `Checks/Challenge.lean`. | The README's evidence line names the green run. Rerun for the final commit. |
| "In every game the engine can reach, there are always exactly 1,000 chips." (T1) | `step_keeps_chips`, `startHand_keeps_chips`, `chips_always_1000` | An accepted move and a new deal keep the chip total, so every reachable game has exactly 1,000 chips. | "Reachable" means a new game, then accepted moves and next hands (`Game.Reachable`). `app_game_reachable` proves the app's game is always one of these. |
| "No card is ever dealt twice." (T2) | `shuffle_same_cards`, `shuffle_fair`, `no_card_dealt_twice` | The shuffle keeps exactly the 52 cards, and in every reachable game the dealt cards are all different. | The same "reachable" limit. It does not say the shuffle is random. |
| "The engine accepts only legal moves, and the bot only picks legal moves." (T3) | `accepted_move_is_legal`, `illegal_move_rejected`, `legal_move_accepted`, `player_to_act_may_act`, `botDecide_legal`, `legalOptions_exact` | A move the engine accepts is legal; an illegal move is rejected and changes nothing; the bot's move is legal whenever the player to act may act; a legal move in a hand that is not over is always accepted; the engine's list of legal moves (fold, check, the call amount, the raise range) is exactly what the rules allow. | The engine's list of legal moves is proved exact (`legalOptions_exact`); that the browser renders it faithfully is tested, not proved. The engine still rejects anything illegal. MVP §14's "Every move is legal" is softened to this. |
| "Facing a bet, turning Risk up never turns a call into a fold." (T4) | `more_risk_never_folds_a_call`, `ofRisk_caution_antitone`, `ofRisk_bluff_monotone`, `more_risk_never_checks_a_bet`, `risk_monotone`, `botDecide_risk_monotone`, `more_risk_takes_fewer_gambles` | Facing a bet in one spot (the same seed, cards, board and chips), if the bot calls or raises at some Risk, it does so at every higher Risk too. More Risk never makes the bot more cautious, never makes it bluff less, and never turns a river bet into a check. | One decision at a time. It says nothing about whole games, or how many hands a bot wins. |
| "At this Risk the call was not worth it. The bot folds only when that is true." (scene b) | `bot_folds_only_when_not_worth_it`, `bot_calls_only_when_worth_it`, `callPays_iff_takes`, `no_loss_always_taken`, `viewOf_toCall_le_pot` | Facing a bet, if the bot does not raise, it calls exactly when the call is worth it, with a lost chip counted (1 + caution/50) times. Risk 0 sets caution 100, so a lost chip counts three times. | The theorems assume the call is at most the pot; `viewOf_toCall_le_pot` proves that for every view the bot gets. A strong hand (75% or more) with a legal raise raises without using the call rule. "Folds everything but strong hands" (MVP §14) is cut: no theorem says that. |
| "Risk sets how many bluffs are in the bot's river betting set, to the nearest whole hand." (T7) | `ofRisk_bluff_le_60`, `ideal_river_set`, `bluff_frequency`, `value_and_bluffs_apart`, `bot_bets_its_set`, `botDecide_river_follows_set`, `rankRiverHands_sorted`, `value_strongest`, `bluffs_weakest` | Risk sets a bluff share b of at most 60%. On any river board, the set has 324 value hands and the whole number of bluffs nearest to 324 × b / (100 − b) (160 at Risk 50); no hand is both; with no bet to face and a legal bet available, the bot bets exactly the hands in the set; the value hands are the strongest and the bluffs the weakest. | A count of hands in a set, not how often the bot bluffs in play. |
| "At 60%, it adds 486 bluffs, picked from its weakest hands, and this is one of them." (scene c, peek on) | `bluff_frequency`, `bluffs_weakest` | 324 × 60 / 40 = 486 exactly, so the set has 486 bluffs. Every bluff scores no better than any hand outside the bluffs. | That Risk 100 means a 60% share is a `#guard` check in `Engine/Slider.lean`, run at build time, not a Comparator theorem. "Weakest" means the lowest showdown score on that board. That Ks 9d is a bluff comes from the bot's own reason. |
| "The review compares call and fold under its stated model. Best means you lost nothing against the better choice. A worse label always means more chips lost." (T5) | `review_worth`, `review_lost`, `review_best_iff`, `review_label_monotone`, `review_call_best_iff_equity`, `review_hands_ne_nil`, `botHands_ne_nil_of_board` | The worth of calling is the exact average over the bot's possible hands, in big blinds; Best means the choice was worth at least the other; fewer big blinds lost never gets a worse label; calling is Best exactly when your equity is at least the equity needed; the list of hands the bot can hold is never empty. | The model is every hand the bot's river rule bets on that board, minus your cards. It ignores the earlier betting. Only river calls and folds against the bot's opening bet are graded. The label bands (0.5, 2, 5 BB) are the team's choice, in `labelFor`, which a reader must check. |
| "18.5% against 33% needed: a Mistake." (scene a) | `review_call_best_iff_equity`, `review_lost` | 0.185 < 0.333, so the call is not Best; it lost 2.67 BB, which is in the Mistake band (2 to 5). | The decimals are rounded for display. The engine compares exact fractions. |
| "The grade never depends on the bot's real cards." (T8) | `no_hindsight`, `bot_hand_in_review` | Two hands that look the same to you get the same review, whatever the bot holds; the bot's real hand is always one of the hands the review counts. | "Look the same" means the same bluff share (set by Risk), chips, board and your cards (`SameForHuman`). That the session records the right river spot for the review is tested, not proved. |
| Range viewer, the box "The hands the grade counts" (scene a): "324 value hands and 486 bluffs; of the hands left I beat 132, tie 9, lose 596." | `rangeOf_counts`, `rangeOf_adds_up` | The range viewer's beat, tie and lose numbers are the counts the grade uses, and value + bluffs = blocked + beat + tie + lose. | The 324 and 486 come from T7. The bar's drawing is browser code. |
| Not spoken; say it if asked: "The Risk explorer shows what this same bot would have done at every other Risk." | `exploreHandAt_moves`, `exploreHandAt_more_risk_continues` | Each entry is exactly `botDecide`'s move at that Risk (through `Sliders.ofRisk`), on the recorded inputs; facing a bet, it never goes from call back to fold as Risk rises. | That the session recorded the bot's real inputs is tested, not proved. Only one move changes; earlier moves stay as played. |
| Not spoken; say it if asked: "Every hand ends." (T9) | `every_hand_ends` | From any reachable game, a hand has at most 200 accepted moves. | It does not bound a whole match. |
| Not spoken; say it if asked: "On the turn and river, the win chance counts every outcome exactly once." (T6) | `enumeration_exact`, `riverOpponentHands_length`, `turnOutcomes_length`, `countsFor_river`, `countsFor_turn` | The river counts each of the 990 opponent hands once; the turn counts each of the 45,540 (river card, opponent hand) pairs once. | The flop is an estimate from 1,000 deals; preflop uses a table of estimates (`data/preflop.json`). The compiler is trusted to run the turn's 46 parallel tasks. |

Claims cut or softened from MVP §14:

- "It folds everything but strong hands": cut. Only "it folds when the Risk-weighted call is
  not worth it" is proved.
- "Every move is legal": softened to "the engine accepts only legal moves, and the bot only
  picks legal moves".
- "Now it fires bluffs on the river": kept as a description of the hand. The proved part is
  the bluff count in the set.

## Sources and likely questions

Research behind the review's design, from [docs/research/sources/](research/sources/):

- **Grade the decision, not the result.** Baron and Hershey, "Outcome bias in decision
  evaluation", Journal of Personality and Social Psychology 54(4), 1988 (E06). People rate
  the same decision as better when it happened to turn out well.
- **The five labels.** chess.com's Game Review uses Best, Good, Inaccuracy, Mistake and
  Blunder, each a band of loss (E01). Ours are the same idea, in big blinds.
- **Big blinds lost as the unit.** GTO Wizard's hand analyzer reports each mistake as big
  blinds lost (E05).
- **Never using the bot's cards.** DIVAT and PokerTracker's all-in equity judge with both
  players' cards known (E04, E05). That suits measuring luck, not grading a decision you made
  without seeing them.
- **Fixed reasons, not an LLM.** Jacovi and Goldberg (ACL 2020) separate an explanation that
  sounds right from one that shows the real reason (E08). Our reasons come from the bot's
  own numbers.
- **Novelty.** We found no other poker review with machine-checked proofs about its grades
  ([SYNTHESIS.md](research/SYNTHESIS.md) §2). Say "we found no other", not "the first".

If asked:

- **"Why 0.5, 2 and 5 big blinds?"** Our choice. No poker tool publishes its cutoffs (E05);
  chess.com uses the same kind of loss table (E01). What is proved is that Best means nothing
  lost and that a bigger loss never gets a better label (`review_best_iff`,
  `review_label_monotone`).
- **"Is the grade exact?"** Yes, for the stated set of hands: every hand the bot bets on this
  river board, minus the hands your cards block. That set ignores the earlier betting, and we
  say so on screen.
- **"Why no accuracy percentage?"** Left out on purpose (MVP stretch S4). Lichess's published
  formula gives 100% to some moves that lose a little (E02); we would want a proof that 100%
  means no loss.
- **"Why is Risk 50 called Ideal?"** At 50 the bot plays for plain chip profit and bluffs
  33% of its river bets (`ideal_is_textbook`). Its river bet is pot-sized, and 33% is the
  textbook break-even bluff share against a pot-sized bet, so we say it matches the textbook
  ratio, not that it plays best. Sources are in [THEORY.md](THEORY.md).
- **"Is the bot good?"** Not the goal. The bot does exactly what its slider says, provably.
- **"What isn't proved?"** The browser, Node and the JSON text. The engine's own list of legal
  moves is proved exact (`legalOptions_exact`), and the engine still rejects any illegal move.
  See the README's "What we trust".
