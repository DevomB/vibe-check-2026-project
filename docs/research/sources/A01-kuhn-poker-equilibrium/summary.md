# Summary: A01: Kuhn poker, its equilibrium family and game value


TL;DR: Kuhn poker (3 cards, ante 1, bet 1, one round) has a known exact solution. Two peer-reviewed papers (Hoehn et al., AAAI 2005; Ganzfried and Sandholm, ACM TEAC 2015) and Wikipedia agree on it. Kuhn's 1950 original was not opened.

What matters for us:
- P2 has one equilibrium strategy: facing a bet, J folds, Q calls 1/3, K calls; facing a check, J bets 1/3, Q checks, K bets.
- P1 has a family with one parameter a in [0, 1]: J bets a/3, Q always checks then calls a/3 + 1/3, K bets a. (Wikipedia writes alpha = a/3 in [0, 1/3].)
- Game value: -1/18 per hand for P1.
- Exploitability = game value minus worst-case payoff. A worst-case opponent can always be a pure strategy, so "exploitability 0" is a finite check over 64 pure opponent strategies with exact rationals. Checking both sides also proves the value, with no LP.
- No machine-checked proof of any of this was found. It is a clear, small novelty target (about 4-8 hours for the value, 6-12 for the whole family).

Verdict: use. It is the core of the "provably unexploitable" mini-mode, and every claim reduces to a finite exact check.


Full extraction: [notes.md](notes.md).
