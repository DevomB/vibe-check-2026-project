# The 5-minute pitch

This script follows MVP §14 and uses the hands in [DEMO.md](DEMO.md). Say only what the
claim table at the end backs. Each line there names its Lean theorems in
`engine/comparator.json`.

Before you start: have the setup screen open. Check that `node docs/demo/find-demo-hands.mjs
--check` printed six `PASS` lines on the build you will use.

| Time | Part | Opponent | Seed | Your moves |
| --- | --- | --- | --- | --- |
| 0:00 | The hook | | | |
| 0:30 | Build your opponent: scene (b) | Ivy (Risk 100, Bluff 0%) | 1 | Raise to 150 |
| 1:30 | Change its personality: scene (c) | Vex (Risk 0, Bluff 60%) | 1 | Call 5, Check, Check, Call 20 |
| 2:30 | The game review: scene (a) | Vex (Risk 0, Bluff 60%) | 6 | Raise to 30, Check, Check, Call 60 |
| 3:30 | What is proven | | | |
| 4:30 | The close | | | |

## 0:00 The hook (30 seconds)

> "Build your opponent, play it, and review your river calls and folds. The game runs in Lean,
> and our Lean proofs check properties of that code and of the review's stated model."

## 0:30 Build your opponent (1 minute): scene (b)

Pick Ivy: Risk 100, Bluff 0%. Enter seed 1 and start. Type 150 and click "Raise to 150".

> "Risk says how much a lost chip hurts. At Risk 100, a lost chip counts three times as much
> as a won chip. I raise to 150 from the small blind. Ivy folds."

Click Review and point at the bot's reason: "Fold: not worth calling 140 to win 160 at Risk
100, with win chance 58%."

> "It had a 58% hand, and it still folded: at this Risk, the call was not worth it. The bot
> folds only when that is true, and we proved it."

Optional, if time allows: the same seed with Rook (Risk 0) and the same raise. The bot calls.

> "Same cards, same raise, less Risk: now it calls. Lowering Risk can turn a fold into a call.
> Raising Risk can never turn a fold into a call."

## 1:30 Change its personality (1 minute): scene (c)

Pick Vex: Risk 0, Bluff 60%. Enter seed 1 again: the same cards. Click "Call 5", "Check",
"Check". On the river the bot bets 20.

Pick one of these two versions in the morning:

- **Peek off (works on `main` now).**
  > "Bluff 60% means 60% of the hands it bets on the river are bluffs. Is this one?"

  Click "Call 20". The showdown shows the bot's king-high. Your pair of eights wins. Open
  the review: "Bet 20: a bluff, picked at Bluff 60%."
  > "It was a bluff, and the bot tells us so after the hand. Not before: during the hand
  > its messages stay generic."
- **Peek on (after job 1 merges).** Turn on "Peek at bot's cards" at the start of the hand.
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

Click "Call 60". The bot shows 6s 4c, a straight. Open the review: **Mistake**. "Call was
worth −2.7 BB", "Your equity 19% · needed to call 33%".

> "The review looks at every hand Vex bets on this board, its strong hands and its bluffs,
> minus the hands my cards block. Against those, jack-high wins only 18.5% of the time,
> with a tie counting half. The call needed 33%. So, on average, calling lost 2.67 big blinds: a Mistake. The grade would be
> the same whatever cards the bot really held. It grades the decision, not the luck."

The review ignores the earlier betting. If asked: "It's exact for that set of hands. That set
is a simple model of what the bot holds, and we say so."

## 3:30 What is proven (1 minute)

> "The game itself is written in Lean, and the theorems are about that code, not a copy of it:
> the betting rules, the shuffle, the bot and the review. Lean's kernel checks every proof.
> Comparator checks that each proof states exactly the theorem we agreed on."
>
> - "In every game the engine can reach, there are always exactly 1,000 chips."
> - "No card is ever dealt twice."
> - "The engine accepts only legal moves, and the bot only picks legal moves."
> - "At the same decision, raising Risk never turns a fold into a call or a raise."
> - "The Bluff slider sets how many bluffs are in the bot's river betting set, to the
>   nearest whole hand."
> - "The review compares call and fold under its stated model. Best means you lost nothing
>   against the better choice. A worse label always means more chips lost. And the grade
>   never depends on the bot's real cards."
>
> "What we do not prove: the web page, and the JSON between the page and Lean. The loop that
> runs a session is tested, not proved yet."

## 4:30 The close (30 seconds)

> "Next, we would build the Proofs screen, and a bot that reads you: it bluffs more only when
> its own numbers say it pays. Thank you."

## Claim table

Every spoken claim, the theorems that back it (all in `engine/comparator.json`), what they
say, and where they stop. CI ran the audit, Comparator and `lake check` on `main` at
`df6904a` ([run 41281639578](https://github.com/DevomB/vibe-check-2026-project/actions/runs/41281639578)).
The final commit needs its own green run.

| Spoken claim | Lean theorems | What they say, in one sentence | Limit |
| --- | --- | --- | --- |
| "The theorems are about the Lean code the game runs." | All below | The statements name the engine's own functions (`step`, `shuffle`, `botDecide`, `reviewRiver`), not copies. | The session loop (`Engine/Session.lean`) and the JSON layer (`Engine/Protocol.lean`) are covered by no theorem. They are tested. |
| "Lean's kernel checks every proof. Comparator checks each statement." | (CI) | The audit allows only `propext`, `Classical.choice` and `Quot.sound`; Comparator matches each proof to `Checks/Challenge.lean`. | Seen green on `df6904a`. Rerun for the final commit. |
| "In every game the engine can reach, there are always exactly 1,000 chips." (T1) | `step_keeps_chips`, `startHand_keeps_chips`, `chips_always_1000` | An accepted move and a new deal keep the chip total, so every reachable game has exactly 1,000 chips. | "Reachable" means a new game, then accepted moves and next hands (`Game.Reachable`). No theorem yet says the app's session only builds such games. |
| "No card is ever dealt twice." (T2) | `shuffle_same_cards`, `shuffle_fair`, `no_card_dealt_twice` | The shuffle keeps exactly the 52 cards, and in every reachable game the dealt cards are all different. | The same "reachable" limit. It does not say the shuffle is random. |
| "The engine accepts only legal moves, and the bot only picks legal moves." (T3) | `accepted_move_is_legal`, `illegal_move_rejected`, `player_to_act_may_act`, `botDecide_legal` | A move the engine accepts is legal; an illegal move is rejected and changes nothing; the bot's move is legal whenever the player to act may act. | The buttons and raise bounds the browser shows (`legalOptions`) are not proved equal to the rules (`Legal`). The engine still rejects anything illegal. MVP §14's "Every move is legal" is softened to this. |
| "At the same decision, raising Risk never turns a fold into a call or a raise." (T4) | `risk_monotone`, `botDecide_risk_monotone`, `more_risk_takes_fewer_gambles` | For one spot (same state, cards, counts and Bluff), if the bot calls or raises at some Risk, it does so at every lower Risk too. | One decision at a time. It says nothing about whole games, or how many hands a bot wins. |
| "At this Risk the call was not worth it. The bot folds only when that is true." (scene b) | `bot_folds_only_when_not_worth_it`, `bot_calls_only_when_worth_it`, `callPays_iff_takes`, `no_loss_always_taken` | The bot calls exactly when the call is worth it, with a lost chip counted (1 + Risk/50) times. | Both theorems assume the call is at most the pot. That holds here (140 ≤ 160), but no theorem proves it for every real hand yet. "Folds everything but strong hands" (MVP §14) is cut: no theorem says that. |
| "The Bluff slider sets how many bluffs are in the bot's river betting set, to the nearest whole hand." (T7) | `bluff_frequency`, `value_and_bluffs_apart`, `bot_bets_its_set` | On any river board, the set has 324 value hands and the whole number of bluffs nearest to 324 × b / (100 − b); no hand is both; the bot's river role bets exactly the hands in the set. | A count of hands in a set, not how often the bot bluffs in play. No theorem on `main` says the bluffs are the weakest hands (the code picks them that way). |
| "At 60%, it adds 486 bluffs, picked from its weakest hands, and this is one of them." (scene c, peek on) | `bluff_frequency` | 324 × 60 / 40 = 486 exactly, so the set has 486 bluffs. | "Picked from its weakest hands" is the code's rule (MVP §5), not a theorem on `main`. That Ks 9d is a bluff comes from the bot's own reason. |
| "The review compares call and fold under its stated model. Best means you lost nothing against the better choice. A worse label always means more chips lost." (T5) | `review_worth`, `review_lost`, `review_best_iff`, `review_label_monotone`, `review_call_best_iff_equity` | The worth of calling is the exact average over the bot's possible hands, in big blinds; Best means the choice was worth at least the other; fewer big blinds lost never gets a worse label; calling is Best exactly when your equity is at least the equity needed. | The model is every hand the bot's river rule bets on that board, minus your cards. It ignores the earlier betting. Only river calls and folds against the bot's opening bet are graded. The label bands (0.5, 2, 5 BB) are in `labelFor`, which a reader must check. |
| "18.5% against 33% needed: a Mistake." (scene a) | `review_call_best_iff_equity`, `review_lost` | 0.185 < 0.333, so the call is not Best; it lost 2.67 BB, which is in the Mistake band (2 to 5). | The decimals are rounded for display. The engine compares exact fractions. |
| "The grade never depends on the bot's real cards." (T8) | `no_hindsight`, `bot_hand_in_review` | Two hands that look the same to you get the same review, whatever the bot holds; the bot's real hand is always one of the hands the review counts. | "Look the same" means the same chips, board and your cards (`SameForHuman`). That the session records the right spot is in `Session.lean`, which no theorem covers. |
| Not spoken; say it if asked: "On the turn and river, the win chance counts every outcome exactly once." (T6) | `enumeration_exact`, `riverOpponentHands_length`, `turnOutcomes_length`, `countsFor_river`, `countsFor_turn` | The river counts each of the 990 opponent hands once; the turn counts each of the 45,540 (river card, opponent hand) pairs once. | The flop is an estimate from 1,000 deals; preflop uses a table of estimates (`data/preflop.json`). The compiler is trusted to run the turn's 46 parallel tasks. |

Claims cut or softened from MVP §14:

- "It folds everything but strong hands": cut. Only "it folds when the Risk-weighted call is
  not worth it" is proved.
- "Every move is legal": softened to "the engine accepts only legal moves, and the bot only
  picks legal moves".
- "Now it fires bluffs on the river": kept as a description of the hand. The proved part is
  the bluff count in the set.
