# Poker spec

Game: heads-up (two players) no-limit Texas Hold'em. One human, one bot.

This file says, in plain English, what "correct" means. The Lean files in
`engine/Poker/Spec/` say the same things in Lean. If the two disagree, this file is the
intent and the Lean is the bug. Theorem numbers (T1, T2, ...) follow `MVP.txt`. The Lean
names are the ones in `engine/Checks/Challenge.lean`, the statements the team agreed on.

## Proof targets

T1 to T9 are proved on `main`. Each is listed with its Lean theorems. The statements are in
`engine/Checks/Challenge.lean`; the proofs are in `engine/Engine/Proofs/`. The README's
"What is proved" table also lists the app and panel theorems.

- **T1 chips are never created or destroyed** (MVP name `chips_conserved`; Lean
  `step_keeps_chips`, `startHand_keeps_chips`, `chips_always_1000`). Every move, and every payout, keeps the total chips on the
  table the same: 1,000 chips in total. Any part of a bet the other player cannot match
  is given back. So at showdown both players have put in the same amount, and the pot is
  even. The pot goes entirely to the winner, or is split in half on a tie. If a split ever
  left an odd chip, it would go to the big blind (this cannot happen with the refund rule,
  but it is the agreed rule from `MVP.txt`). In Lean: an accepted move and a new deal keep
  the total, and every game the engine can reach (`Game.Reachable`) holds 1,000 chips.
- **T1b the right player wins the pot** (Lean `showdown_pays_better_hand`,
  `fold_pays_other_player`, `fold_records_other_player`). T1 alone allows paying the pot to
  the wrong player. For a hand dealt from two stacks above 0 and played with any accepted
  moves: at a showdown, the result is the spec's `showdown` on the real cards and board, the
  better hand ends with more chips than it started with and the other with fewer, and a tie
  leaves both where they started. A fold ends the hand with the player who did not fold as
  the winner; that player ends with more chips and the folder with fewer.
- **T2 no card is dealt twice** (MVP `no_duplicate_cards`; Lean `shuffle_same_cards`,
  `shuffle_fair`, `no_card_dealt_twice`). A shuffled deck holds the same 52 cards as a new
  deck: no card missing, no card twice. In every reachable game, the dealt cards are all
  different.
- **T2b the board matches the street** (Lean `board_matches_street`, `showdown_has_five_cards`).
  While a hand is played, the board has 0 cards before the flop, 3 on the flop, 4 on the
  turn and 5 on the river (`Street.boardCards`), and a hand only reaches a showdown with all
  5 board cards.
- **T3 only legal moves** (MVP `legal_only`; Lean `accepted_move_is_legal`,
  `illegal_move_rejected`, `legal_move_accepted`, `player_to_act_may_act`, `botDecide_legal`).
  `legal_move_accepted` is the other half: every legal move in a hand that is not over is
  accepted, so an engine that rejects everything does not pass T3. The game rejects
  any illegal move and leaves the game unchanged. The
  bot only ever picks a legal move. Only a player with chips remaining who has not bet
  more than the other player can act (`State.MayAct`). The rules:
  - *Check*: only when there is nothing to call.
  - *Call*: only when there is something to call. If you cannot cover it, you go all-in
    for less.
  - *Fold*: always allowed. (Folding when checking is free is pointless, but not illegal.)
  - *Raise to N*: both players must have chips remaining; N must exceed both current bets,
    you must have the chips,
    and the raise must be at least as big as the last raise and the big blind. The one exception is going
    all-in, which may be smaller.
- **T4 more caution never turns a fold into a call** (MVP `risk_monotone`; Lean `risk_monotone`,
  `botDecide_risk_monotone`, `more_risk_takes_fewer_gambles`). These are stated over the bot's
  internal caution number, which the spec files call `risk`. For one decision (the same
  state, cards, counts and Bluff), if the bot calls or raises at some caution, it also calls or
  raises at every lower caution. With it: `callPays_iff_takes`, `bot_calls_only_when_worth_it`,
  `bot_folds_only_when_not_worth_it` and `no_loss_always_taken` say the bot calls exactly
  when the call, with a lost chip counted (1 + caution/50) times, is worth it. The Risk the
  player sets runs the other way (higher means more risk-seeking) and is mapped to caution by
  `Sliders.ofRisk`. For the player's number the statement is `more_risk_never_folds_a_call`:
  facing a bet, if the bot calls or raises at some Risk, it does so at every higher Risk.
- **T5 the review's labels are sound** (MVP `review_sound`; Lean `review_worth`,
  `review_lost`, `review_best_iff`, `review_label_monotone`, `review_call_best_iff_equity`).
  For a graded river call or fold, Best means the choice was worth at least as much as the
  other one, averaged over the bot's possible hands. A decision that lost fewer big blinds
  never gets a worse label.
- **T6 the exact counts see every outcome once** (MVP `enumeration_exact`; Lean
  `enumeration_exact`, `riverOpponentHands_length`, `turnOutcomes_length`,
  `countsFor_river`, `countsFor_turn`). On the river, each of the 990 opponent hands; on the
  turn, each of the 45,540 (river card, opponent hand) pairs.
- **T7 the Bluff count** (MVP `bluff_frequency`; Lean `bluff_frequency`,
  `value_and_bluffs_apart`, `bot_bets_its_set`). On any river board, the bot's betting set
  has 324 value hands, and the number of bluffs nearest to 324 x b / (100 - b), where b is the
  bluff share the player's Risk maps to (`Sliders.ofRisk`; `ofRisk_bluff_le_60` keeps it at most
  60). This is a count in a set of hands, not how often the bot bluffs in play.
- **T8 no hindsight** (MVP `no_hindsight`; Lean `no_hindsight`, `bot_hand_in_review`). Two
  hands that look the same to the human get the same review, whatever cards the bot really
  holds. The bot's real hand is always one of the hands the review counts.
- **T9 `every_hand_ends`** (completed stretch). Every run of accepted moves in one reachable
  hand has at most 200 moves. This does not bound the length of an entire match.
- **T10 `evaluator_equals_spec`** (stretch, Tier 3). At showdown, the winner is the player with the better
  five-card hand. "Better" is defined by a short, obviously correct reference ranking (best
  of the 21 five-card hands). The fast evaluator used in the game must agree with it on
  every valid deal: two cards per player, five on the board, and no duplicates (`ValidDeal`).
  Kicker comparisons use only each player's best five cards.
  - **There is no separate fast evaluator.** The game scores every hand with the spec's own
    `bestScore` (`engine/Poker/Spec/HandRank.lean`): at showdown, in the equity counts and
    in the river betting set. So the game already uses the reference ranking, and T10 has
    nothing to compare. MVP section 8 still lists T10; whether to keep it is the team's call.

## What we do NOT prove

- That the bot plays *well*. That is not a property we can state and prove here.
- That the shuffle is random. We only prove it is a valid deck.
- That the GUI draws things correctly.

## Decided

These follow `MVP.txt`, which is the team's agreed rule set.

- Folding is allowed whenever it is the player's turn to act (`State.MayAct`).
- Blinds are 5/10 for the whole game. Each player starts with 500 chips (1,000 in total).
- In the initial example, player 0 is the button, posts the small blind and acts first
  before the flop; player 1 is the big blind. The button rotates between hands.
- An odd chip on a split pot goes to the big blind.
- Heads-up, no raise is available once the opponent is all-in. A short call pays only
  the caller's remaining stack. A raise never retracts chips already committed.

## Where things are

- `engine/Poker/Spec/Basics.lean`: cards, the deck, chips, legal moves. Written.
- `engine/Poker/Spec/HandRank.lean`: the reference hand ranking and showdown. Written.
- `engine/Engine/Deck.lean`: seeded shuffle and card formatting.
- `engine/Engine/Hand.lean`: hand/game transitions, legality checks, refunds and payouts.
- `engine/Engine/Tests.lean`: scripted checks and 300 simulated random games. These are
  runnable checks, not universal proofs of T1-T3.
- `engine/Engine/HandRankTests.lean`: known showdowns, kicker comparisons and random-deal checks.
- `engine/Engine/Proofs.lean`: proofs about which player may receive the turn.
- `engine/Engine/Equity.lean`, `Slider.lean`, `River.lean` and `Review.lean`: the win
  counts, the slider bot, the river betting set and the river review.
- `engine/Engine/Session.lean`: the game loop the app runs. `engine/Engine/Protocol.lean`:
  the JSON messages. `engine/Main.lean` only reads and writes lines.
- `engine/Engine/Explain.lean`: the Risk explorer (`exploreHand`) and the range viewer
  (`rangeOf`) shown in the review.
- `engine/Engine/Proofs/`: the proofs of T1 to T9, and the definitions they rely on
  (`Reachable.lean`, `RiskSpec.lean`, `BotSpec.lean`, `EquitySpec.lean`, `BluffSpec.lean`,
  `ReviewSpec.lean`, `EndsSpec.lean`).
- `engine/Checks/Challenge.lean` and `engine/comparator.json`: the agreed statements, which
  Comparator checks against the proofs.

## What is proven so far

- **Every theorem in `engine/comparator.json`**: T1 to T9 with the Lean names above, plus
  the app (session) and review-panel theorems. CI checks them with the axiom audit,
  Comparator and `lake check`; the README's evidence line names the green run. Only
  `propext`, `Classical.choice` and `Quot.sound` are used.
- `no_raise_against_all_in`, `all_in_player_cannot_act`, `player_ahead_cannot_act`,
  `raise_at_least_big_blind` (`engine/Poker/Spec/Basics.lean`): facts about the rules themselves.
- `step_turn_ok` and `startHand_turn_ok` (`engine/Engine/Proofs.lean`): after a new hand
  or an accepted move, either the hand is over or the player to act has chips and is not
  ahead in street contributions.

## Integration coverage and remaining proof work

- The session now has `bot_move_accepted`, `handle_keeps_reachable`, `handle_error_unchanged`,
  `viewOf_toCall_le_pot`, `app_game_reachable` and `respond_keeps_session_unless_accepted`.
  Rejection covers valid Peek flags and build identities. The unused fallback is removed.
- `exploreHand_moves` and `exploreHand_risk_monotone` (the internal caution sweep),
  `exploreHandAt_moves` and `exploreHandAt_more_risk_continues` (the player's Risk sweep the
  app shows), `rangeOf_adds_up` and `rangeOf_counts` are registered. Faithful recording of the bot's original inputs remains tested, not proved.
- That `legalOptions` (the moves and raise bounds the human is offered) matches `Legal`.
- T9 is proved and registered. T10 remains optional if a separate fast evaluator is added.
- The JSON layer (`Engine/Protocol.lean`) is tested, not proved.
