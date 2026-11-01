# What the app guarantees

Each row is a promise about the game, the Lean theorems that prove it, and what it does not
cover. The same list is shown in the app's Proofs drawer (`src/lib/guarantees.ts`). Every
theorem named here is listed in [`engine/comparator.json`](../engine/comparator.json), and its
exact statement is in [`engine/Checks/Challenge.lean`](../engine/Checks/Challenge.lean).

| # | Guarantee | Theorems | Not covered |
| --- | --- | --- | --- |
| **T1** | **Chips are never created or destroyed.** Every accepted move keeps the chip total, a new hand holds the chips the players brought, and every game always has exactly 1,000 chips. | `step_keeps_chips`, `startHand_keeps_chips`, `chips_always_1000`, `app_game_reachable` | The numbers the web page shows. |
| **T1b** | **The right player wins the pot.** At a showdown, the result comes from the rules' own hand ranking on the real cards and board: the better hand ends with more chips than it started with, the other with fewer, and a tie leaves both where they started. A fold gives the hand to the player who did not fold, who ends with more chips, while the folder ends with fewer. | `showdown_pays_better_hand`, `fold_pays_other_player`, `fold_records_other_player`, `game_hand_from_deal` | — (`game_hand_from_deal` shows every hand the app plays is dealt to two players who both have chips, so this holds for every hand). |
| **T2** | **No card is dealt twice.** The shuffle keeps exactly the 52 cards of a new deck, and the cards on the table are all different. | `shuffle_same_cards`, `shuffle_fair`, `no_card_dealt_twice` | That the shuffle is random. The same seed always deals the same cards. |
| **T2b** | **The board matches the street.** While a hand is played the board has 0 cards before the flop, 3 on the flop, 4 on the turn and 5 on the river, and a showdown always has all 5. | `board_matches_street`, `showdown_has_five_cards`, `game_hand_from_deal` | — |
| **T3** | **Only legal moves.** An accepted move is legal; an illegal move is rejected and changes nothing; a legal move is always accepted; only a player who may act gets the turn; the bot always moves legally; bad or rejected commands leave the game unchanged; the buttons offered are exactly the legal moves, with the right call amount and raise range. | `accepted_move_is_legal`, `illegal_move_rejected`, `legal_move_accepted`, `player_to_act_may_act`, `botDecide_legal`, `bot_move_accepted`, `handle_error_unchanged`, `handle_keeps_reachable`, `respond_keeps_session_unless_accepted`, `legalOptions_exact` | The browser and Node bridge (tested, not proved). The engine still rejects any illegal move it gets. |
| **T4** | **The Risk slider works in one direction.** More Risk never turns a call into a fold, or a river bet into a check. The bot calls exactly when the call is worth it, with a lost chip counted 1 + caution/50 times. Risk 50 is the textbook setting (caution 0, 33% bluffs). The Risk explorer shows the real bot's move at every Risk. | `more_risk_never_folds_a_call`, `more_risk_never_checks_a_bet`, `botDecide_no_bet_off_river`, `ofRisk_caution_antitone`, `ofRisk_bluff_monotone`, `ideal_is_textbook`, `callPays_iff_takes`, `bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it`, `no_loss_always_taken`, `viewOf_toCall_le_pot`, `botDecide_action_shown`, `exploreHandAt_moves`, `exploreHandAt_more_risk_continues`, `risk_monotone`, `botDecide_risk_monotone`, `more_risk_takes_fewer_gambles`, `exploreHand_moves`, `exploreHand_risk_monotone` | One decision at a time: nothing about whole games or how often the bot wins. Flop and preflop odds are estimates. |
| **T5** | **The review grades call or fold correctly.** Best means the better of call and fold; losing fewer big blinds never gets a worse label; calling is Best exactly when you had the odds you needed; the range viewer's numbers add up and match the grade. | `review_worth`, `review_lost`, `review_best_iff`, `review_label_monotone`, `review_call_best_iff_equity`, `review_hands_ne_nil`, `botHands_ne_nil_of_board`, `rangeOf_counts`, `rangeOf_adds_up` | Only your call or fold after the bot's first river bet is graded, not raises or other streets. The model ignores earlier betting. |
| **T6** | **The exact odds count every outcome once.** 990 possible opponent hands on the river and 45,540 outcomes on the turn, each scored by the rules' own showdown. | `enumeration_exact`, `riverOpponentHands_length`, `turnOutcomes_length`, `countsFor_river`, `countsFor_turn` | Flop odds (1,000 sampled deals) and preflop odds (a fixed table). |
| **T7** | **Risk sets the river bluffs exactly.** The river betting set has 324 value hands and the matching number of bluffs (160 at Risk 50, never above 60%). Value hands are the strongest, bluffs the weakest, no hand is both, and the bot bets exactly that set. A bigger bluff share never turns a river bet into a check. | `bluff_frequency`, `value_and_bluffs_apart`, `value_strongest`, `bluffs_weakest`, `bot_bets_its_set`, `botDecide_river_follows_set`, `rankRiverHands_sorted`, `ofRisk_bluff_le_60`, `ideal_river_set`, `more_bluff_never_checks_a_bet` | How often the bot bluffs in played games. |
| **T8** | **The grade ignores the bot's real cards.** Two hands that look the same to you get the same review, and the bot's real hand is always among the hands the review counts. | `no_hindsight`, `bot_hand_in_review` | A right decision can still lose chips. |
| **T9** | **Every hand ends,** within 200 moves. | `every_hand_ends` | How many hands a game lasts, or how long each move takes. |

## Why the rest of "Not covered" is not proved

Some limits cannot be closed by a Lean proof. They are listed here so nobody reads the
table as claiming more than it does.

| Limit | Why it is not proved |
| --- | --- |
| The web page's numbers, the browser and the Node bridge | They are JavaScript. Lean proves things only about Lean code. They are checked by the app's test suite instead. |
| The shuffle being random | It is a seeded generator on purpose, so a game can be replayed. "Random" is not a property a fixed rule has. |
| Whole games: how often the bot wins or bluffs in play | These are statistics over luck, not facts that are true or false. |
| Flop and preflop odds are estimates | Exact flop odds need about 1.2 million showdowns per decision, about 25 times the turn's count, which already takes 0.4–0.8 s. That is too slow to play, so it is a speed choice. |
| The review grades only river call/fold and ignores earlier betting | That is the scope of the review, not a missing proof. Grading more would be a new feature. |
| A right decision can still lose chips | That is true of poker. |
| How many hands a game lasts | There is no bound to prove: if each player folds the small blind in turn, the chips go back and forth forever. |

## What these rely on

- **Lean 4.35.0** checks every proof, using only the three standard axioms (`propext`,
  `Quot.sound`, `Classical.choice`). No `sorry` and no `native_decide`.
- **Definitions a person must read.** A theorem means only what its definitions mean:
  the rules in `engine/Poker/Spec/` (`Legal`, `State.total`, `FairDeck`, the hand ranking),
  `Reachable`, `RunsTo`, `Street.boardCards`, the Risk definitions and the review model.
  The README lists all of them under "What we trust".
- **Trusted data, not proved:** the preflop table (`data/preflop.json`) and the flop odds.

## How to check it yourself

```sh
checks/audit.sh   # builds everything, then fails on any sorry, extra axiom or banned shortcut
```

`lake comparator` and `lake check` (Linux only) confirm each proof matches the agreed
statement in `engine/Checks/Challenge.lean`; GitHub CI runs them on every push.
