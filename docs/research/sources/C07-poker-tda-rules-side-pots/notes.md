# C07: Poker TDA Rules (2026, Version 1.1) on side pots, odd chips, short all-ins, heads-up; plus real pot-award bugs

## Summary

**Source:** Poker TDA. "2026 Rules, Version 1.1" (21 Sept 2026). https://www.pokertda.com/view-poker-tda-rules/. Bug reports: see notes.

TL;DR: The official tournament rules (Poker TDA, 2026 v1.1, 21 Sept 2026) say little about how side pots are built. They say each side pot is split on its own, the odd chip goes to the first seat left of the button, and a short all-in does not reopen betting for players who already acted. We must write the side-pot construction ourselves, which is exactly where proofs add value. Real sites have paid pots to the wrong player (GGPoker 2022, UltimateBet 2008).
- Rule 23: "Each side pot will be split separately." Rule 21: odd chip to the first seat left of the button (board games, like Hold'em).
- Rule 49-A (no-limit): a short all-in, or several short all-ins together, below a full raise does not reopen betting for players who already acted. Rule 45-A: a raise must be at least the largest prior full bet or raise in the round.
- Rule 36-C: heads-up, the small blind is the button, acts first preflop and last after the flop.
- The TDA text gives no side-pot construction algorithm and no order for awarding pots. Our spec must define both; the theorems below make that spec checkable.
- Non-academic bug reports (labelled) show wrong-winner bugs caused by edge cases (a game-mode flag, a disconnect at the moment of award). These make a good motivation slide.

Verdict: use. It is the rule source for the engine and gives the plain-English statements we should prove.

## Citations and URLs (fetched 2026-10-31)
1. Poker Tournament Directors Association (Poker TDA). "2026 Rules, Version 1.1, Sept 21, 2026". Official rules (non-academic, allowed for game rules).
   - https://www.pokertda.com/view-poker-tda-rules/ (HTML rules; fetched three times with different questions)
   - Downloads page named on that page (not opened): https://www.pokertda.com/poker-tda-rules/
   - The Illustration Addendum and the Recommended Procedures (e.g. RP-21 "Spreading the Pot") are referenced but their text was not on the page. Not read: UNVERIFIED.
2. PokerNews, "Online Poker Pot Awarded to Wrong Player in $1M Gtd. Tournament", 27 June 2022. News (non-academic; real-world bug).
   - https://www.pokernews.com/news/2022/06/online-poker-player-glitch-41509.htm
3. PokerNews, "Tokwiro Releases Statement on UltimateBet Software Glitch Awarding Pot to Wrong Player", 24 Dec 2008. News (non-academic; real-world bug).
   - https://www.pokernews.com/news/2008/12/tokwiro-issues-statement-ultimate-bet-software-glitch-5913.htm
- Poker Mavens forum report of a wrong pot value (https://briggsoft.com/forums/viewtopic.php?p=7743): HTTP 403, UNVERIFIED, not counted.

## Claim status
All TDA items are official rules (normative text), not research claims. The bug items are news reports (non-academic), resting on operator statements.

## Rules (paraphrased, with rule numbers)
- Rule 13: "Cards speak". Spoken claims about a hand do not decide the winner.
- Rule 17: in an all-in showdown, all hands in the main and side pots are tabled and live.
- Rule 18-A: show order if not shown spontaneously: the last aggressor on the final round shows first; if no bet on the final round, the first player to act in that round (first seat left of the button in flop games).
- Rule 21 (odd chips): first break odd chips down to the smallest denomination in play. In board games (Hold'em) with two or more high hands, the odd chip goes to the first seat left of the button. In high-low split, to the high side. The text does not say what happens when there are two or more odd chips among three or more winners. Unsure: we must choose (for example, one chip each in seat order starting left of the button) and state it.
- Rule 23 (side pots): "Each side pot will be split separately." So the odd-chip rule applies pot by pot.
- Rule 34: tournaments use a dead button.
- Rule 36-B: the button can skip empty seats; no player may miss a big blind or post the big blind twice in a row.
- Rule 36-C (heads-up): the small blind is the button; the button is dealt last, acts first preflop and last on later rounds. When play becomes heads-up, the button may be moved so no player posts the big blind twice in a row.
- Rule 45-A (minimum raise): a raise must be at least the largest prior full bet or raise of the current round. A raise of 50% or more of that, but below a full raise, must be made a full minimum raise. Below 50% it is a call, unless "raise" was declared first or the player is all-in.
- Rule 47: chips that are a player's last chips make an all-in bet, whatever the 50% threshold.
- Rule 49-A (no-limit and pot-limit): a short all-in, or several short all-ins that together are less than a full bet or raise, does not reopen betting for players who already acted and are not facing a full bet or raise. If several short all-ins do add up to reopen it, the minimum raise is the last full valid bet or raise of the round.
- Rule 49-B (limit only): 50% of a full bet or raise reopens betting. Not relevant to No-Limit.
- Rule 58: string bets and raises are not allowed (relevant only for live play; our GUI sends one action).

## Real-world bugs (non-academic, labelled)
- GGPoker, 2022 (news): in a $10,300 Super High Roller ($1M guaranteed), queens lost to tens on a K♠ 6♦ K♣ 7♣ 5♣ board. GGPoker said a "conditional bug" made the system treat the hand as a Flip&Go game and "discard one card". GGPoker fixed it and refunded all affected cases.
- UltimateBet, 2008 (news): a heads-up limit hand was paid to Phil Hellmuth although his opponent held trip queens. The opponent disconnected and his hole cards were wiped "at the precise millisecond" of the award. The first fix caused a second flaw that mis-paid 36 other hands.
- Lesson for us: wrong-winner bugs come from rare paths (game-mode flags, missing cards, timing). A proof that "the pot goes to the best eligible hand(s)" for every input covers rare paths that tests miss.

## Precise statements we can prove (my design, opinion)
Setup. A hand ends with: each player i has committed `c i` chips this hand (blinds included); some players folded. Let the "levels" be the distinct values of `c i` over players who did not fold, sorted: L1 < L2 < ... < Lm. Pot k takes from every player (folded or not) `min (c i) Lk − min (c i) L(k−1)` (with L0 = 0). The players eligible for pot k are the non-folded players with `c i ≥ Lk`.
1. Every chip committed goes to exactly one pot: `(pots.map amount).sum = (players.map c).sum`.
2. Every pot has at least one eligible player.
3. A player only wins from pots they are eligible for, and a folded player wins nothing.
4. A player wins at most what they matched: from each opponent j, player i can win at most `min (c i) (c j)`. (All-in for 50 means you can win at most 50 from each caller.)
5. Pot split: in each pot, the winners are exactly the eligible players with the best hand. Each gets `amount / w`; the `amount % w` leftover chips go one each to the winners in seat order starting left of the button (our reading of Rule 21 plus a stated choice).
6. Chip conservation: total chips at the table after the hand = total before (500 × number of players for a sit-and-go; no chip is created or destroyed).
7. Betting: after a short all-in that is not a full raise, a player who already acted and faces no full raise can only call or fold (Rule 49-A). The minimum raise is the last full raise (Rule 45-A).
8. Heads-up: the button posts the small blind and acts first preflop and second after the flop (Rule 36-C).
9. Uncalled excess: if the top level has only one eligible player, that pot is that player's own excess and goes back to them.

## Assumptions and limitations
- TDA rules are for live tournaments. Many rules (verbal declarations, chip motions) do not apply to software.
- The rules do not define the side-pot construction or award order. Our construction is the standard one, but it is our choice and goes in the trusted surface.

## Relevance to our project
- These are the rule sources for the engine's legality checks and the side-pot module.
- The wrong-winner stories give a concrete "why verify" message for non-technical judges.

## Candidate theorems for us
| Plain English | Lean 4 shape (sketch) | Hours |
|---|---|---|
| Pots add up to the chips put in | `theorem pots_sum (c : Fin n → ℕ) (folded : Fin n → Bool) : ((buildPots c folded).map Pot.amount).sum = ∑ i, c i` | 3–6 |
| Each pot has an eligible player (given at least one player did not fold) | `theorem pot_eligible_nonempty (h : ∃ i, folded i = false) : ∀ p ∈ buildPots c folded, p.eligible ≠ []` | 2–4 |
| Payout is a split of the pots; nothing created or lost | `theorem payout_sum : ∑ i, payout c folded hands button i = ∑ i, c i` | 3–6 |
| Folded players win nothing; a player only wins from eligible pots | `theorem folded_wins_zero (h : folded i) : payout ... i = 0` | 1–2 |
| You can win at most what you matched from each opponent | `theorem win_le_matched : payout ... i ≤ ∑ j, min (c i) (c j)` | 3–5 |
| Chip conservation for a whole hand / whole tournament | `theorem hand_conserves (s : TableState) (a : List Action) : totalChips (playHand s a) = totalChips s` | 4–10 (depends on engine structure) |
| Short all-in does not reopen betting | `theorem short_allin_no_reopen : ... → legalActions s p ⊆ [.fold, .call]` | 3–6 |
| Spec rejects bad payouts: giving a side pot to an all-in player who is not eligible violates the spec | `example : ¬ PayoutSpec input badPayout := by decide` | 1 |
