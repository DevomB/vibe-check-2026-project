# Papers

The full texts behind the source notes. Each row links to a free full text that
a research agent opened on 2026-10-31.

**Why the PDFs are not committed.** This repo is public, and most of these
papers are under publisher copyright (AAAI, IJCAI, NeurIPS, ACM, Science) or
the default arXiv license. Both let anyone read the paper, but neither lets us
publish copies. So the repo keeps the links, and one command downloads local copies:

```sh
sh docs/research/fetch_papers.sh      # saves PDFs to docs/research/papers/ (git-ignored)
```

Papers with no free full text are listed at the end with their DOI.

| Source | Paper | Free full text |
|---|---|---|
| A01 | Hoehn, Southey, Holte, Bulitko. Effective Short-Term Opponent Exploitation in Simplified Poker. AAAI 2005 | https://cdn.aaai.org/AAAI/2005/AAAI05-123.pdf |
| A02 | Southey et al. Bayes' Bluff: Opponent Modelling in Poker. UAI 2005 | https://arxiv.org/pdf/1207.1411 |
| A03 | C. Ferguson, T. Ferguson. On the Borel and von Neumann Poker Models | https://www.math.ucla.edu/~tom/papers/poker1.pdf |
| A04 | Zinkevich, Johanson, Bowling, Piccione. Regret Minimization in Games with Incomplete Information. NeurIPS 2007 | https://proceedings.neurips.cc/paper_files/paper/2007/file/08d98638c6fcd194a4b1e6992063e944-Paper.pdf |
| A04 | Tammelin. Solving Large Imperfect Information Games Using CFR+. 2014 | https://arxiv.org/pdf/1407.5042 |
| A04 | Brown, Sandholm. Solving Imperfect-Information Games via Discounted Regret Minimization. AAAI 2019 | https://arxiv.org/pdf/1809.04040 |
| A05 | Ganzfried, Sandholm. Safe Opponent Exploitation. ACM TEAC 2015 | https://www.cs.cmu.edu/~sandholm/safeExploitation.teac15.pdf |
| A05 | Jeary, Turrini. Safe Opponent Exploitation for Epsilon Equilibrium Strategies. 2023 | https://arxiv.org/pdf/2307.12338 |
| A06 | Johanson, Waugh, Bowling, Zinkevich. Accelerating Best Response Calculation in Large Extensive Games. IJCAI 2011 | https://www.ijcai.org/Proceedings/11/Papers/054.pdf |
| A07 | Moravčík et al. DeepStack. 2017 | https://arxiv.org/pdf/1701.01724 |
| A07 | Brown, Sandholm. Safe and Nested Subgame Solving for Imperfect-Information Games. 2017 | https://arxiv.org/pdf/1705.02955 |
| A07 | Brown et al. ReBeL: Combining Deep Reinforcement Learning and Search for Imperfect-Information Games. 2020 | https://arxiv.org/pdf/2007.13544 |
| A07 | Schmid et al. Student of Games. 2021 | https://arxiv.org/pdf/2112.03178 |
| B01 | Kimball. Precautionary Saving in the Small and in the Large. NBER w2848 (open restatement of Pratt's setting) | https://www.nber.org/papers/w2848.pdf |
| B04 | Diaconis, Ethier. Gambler's Ruin and the ICM. 2020 | https://arxiv.org/pdf/2011.07610v3 |
| B05 | Gilbert. The Independent Chip Model and Risk Aversion. 2009 | https://arxiv.org/pdf/0911.3100v1 |
| B06 | Rockafellar, Uryasev. Optimization of Conditional Value-at-Risk. J. Risk 2000 (authors' copy) | https://sites.math.washington.edu/~rtr/papers/rtr179-CVaR1.pdf |
| B07 | Davis, Waugh, Bowling. Solving Large Extensive-Form Games with Strategy Constraints. AAAI 2019 | https://arxiv.org/pdf/1809.07893v2 |
| C02 | SampCert paper. 2024 | https://arxiv.org/pdf/2412.01671 |
| C03 | Le Roux. Acyclicity and Finite Linear Extendability: a Formal and Constructive Equivalence. 2007 | https://arxiv.org/pdf/0705.3316 |
| C03 | Le Roux, Martin-Dorel, Smaus. EPTCS 256. 2017 | https://arxiv.org/pdf/1709.02096 |
| C04 | Ramos, Soria. Lean 4 Nash analysis of the Pokémon card game. 2026 | https://arxiv.org/pdf/2607.08692 |
| C08 | Burch, Moravčík, Schmid. Revisiting CFR+ and Alternating Updates. JAIR 2019 | https://arxiv.org/pdf/1810.11542 |
| D07 | Ullrich, de Moura. Counting Immutable Beans. IFL 2019 | https://arxiv.org/pdf/1908.05647 |
| E03 | Burch et al. AIVAT: A New Variance Reduction Technique for Agent Evaluation in Imperfect Information Games. AAAI 2018 | https://arxiv.org/pdf/1612.06915 |
| E07 | Ignatiev, Narodytska, Marques-Silva. Abduction-Based Explanations for Machine Learning Models. AAAI 2019 | https://arxiv.org/pdf/1811.10656 |
| E08 | Jacovi, Goldberg. Towards Faithfully Interpretable NLP Systems. ACL 2020 | https://arxiv.org/pdf/2004.03685 |
| E09 | Zinkevich et al. Optimal Unbiased Estimators for Evaluating Agent Performance. AAAI 2006 | https://cdn.aaai.org/AAAI/2006/AAAI06-092.pdf |
| E10 | White, Bowling. Learning a Value Analysis Tool for Agent Evaluation (MIVAT). IJCAI 2009 | https://www.ijcai.org/Proceedings/09/Papers/326.pdf |

Titles are copied from each source's notes. If a title here differs from the
notes, the notes are right.

## No free full text (links only)

- B01 Pratt, Risk Aversion in the Small and in the Large, Econometrica 1964: https://doi.org/10.2307/1913738
- B04 Harville, Assigning Probabilities to the Outcomes of Multi-Entry Competitions, JASA 1973: https://doi.org/10.1080/01621459.1973.10482425
- E04 Billings, Kan, DIVAT (University of Alberta tech report): https://doi.org/10.7939/R3PC2TC4D
- E06 Baron, Hershey, Outcome Bias in Decision Evaluation, JPSP 1988: https://doi.org/10.1037/0022-3514.54.4.569
- Bowling et al., Heads-up limit hold'em poker is solved, Science 2015: https://doi.org/10.1126/science.1259433

## Formal developments (open source code, not papers)

These are licensed proof libraries. They can be browsed online, and their
licenses would allow copying them, but we have no need to.

- C01 Isabelle AFP, Fisher-Yates shuffle (BSD): https://www.isa-afp.org/entries/Fisher_Yates.html
- B03 Isabelle AFP, Von Neumann-Morgenstern Utility Theorem (LGPL): https://www.isa-afp.org/entries/Neumann_Morgenstern_Utility.html
- C05 Isabelle AFP, Nash Equilibrium: https://www.isa-afp.org/entries/Nash_Equilibrium.html
- C08 Isabelle AFP, Alpha-Beta Pruning: https://www.isa-afp.org/entries/Alpha_Beta_Pruning.html
