# Poker spec (draft)

Game: heads-up (two players) no-limit Texas Hold'em. One human, one bot.

This file says, in plain English, what "correct" means. The Lean files in
`engine/Poker/Spec/` say the same things in Lean. If the two disagree, this file is the
intent and the Lean is the bug. Theorem names and numbers (T1, T2, ...) follow `MVP.txt`.

## Proof targets (completion requires actual proofs and final checks)

- **T1 `chips_conserved`.** Every move, and every payout, keeps the total chips on the
  table the same: 1,000 chips in total. Any part of a bet the other player cannot match
  is given back. So at showdown both players have put in the same amount, and the pot is
  even. The pot goes entirely to the winner, or is split in half on a tie. If a split ever
  left an odd chip, it would go to the big blind (this cannot happen with the refund rule,
  but it is the agreed rule from `MVP.txt`).
- **T2 `no_duplicate_cards`.** A shuffled deck holds the same 52 cards as a new deck: no
  card missing, no card twice.
- **T3 `legal_only`.** The game rejects any illegal move and leaves the game unchanged. The
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
- **T10 `evaluator_equals_spec`** (stretch, Tier 3). At showdown, the winner is the player with the better
  five-card hand. "Better" is defined by a short, obviously correct reference ranking (best
  of the 21 five-card hands). The fast evaluator used in the game must agree with it on
  every valid deal: two cards per player, five on the board, and no duplicates (`ValidDeal`).
  Kicker comparisons use only each player's best five cards.
- **T9 `every_hand_ends`** (stretch). Every hand finishes in a bounded number of moves.

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

## What is proven so far

- `no_raise_against_all_in`, `all_in_player_cannot_act`, `player_ahead_cannot_act`,
  `raise_at_least_big_blind` (`engine/Poker/Spec/Basics.lean`): facts about the rules themselves.
- `step_turn_ok` and `startHand_turn_ok` (`engine/Engine/Proofs.lean`): after a new hand
  or an accepted move, either the hand is over or the player to act has chips and is not
  ahead in street contributions. These prove the turn condition, not all of T1-T3.

## Still to write

- JSON command handling and the Node-to-Lean bridge; `Main.lean` is still a placeholder.
- The Risk/Bluff bot and river review, including T4/T5 and the Tier 2 targets in `MVP.txt`.
- Runtime validation of incoming card sets before hand ranking. `State` describes a betting
  turn; the engine's `Hand.ended` controls the finished-hand lifecycle.
- The Lean statements of T1, T2, T3 and T10, so each can be proven.
