# Summary: B04: Harville (1973), "Assigning Probabilities to the Outcomes of Multi-Entry Competitions", and the Independent Chip Model (ICM)

**Source:** D. A. Harville. "Assigning Probabilities to the Outcomes of Multi-Entry Competitions." JASA 68(342), 1973, pp. 312-316. https://doi.org/10.1080/01621459.1973.10482425. Also Diaconis, Ethier. "Gambler's Ruin and the ICM." https://arxiv.org/abs/2011.07610


TL;DR: Harville's 1973 JASA paper (peer-reviewed; paywalled; I saw only Crossref metadata, no abstract) is the usual citation for the rule "the chance you finish k-th is your share of what is left after the players above you are removed". Poker players call this the Independent Chip Model (ICM). Diaconis and Ethier (open arXiv preprint) say the poker ICM came from Mason Malmuth's 1986 article. The formula itself I verified from Gilbert (2009) and Diaconis-Ethier, not from Harville's paper.

- ICM turns chip stacks into expected prize money. It uses only rational arithmetic (fractions of chips), so it is **exactly computable in `Rat`**.
- The chance of finishing 1st equals your chip share. So with a **winner-takes-all** payout, money value is linear in chips, and a money-maximizing bot should be risk-neutral. Our heads-up MVP is this case.
- ICM makes money value non-linear only with **3+ players and a payout for 2nd place or lower**. Then risk aversion is justified (see B05).
- ICM is an approximation: Diaconis-Ethier show it can be "inadequate" against exact gambler's-ruin probabilities; Kim (2025) finds it underrates big stacks (abstracts only).
- Clean theorems: ICM finish probabilities sum to 1; ICM prize values sum to the prize pool (no money created); winner-takes-all ICM = chip share times prize.

Verdict: maybe. Only needed if the 3-6 player mode has a multi-place payout; then it is cheap, exact and gives a conservation theorem that matches our "no chips created" story.


Full extraction: [notes.md](notes.md).
