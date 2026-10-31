# B05: Gilbert (2009), "The Independent Chip Model and Risk Aversion"

## Summary

**Source:** G. T. Gilbert. "The Independent Chip Model and Risk Aversion." arXiv preprint, 2009. https://arxiv.org/abs/0911.3100

TL;DR: A short open math paper (arXiv preprint, math.PR, not peer-reviewed as far as I saw). Under ICM (B04), with prizes that do not increase by place and at least one player who will get less than 2nd prize, **any chip-fair bet against one opponent lowers your expected prize money**, and **every player not in the bet gains**. Both can fail for bets among three or more players; the paper gives a numeric counterexample.

- This is the rigorous reason risk aversion is *correct* in multi-player sit-and-gos with multi-place payouts.
- The proof is "split the payout into sub-tournaments, each term is linear or concave in your chip share, then Jensen". It fits Lean well, over exact `Rat`.
- In winner-takes-all, the money value is linear in chips, so there is no ICM risk aversion. Our heads-up MVP is this case.
- "Bystanders gain when two players gamble" is a fun, explainable fact for the GUI, and a possible theorem.

Verdict: use (for the 3-6 player story and as a stretch theorem). Ignore for the heads-up MVP.

## Citation

George T. Gilbert (Texas Christian University), "The Independent Chip Model and Risk Aversion", arXiv:0911.3100 v1, 16 November 2009. Preprint (category math.PR). No journal reference on arXiv; peer-reviewed version **unsure**. Citation count not looked up.

## URLs fetched (fetched 2026-10-31)

- http://export.arxiv.org/api/query?id_list=0911.3100 (abstract and metadata)
- https://arxiv.org/pdf/0911.3100v1 (full text, read as text in a temp folder outside the repo)

## Claim status

| Claim | Status |
|---|---|
| Theorem 1: a fair bet with exactly one other player lowers your ICM expected prize | Proved on paper |
| Theorem 2: players not in a fair two-player bet gain ICM expected prize | Proved on paper |
| Both fail in general for fair bets among 3+ players | Proved on paper by counterexample (numbers in a table) |
| Corollary 1: if several players each bet a fixed amount and the pot goes to one of them with chance proportional to their bet, every uninvolved player gains; in particular merging stacks helps everyone else | Proved on paper (by chaining two-player fair bets) |
| If each hand is chip-fair, P(finish 1st) = chip share | Proved on paper (one-line argument in Section 2) |
| Gilbert's own data "at first glance" suggest ICM is reasonable in aggregate | Opinion / informal empirical remark |
| Machine-checked | No |

## Setting and definitions

- **ICM** as in B04: P(finishing order) = product of "your share of the chips that remain".
- **Fair bet** (Gilbert's definition): a random chip transfer W, not always 0, with **expected value 0 in chips**, taking finitely many values, measured as a fraction of all chips. It covers the whole rest of the hand.
- **Prize assumption:** prize for place n is at least prize for place n + 1, and at least one player still in will get less than the 2nd-place prize (so the payout is not "everyone left gets the same").

## Main results, precisely

- **Theorem 1.** Under the prize assumption and ICM, any fair bet in which only one other player can gain or lose chips in the hand lowers the player's expected prize money (strictly).
- **Theorem 2.** Under the same assumptions, the expected prize money of any player not involved in a fair bet between two players increases.
- **Proof method (Theorem 1).** Write prizes m1 >= m2 >= ... >= mn as a sum of sub-tournaments: the first pays m1 - m2 to 1st only, the second pays m2 - m3 to each of the top 2, ..., the last pays mn to each of the top n. In the winner-takes-all part, your value is (m1 - m2) * E[x - w] = (m1 - m2) * x, unchanged by a fair bet. In parts where everyone gets the same, nothing changes. Every other part pays 1 to each of the top k (k >= 2) and 0 below; there your ICM value is a sum of terms that are concave in your share, so a fair bet lowers it (Jensen). A key lemma (Lemma 1) gives a closed form that makes the concavity visible.
- **Counterexample for 3+ players** (my reading of a table whose columns were scrambled in the text extraction; the sums check out to 3 prize units before and after): a satellite paying 1 unit to each of the top 3. Stacks A = 140, B = 10, C = 10, D = 50. The bet: with probability 1/2 A wins 16 chips (B and C lose 8 each), else A loses 16 (B and C win 8 each). ICM values before -> after: A 0.9952 -> 0.9914, B 0.5256 -> 0.5316, C 0.5256 -> 0.5316, D 0.9536 -> 0.9455. So B and C *gain* from a fair three-way bet (Theorem 1 fails), and bystander D *loses* (Theorem 2 fails).

## Assumptions and limitations

- Everything is "under ICM", which is itself an approximation (B04: Diaconis-Ethier, Kim).
- Bets are fair in chips. Real poker spots have positive or negative chip EV; the theorem then says ICM adds a penalty on top.
- The paper assumes finite-valued bets (fits our finite lotteries).

## What is formally verified

Nothing. Paper proof only, about 10 pages.

## Code artifacts and licenses

None.

## Relevance to our project

- Gives the honest story for the Risk slider: in heads-up winner-takes-all, risk aversion is a costly style; in multi-way pay-2+ places, some risk aversion is correct, and ICM says how much.
- The "sub-tournament" split and "concave terms + Jensen" proof is the same pattern as B01/B02, so one Jensen lemma serves both.
- GUI idea: show "your money value" next to "your chips", and highlight when a call is +chips but -money.

## Candidate theorems for us

1. **Winner-takes-all part is neutral:** "with one prize, a chip-fair bet does not change your money value." Follows from B04 candidate 3 plus linearity. 1-2 h after B04.
2. **Gilbert Theorem 1, three players, two paid places (smallest real case):** "in a 3-player game paying 1st and 2nd, a chip-fair bet with one opponent lowers your expected prize."
   ```lean
   theorem icm3_fair_bet_hurts (x y z : ℚ) (hx : 0 < x) (hy : 0 < y) (hz : 0 < z)
       (hsum : x + y + z = 1) (m1 m2 : ℚ) (hm : m2 ≤ m1) (hm2 : 0 < m2)
       (L : Lottery) (hfair : L.expect id = 0) (hnontriv : L.nonzero)
       (hrange : ∀ d ∈ L.outcomes, 0 < x + d ∧ 0 < y - d) :
       L.expect (fun d => icmEquity3 (x + d) (y - d) z m1 m2) < icmEquity3 x y z m1 m2
   ```
   6-10 h (show the function is strictly concave in d on the allowed range, then strict Jensen; or a direct algebraic proof for 3 players).
3. **General n-player Theorem 1 or 2:** 20+ h. Not for this hackathon.
4. **Counterexample check:** `#eval`/`#guard` the 4-player table above with exact `Rat` ICM. 1 h. Good as a "spec rejects bad claims" example: `¬ (∀ fair bets among 3 players, each player's value goes down)`.
