# Summary: A02: Bayes' Bluff (Southey et al., UAI 2005): opponent modelling and the rules of Leduc hold'em

**Source:** Southey, Bowling, Larson, Piccione, Burch, Billings, Rayner. "Bayes' Bluff: Opponent Modelling in Poker." UAI 2005. https://arxiv.org/abs/1207.1411. Leduc code: OpenSpiel (Apache-2.0), https://github.com/google-deepmind/open_spiel/blob/master/open_spiel/games/leduc_poker/leduc_poker.cc


TL;DR: Southey et al. (UAI 2005) model an unknown poker opponent with Bayesian updating and introduce Leduc hold'em, a small poker game used everywhere since. Full text read on arXiv.

What matters for us:
- Leduc rules, as stated: 6-card deck (two suits of three ranks); ante 1 each; round 1 deals one private card each; round 2 shows one board card; at most two bets or raises per round; raise size 2 in round 1 and 4 in round 2; best hand of private plus board card wins.
- Not stated in the paper: rank names, the exact hand ranking, ties, and who acts first in round 2. OpenSpiel's code (Apache-2.0) fills them: ranks J, Q, K; any pair beats any non-pair, otherwise the higher card wins; ties split the pot; the same player acts first in both rounds.
- Three ways to respond to a belief about the opponent: Bayesian best response, MAP response, Thompson sampling. Leduc prior: Dirichlet(2,2,2) at each decision point.
- Their Texas opponent model uses "fraction of optimal bluff frequency" and "fraction of optimal fold frequency". This is our bluff-slider idea.
- Results are empirical only (200-hand matches). There is no safety guarantee and nothing is machine-checked.

Verdict: use. It is the source for Leduc's rules (with the gaps listed) and for a simple opponent model we can run.


Full extraction: [notes.md](notes.md).
