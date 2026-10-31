le# Poker spec (draft)

Game: heads-up (two players) no-limit Texas Hold'em. One human, one bot.

This file says, in plain English, what "correct" means. `Spec/Basics.lean` says the same
things in Lean. If the two disagree, this file is the intent and the Lean is the bug.

## What we prove

1. **Fair deck.** A shuffled deck holds the same 52 cards as a new deck: no card missing,
   no card twice. The bot never sees the human's cards or the cards still in the deck.
2. **Legal moves only.** The game accepts a move only if the rules allow it, and the bot
   only ever picks an allowed move. The rules:
   - *Whose turn*: a player with no chips left (all-in) never gets the turn, and neither
     does a player who has already bet more than the other player. In those states no
     move at all is legal, not even fold.
   - *Check*: only when there is nothing to call.
   - *Call*: only when there is something to call. If you cannot cover it, you go all-in
     for less.
   - *Fold*: always allowed. (Folding when checking is free is pointless, but not illegal.)
   - *Raise to N*: N must be more than the other player's bet, you must have the chips,
     and the raise must be at least as big as the last raise, and never less than the big
     blind. The one exception is going all-in, which may be smaller.
   - *No raising an all-in player*: if the other player has no chips left, you may only
     call or fold. With two players, this also means a short all-in (an all-in smaller
     than a full raise) never reopens the betting: the player who went all-in has nothing
     left, so the other player cannot raise again.
3. **Chips are conserved.** Every move, and every payout, keeps the total chips on the
   table the same. Any part of a bet the other player cannot match is given back. So at
   showdown both players have put in the same amount, and the pot is always even. The pot
   goes entirely to the winner, or is split exactly in half on a tie.
4. **Correct winner.** At showdown, the winner is the player with the better five-card
   hand. "Better" is defined by a short, obviously correct reference ranking. The fast
   code used in the game must agree with it on every input. This is only asked of real
   deals: two cards each, five on the board, and no card twice (`ValidDeal`). When two
   hands are the same kind, the next highest cards (kickers) decide, and cards outside
   each player's best five never count.

## What we do NOT prove

- That the bot plays *well*. That is not a property we can state and prove here.
- That the shuffle is random. We only prove it is a valid deck.
- That the GUI draws things correctly.

## Decided

- Folding is always allowed.
- No odd chip: unmatched bets are refunded, so the pot is always even.
- Blinds are 5/10 and each player starts with 500 chips (1,000 in total), as in `MVP.txt`.
- You cannot raise a player who is all-in. This also covers the short all-in rule.
- The button moves to the other player every hand.

## What is proven so far

- `no_raise_against_all_in`, `all_in_player_cannot_act`, `player_ahead_cannot_act`,
  `raise_at_least_big_blind` (`Spec/Basics.lean`): facts about the rules themselves.
- `step_turn_ok` and `startHand_turn_ok` (`Engine/Proofs.lean`): the engine never gives the
  turn to a player who may not act. After a new hand is dealt, and after every accepted
  move, either the hand is over or the player to act has chips and is not ahead.

## Tested, not yet proven

- Chips add up to 1,000 after every move in 300 random games (`Engine/Tests.lean`).
- 33 showdowns with known answers, mostly kickers, plus two properties on random deals
  (`Engine/HandRankTests.lean`).

## Still to write

- The statements and proofs of properties 1, 2 (that the engine only accepts legal moves),
  3 and 4.
