# B04: Harville (1973), "Assigning Probabilities to the Outcomes of Multi-Entry Competitions", and the Independent Chip Model (ICM)

## Summary

**Source:** D. A. Harville. "Assigning Probabilities to the Outcomes of Multi-Entry Competitions." JASA 68(342), 1973, pp. 312-316. https://doi.org/10.1080/01621459.1973.10482425. Also Diaconis, Ethier. "Gambler's Ruin and the ICM." https://arxiv.org/abs/2011.07610

TL;DR: Harville's 1973 JASA paper (peer-reviewed; paywalled; I saw only Crossref metadata, no abstract) is the usual citation for the rule "the chance you finish k-th is your share of what is left after the players above you are removed". Poker players call this the Independent Chip Model (ICM). Diaconis and Ethier (open arXiv preprint) say the poker ICM came from Mason Malmuth's 1986 article. The formula itself I verified from Gilbert (2009) and Diaconis-Ethier, not from Harville's paper.

- ICM turns chip stacks into expected prize money. It uses only rational arithmetic (fractions of chips), so it is **exactly computable in `Rat`**.
- The chance of finishing 1st equals your chip share. So with a **winner-takes-all** payout, money value is linear in chips, and a money-maximizing bot should be risk-neutral. Our heads-up MVP is this case.
- ICM makes money value non-linear only with **3+ players and a payout for 2nd place or lower**. Then risk aversion is justified (see B05).
- ICM is an approximation: Diaconis-Ethier show it can be "inadequate" against exact gambler's-ruin probabilities; Kim (2025) finds it underrates big stacks (abstracts only).
- Clean theorems: ICM finish probabilities sum to 1; ICM prize values sum to the prize pool (no money created); winner-takes-all ICM = chip share times prize.

Verdict: maybe. Only needed if the 3-6 player mode has a multi-place payout; then it is cheap, exact and gives a conservation theorem that matches our "no chips created" story.

## Citation

- David A. Harville, "Assigning Probabilities to the Outcomes of Multi-Entry Competitions", *Journal of the American Statistical Association* 68(342), June 1973, pp. 312-316. DOI 10.1080/01621459.1973.10482425. Peer-reviewed.
- Crossref "is-referenced-by-count": 63 (Crossref only; far lower than Google Scholar would show; looked up 2026-10-31).
- Supporting open sources for the formula and the poker history:
  - George T. Gilbert, "The Independent Chip Model and Risk Aversion", arXiv:0911.3100, 2009 (preprint, math.PR). See B05.
  - Persi Diaconis and Stewart N. Ethier, "Gambler's Ruin and the ICM", arXiv:2011.07610 v3, 2021 (preprint, math.PR; journal version **unsure**).
  - Juho Kim, "Empirical Validation of the Independent Chip Model", arXiv:2506.00180, in 2025 IEEE Conference on Games (CoG), pp. 1-4, DOI 10.1109/CoG64752.2025.11114139 (peer-reviewed conference short paper; abstract only read).

## URLs fetched (fetched 2026-10-31)

- https://api.crossref.org/works/10.1080/01621459.1973.10482425 (metadata: title, author, journal, volume, issue, pages, date, count; no abstract)
- https://www.tandfonline.com/doi/abs/10.1080/01621459.1973.10482425 (HTTP 403, not readable)
- https://arxiv.org/pdf/2011.07610v3 (Diaconis-Ethier full text, read as text in a temp folder outside the repo) and its abstract via http://export.arxiv.org/api/query?id_list=2011.07610
- https://arxiv.org/pdf/0911.3100v1 (Gilbert full text; see B05)
- http://export.arxiv.org/api/query?id_list=2506.00180 (Kim abstract)
- http://export.arxiv.org/api/query?id_list=2608.09586 (Li and Huang, "ICM Out!", 2026 preprint, abstract only)

## Claim status

| Claim | Status |
|---|---|
| Harville 1973 gives the "conditional on who is above you, chance proportional to strength" rule for finishing orders | **Unsure as a fact about the paper** (paywalled, no abstract seen). This is how the paper is usually cited; the title fits. |
| The ICM formula: P(order 1..k) = x1 * x2/(1 - x1) * x3/(1 - x1 - x2) * ... (x_i = chip shares) | Stated on paper by Gilbert (2009, Section 3) and Diaconis-Ethier (2021, Section 2.7). Verified from both. |
| Poker ICM "originated in a 1986 article by Mason Malmuth in Poker Player Newspaper" | Stated by Diaconis-Ethier (Section 2.7). Not checked further. |
| "Malmuth-Harville" as the name of the poker model | **Unsure**; I did not find it in a source I opened. |
| Chance of finishing 1st = chip share, when each hand is chip-fair | Proved on paper (Gilbert 2009, Section 2: if expected chip gain is zero each hand, f(x) = x). |
| ICM is "inadequate" vs exact three-player gambler's ruin; a regression fix works well | Shown numerically by Diaconis-Ethier (exact Markov-chain computation for N up to about 300, plus interpolation). |
| ICM underestimates large stacks and overestimates short stacks in real tournaments | Shown empirically, Kim (2025), dataset of "over ten thousand events" (abstract). |
| A policy priced by computed continuation values beats one priced by ICM in a 3-player jam/fold model ($214.33 more prize equity per hand) | Shown empirically / by computation, Li and Huang (2026 preprint, abstract only). |
| Anything here is machine-checked | No. |

## Setting and definitions

- **Tournament (sit-and-go / freezeout):** everyone starts with the same chips; you are out when you have none; play ends when one player has all chips. Prizes are paid by finishing place.
- **Chip EV** vs **money EV:** chip EV is the expected change in your chip count. Money EV is the expected prize money. In a cash game they are the same. In a tournament with prizes for 2nd, 3rd, ..., they differ, because the winner effectively "gives back" chips (Gilbert's phrase, paraphrased).
- **ICM:** with chip shares x1..xn (summing to 1), the chance of the finishing order (player a first, b second, c third, ...) is
  x_a * x_b/(1 - x_a) * x_c/(1 - x_a - x_b) * ...
  A player's **ICM equity** is the sum over all finishing orders of (chance of that order) * (prize for that player's place).
- Diaconis-Ethier's worked example (three players, stacks 169, 301, 817; prizes $10M, $6M, $4M): ICM chop gives ($5.325M, $6.287M, $8.388M); interpolated gambler's ruin gives ($5.270M, $6.293M, $8.437M). The third-largest stack gets about $54K more under ICM.

## Assumptions and limitations

- ICM ignores skill, position, blinds and who acts next (Li and Huang list these omissions in their abstract).
- It is a heuristic: it was not derived from a model of how chips move (Gilbert). Diaconis-Ethier show it differs from gambler's ruin even for 3 players.
- Cost: n! finishing orders. 720 orders for 6 players: fine for exact `Rat`. (Diaconis-Ethier also note it can be "done in your head" for small cases.)

## What is formally verified

Nothing in these sources.

## Code artifacts and licenses

None in the papers I opened.

## Relevance to our project: what ICM means for the Risk slider's story

- **Heads-up, winner takes all (our MVP):** P(win) = chip share, so money EV is linear in chips. A bot that maximizes money is exactly risk-neutral. A risk-averse bot is then a **style, with a measurable cost**: every fold of a +chip-EV gamble loses EV, and the game review can show this loss in big blinds. Pitch line: "Risk costs you EV here; the review shows exactly how much."
- **3-6 players, winner takes all:** still linear (1st-place chance = chip share). Risk aversion is still only a style.
- **3-6 players with a 2nd/3rd prize:** ICM money value is concave enough that fair two-player bets lose money (B05, Gilbert Theorem 1). Here a risk-averse bot is *correct*, not just a style. If we want the slider to have a "this is actually smart" mode, the multi-player mode needs a multi-place payout (e.g. 65/35 or 50/30/20).
- Option: let the bot's utility over chips *be* its ICM equity. That is expected utility with a computable, rational u. But then "more risk-averse" is not a slider; it is fixed by the payout.

## Candidate theorems for us

1. **ICM probabilities form a distribution:** "the chances of all finishing orders add up to 1."
   ```lean
   theorem icm_sum_one (stacks : List ℚ) (hpos : ∀ s ∈ stacks, 0 < s) :
       ((allOrders stacks.length).map (icmProb stacks)).sum = 1
   ```
   4-6 h (induction on the number of players; telescoping).
2. **No money created:** "the ICM values of all players add up to the prize pool."
   ```lean
   theorem icm_conserves (stacks prizes : List ℚ) (h : ...) :
       ((List.range stacks.length).map (icmEquity stacks prizes)).sum = prizes.sum
   ```
   2-3 h given (1).
3. **Winner takes all is linear:** "with one prize, your ICM value is your chip share times the prize."
   ```lean
   theorem icm_wta (stacks : List ℚ) (P : ℚ) (i : Fin stacks.length) :
       icmEquity stacks [P] i = stacks[i] / stacks.sum * P
   ```
   2-3 h. This is the formal reason the heads-up risk slider is "a style with a cost".
4. **Concrete check:** `#guard` the Diaconis-Ethier three-player example rounds to their numbers. 0.5 h.
