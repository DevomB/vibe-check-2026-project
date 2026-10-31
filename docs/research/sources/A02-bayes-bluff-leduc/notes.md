# A02: Bayes' Bluff (Southey et al., UAI 2005): opponent modelling and the rules of Leduc hold'em

## Summary (also in summary.md)

TL;DR: Southey et al. (UAI 2005) model an unknown poker opponent with Bayesian updating and introduce Leduc hold'em, a small poker game used everywhere since. Full text read on arXiv.

What matters for us:
- Leduc rules, as stated: 6-card deck (two suits of three ranks); ante 1 each; round 1 deals one private card each; round 2 shows one board card; at most two bets or raises per round; raise size 2 in round 1 and 4 in round 2; best hand of private plus board card wins.
- Not stated in the paper: rank names, the exact hand ranking, ties, and who acts first in round 2. OpenSpiel's code (Apache-2.0) fills them: ranks J, Q, K; any pair beats any non-pair, otherwise the higher card wins; ties split the pot; the same player acts first in both rounds.
- Three ways to respond to a belief about the opponent: Bayesian best response, MAP response, Thompson sampling. Leduc prior: Dirichlet(2,2,2) at each decision point.
- Their Texas opponent model uses "fraction of optimal bluff frequency" and "fraction of optimal fold frequency". This is our bluff-slider idea.
- Results are empirical only (200-hand matches). There is no safety guarantee and nothing is machine-checked.

Verdict: use. It is the source for Leduc's rules (with the gaps listed) and for a simple opponent model we can run.

## Citation

- Finnegan Southey, Michael Bowling, Bryce Larson, Carmelo Piccione, Neil Burch, Darse Billings, Chris Rayner. "Bayes' Bluff: Opponent Modelling in Poker." Proceedings of the Twenty-First Conference on Uncertainty in Artificial Intelligence (UAI 2005), pp. 550-558 (report number UAI-P-2005-PG-550-558).
- Source type: peer-reviewed conference paper (UAI 2005); arXiv copy posted 2012.
- URLs fetched: https://arxiv.org/abs/1207.1411 (abstract page) and https://arxiv.org/pdf/1207.1411 (full text), both fetched 2026-10-31.
- Citation count: not looked up.

## Claim status

| Claim | Status |
|---|---|
| Leduc hold'em rules (below) | Definition made by the authors in this paper ("a simplified and more tractable game we constructed"). |
| Posterior over opponent strategies can be computed from observed hands, including folded hands | Derived on paper in the paper. |
| An algorithm computes the exact Bayesian best response (BBR) | Proved on paper (the paper argues the tree-walk algorithm computes BBR); the paper itself says exact BBR is impractical for real use. |
| Bayesian responses quickly exploit opponents drawn from the prior | Shown empirically (Leduc: 1000 trials of 200 hands; Texas: 280 trials). |
| Nash strategy for Leduc "computed exactly" | Stated by the authors (method: the introduction mentions linear programming for Nash; not detailed). |
| Anything machine-checked | Nothing. |

## Setting and definitions

Plain words: the paper builds a Bayesian model of an unknown opponent. You start with a guess about how the opponent plays (a prior), update it after each hand you see, and then choose how to play against your updated belief.

General hold'em format used (precise, from section 2):
- Heads-up limit poker: two players, fixed bet and raise amounts.
- Each round: deal cards, then betting. Actions are fold (f), call (c), raise (r).
- A call matches the other player's total in the pot (possibly nothing, that is, a check). A raise matches and then adds a fixed amount.
- Betting alternates until a player folds (hand ends) or calls, as long as the call is not the first action of the round (then the round ends and the hand moves on).
- A cap limits raises (or bets) per round, so the betting is finite.
- Folding when the money in the pot is equal is left out, because calling (checking) dominates it.
- If nobody folds by the end of the last round: showdown. "The player who can make the strongest poker hand with a combination of their private cards and the public board cards wins the pot."

## Leduc hold'em: exact rules as stated in the paper

Quoted facts (short) and plain restatement:
- Deck: "two suits with three cards in each suit". So 6 cards: three ranks, two copies of each.
- Two rounds.
- Round 1: "a single private card is dealt to each player".
- Round 2: "a single board card is revealed".
- "a two-bet maximum" per round.
- Raise amounts: "2 and 4 in the first and second round, respectively".
- "Both players start the first round with 1 already in the pot" (an ante of 1 each).
- Showdown: strongest poker hand made from your private card plus the board card.

What the paper does NOT state:
- The names of the three ranks.
- The hand ranking spelled out. "Strongest poker hand" implies a pair (your card has the same rank as the board card) beats an unpaired hand, and otherwise the higher rank wins. That is my reading, not a quote.
- What happens when both players hold the same rank and neither pairs.
- Who acts first in round 2.

These gaps are filled by OpenSpiel's implementation (a reference implementation, not the paper; Apache License 2.0). URLs fetched 2026-10-31: https://github.com/google-deepmind/open_spiel/blob/master/open_spiel/games/leduc_poker/leduc_poker.h and https://github.com/google-deepmind/open_spiel/blob/master/open_spiel/games/leduc_poker/leduc_poker.cc . OpenSpiel's games list (https://openspiel.readthedocs.io/en/latest/games.html, fetched 2026-10-31) cites this paper as Leduc's reference.
- Ranks: J, Q, K. Card indices "0 J1, 1 J2, 2 Q1, 3 Q2, 4 K1, 5 K2" (rank = index / 2, suit = index % 2).
- Hand ranking (RankHand): every pair beats every non-pair. Among non-pairs, the higher card decides and then the lower card. Suits never matter. In heads-up play your hand is {your card, board card}, and the board card is shared, so a non-pair comparison is decided by your private card.
- Ties (ResolveWinner): equal ranks split the pot equally (the split can be fractional, as a double).
- Who acts first: the `starting_player` (default player 0) acts first in each round. If that player has folded (only possible with more than 2 players), the next non-folded player starts.
- Constants: kFirstRaiseAmount = 2, kSecondRaiseAmount = 4, kMaxRaises = 2 per round, kStartingMoney = 100, kDefaultPlayers = 2, kNumInfoStates = 936 (as named in OpenSpiel; I did not check what this count covers).
- Status: these are the implementation's choices. They are consistent with the paper, but the paper does not fix them.

Texas hold'em as used in the same paper (for reference): 52 cards, four rounds (2 private cards; flop of 3; turn 1; river 1), four-bet maximum, raise amounts 10 in the first two rounds and 20 in the last two, blinds of 5 and 10.

Size facts given: Texas hold'em has "on the order of 10^18 states". (No size figure for Leduc is given in the text I read.)

## Main results and algorithms

Model:
- A strategy gives, at each information set (own cards + public cards + action history), a probability distribution over actions.
- Observations: hands that reach showdown (opponent's cards seen) and hands that end in a fold (opponent's cards not seen). The posterior uses both, summing over the unseen cards for folded hands.

Three ways to respond to the posterior (section 4):
1. Bayesian Best Response (BBR): maximize expected value over all hands and all opponent strategies, weighted by the posterior. The paper gives a tree-walk algorithm; exact BBR is expensive ("an ideal goal rather than a practical" one, in their words, for large priors).
2. MAP response: estimate the single most likely opponent strategy (in practice, the sampled strategy with highest posterior), then best-respond to it.
3. Thompson's response: sample one opponent strategy from the posterior, best-respond to it.

Priors:
- Leduc: independent Dirichlet(2, 2, 2) at every information set; its mode is (1/3, 1/3, 1/3) over fold, call, raise.
- Texas: an expert "informed prior" with 5 parameters per player (10 total), including b = "Fraction of the game-theoretic optimal bluff frequency" and f = "Fraction of the game-theoretic optimal fold frequency". This is exactly our "bluff slider relative to baseline" idea, used here as an opponent model parameter.

Experiments:
- 1000 strategies sampled from the prior at the start of each trial.
- Each trial: 200 hands. 1000 trials for Leduc, 280 for Texas.
- Opponents: sampled from the prior ("Priors"), a Nash strategy ("Opti", computed exactly for Leduc), and "Frequentist" (Vexbot).
- Units: raw pot units (bets 2 and 4 in Leduc).
- Result (empirical): Bayesian players do well against opponents drawn from their prior, between the Opti line (no exploitation) and the Best Response line (perfect exploitation). I did not extract exact numbers from the plots.

## Assumptions and limitations

- Assumes the deck is uniformly shuffled and hands are independent and identically distributed.
- Assumes a static (non-adapting) opponent drawn from the prior. No safety guarantee against an adaptive opponent (contrast A05).
- Results are best when the opponent really comes from the prior.

## What is formally verified

Nothing. The paper is algorithms plus experiments.

## Code artifacts

None linked in the paper text I read. License unknown.

## Relevance to our project

- This is the defining source for Leduc hold'em, our second mini-mode. Rules above are exact, with listed gaps.
- The idea of describing an opponent by "fraction of optimal bluff frequency" and "fraction of optimal fold frequency" is close to our bluff slider and our later opponent fold-rate model.
- Bayesian Dirichlet counting is a simple, executable opponent model we could use for the fold-rate estimate. Combine with A05 to make it safe.

## Candidate theorems for us

1. Leduc deck and deal are well formed.
   Plain English: the deck has 6 cards, two of each rank, and a deal never gives the same physical card twice.
   ```lean
   theorem leduc_deck_card : leducDeck.length = 6 ∧ ∀ r, (leducDeck.filter (·.rank = r)).length = 2
   theorem deal_distinct (d : Deal) (h : d ∈ allDeals) : d.p1 ≠ d.p2 ∧ d.p1 ≠ d.board ∧ d.p2 ≠ d.board
   ```
   About 1-2 hours.
2. Betting cap: no round has more than two bets or raises, and pot contributions are bounded.
   ```lean
   theorem round_raises_le_two (h : History) (hv : Legal h) : raisesInRound h ≤ 2
   theorem pot_le (h : History) (hv : Legal h) : potOf h ≤ 2 + 2*(2+2) + 2*(4+4)  -- check the exact cap
   ```
   About 2-4 hours. (Work out the exact maximum pot yourself; it is not stated in the paper.)
3. Chips conserved in Leduc: the sum of both players' stacks plus the pot never changes.
   About 1-3 hours (same shape as the NLHE engine theorem).
4. Dirichlet fold-rate estimate stays in [0, 1] and moves toward observed frequency.
   ```lean
   theorem foldEst_mem (c : Counts) : 0 ≤ foldEst c ∧ foldEst c ≤ 1
   ```
   About 1 hour.
