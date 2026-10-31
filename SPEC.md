le# Poker spec (draft)

Game: heads-up (two players) no-limit Texas Hold'em. One human, one bot.

This file says, in plain English, what "correct" means. `Spec/Basics.lean` says the same
things in Lean. If the two disagree, this file is the intent and the Lean is the bug.

## What we prove

1. **Fair deck.** A shuffled deck holds the same 52 cards as a new deck: no card missing,
   no card twice. The bot never sees the human's cards or the cards still in the deck.
2. **Legal moves only.** The game accepts a move only if the rules allow it, and the bot
   only ever picks an allowed move. The rules:
   - *Check*: only when there is nothing to call.
   - *Call*: only when there is something to call. If you cannot cover it, you go all-in
     for less.
   - *Fold*: always allowed. (Folding when checking is free is pointless, but not illegal.)
   - *Raise to N*: N must be more than the other player's bet, you must have the chips,
     and the raise must be at least as big as the last raise. The one exception is going
     all-in, which may be smaller.
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
   code used in the game must agree with it on every input.

## What we do NOT prove

- That the bot plays *well*. That is not a property we can state and prove here.
- That the shuffle is random. We only prove it is a valid deck.
- That the GUI draws things correctly.

## Decided

- Folding is always allowed.
- No odd chip: unmatched bets are refunded, so the pot is always even.
- Blinds are 5/10 and each player starts with 500 chips (1,000 in total), as in `MVP.txt`.
- You cannot raise a player who is all-in. This also covers the short all-in rule.

## Still to write

- The engine's step function (apply a move to the state) and the payout function.
- The reference hand ranking.
- The statements of properties 3 and 4 about those functions.
