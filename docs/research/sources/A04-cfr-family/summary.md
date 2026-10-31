# Summary: A04: Counterfactual regret minimization (CFR) and its variants: CFR (2007), CFR+ (2014), Discounted CFR (2018/2019)

**Source:** Zinkevich, Johanson, Bowling, Piccione. "Regret Minimization in Games with Incomplete Information." NIPS 2007. https://proceedings.neurips.cc/paper/2007/hash/08d98638c6fcd194a4b1e6992063e944-Abstract.html. Tammelin. "Solving Large Imperfect Information Games Using CFR+." arXiv 2014. https://arxiv.org/abs/1407.5042. Brown, Sandholm. Discounted CFR. AAAI 2019. https://arxiv.org/abs/1809.04040


TL;DR: CFR is the standard way to compute near-equilibrium poker strategies. You play the game against yourself many times. At each decision point you keep a running "regret" for each action and play actions in proportion to their positive regret. The average strategy approaches an equilibrium. CFR+ and Discounted CFR are faster versions.

What matters for us:
- Regret matching (eq. 8 of CFR): play action a with probability R+(a) / sum of R+; if no regret is positive, play uniformly. This is short, executable Lean code.
- Guarantees (proved on paper): if both players' average regret is below eps, the average strategy pair is a 2*eps equilibrium (Thm. 2). With regret matching, average regret <= Delta * |I| * sqrt|A| / sqrt T (Thm. 4).
- CFR+: clamp the running regret at 0 each step, update the players in turn, and weight later iterations more (w_T = max(T - d, 0)). More than 10x faster in their tests (empirical; the report gives no proof).
- For us: we do not need CFR at runtime. Kuhn and Leduc are small enough to state equilibria directly and check them exactly (A01, A06). CFR could make the Leduc strategy, and A06's exact check then certifies it. That avoids proving CFR itself.
- Nothing machine-checked found.

Verdict: maybe. Good background, and a possible tool to produce a Leduc strategy that we then check exactly. Proving CFR's convergence is too costly for 34 hours.


Full extraction: [notes.md](notes.md).
