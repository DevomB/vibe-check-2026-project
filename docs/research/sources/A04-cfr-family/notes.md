# A04: Counterfactual regret minimization (CFR) and its variants: CFR (2007), CFR+ (2014), Discounted CFR (2018/2019)

## Summary

**Source:** Zinkevich, Johanson, Bowling, Piccione. "Regret Minimization in Games with Incomplete Information." NIPS 2007. https://proceedings.neurips.cc/paper/2007/hash/08d98638c6fcd194a4b1e6992063e944-Abstract.html. Tammelin. "Solving Large Imperfect Information Games Using CFR+." arXiv 2014. https://arxiv.org/abs/1407.5042. Brown, Sandholm. Discounted CFR. AAAI 2019. https://arxiv.org/abs/1809.04040

TL;DR: CFR is the standard way to compute near-equilibrium poker strategies. You play the game against yourself many times. At each decision point you keep a running "regret" for each action and play actions in proportion to their positive regret. The average strategy approaches an equilibrium. CFR+ and Discounted CFR are faster versions.

What matters for us:
- Regret matching (eq. 8 of CFR): play action a with probability R+(a) / sum of R+; if no regret is positive, play uniformly. This is short, executable Lean code.
- Guarantees (proved on paper): if both players' average regret is below eps, the average strategy pair is a 2*eps equilibrium (Thm. 2). With regret matching, average regret <= Delta * |I| * sqrt|A| / sqrt T (Thm. 4).
- CFR+: clamp the running regret at 0 each step, update the players in turn, and weight later iterations more (w_T = max(T - d, 0)). More than 10x faster in their tests (empirical; the report gives no proof).
- For us: we do not need CFR at runtime. Kuhn and Leduc are small enough to state equilibria directly and check them exactly (A01, A06). CFR could make the Leduc strategy, and A06's exact check then certifies it. That avoids proving CFR itself.
- Nothing machine-checked found.

Verdict: maybe. Good background, and a possible tool to produce a Leduc strategy that we then check exactly. Proving CFR's convergence is too costly for 34 hours.

## Citations

1. Martin Zinkevich, Michael Johanson, Michael Bowling, Carmelo Piccione. "Regret Minimization in Games with Incomplete Information." Advances in Neural Information Processing Systems 20 (NIPS 2007), pp. 1729-1736 (pages from PDF metadata). Peer-reviewed conference paper.
   - URLs fetched: https://proceedings.neurips.cc/paper/2007/hash/08d98638c6fcd194a4b1e6992063e944-Abstract.html (abstract) and https://proceedings.neurips.cc/paper_files/paper/2007/file/08d98638c6fcd194a4b1e6992063e944-Paper.pdf (full text), fetched 2026-10-31.
2. Oskari Tammelin. "Solving Large Imperfect Information Games Using CFR+." arXiv:1407.5042, 18 July 2014. Preprint (technical report, 6 pages; no venue).
   - URLs fetched: https://arxiv.org/abs/1407.5042 and https://arxiv.org/pdf/1407.5042, fetched 2026-10-31 (full text read).
3. Noam Brown, Tuomas Sandholm. "Solving Imperfect-Information Games via Discounted Regret Minimization." arXiv:1809.04040 (v1 11 Sep 2018; v3 21 Feb 2019). The lead lists it as AAAI 2019; the arXiv page shows no venue, so the venue is unverified here. ABSTRACT ONLY read.
   - URL fetched: https://arxiv.org/abs/1809.04040, fetched 2026-10-31.

Not opened (UNVERIFIED, not counted): Lanctot et al. 2009, Monte Carlo CFR (NeurIPS).

Citation counts: not looked up.

## Claim status

| Claim | Source | Status |
|---|---|---|
| Thm. 2: average regret < eps for both players implies the average strategy is a 2*eps equilibrium (zero-sum) | CFR 2007 | Proved on paper (standard). |
| Thm. 3: overall regret <= sum over information sets of positive immediate counterfactual regret | CFR 2007 | Proved on paper ("the proof is in the full version"). |
| Thm. 4: with regret matching, immediate regret <= Delta_u,i * sqrt|A_i| / sqrt T, and overall regret <= Delta_u,i * |I_i| * sqrt|A_i| / sqrt T | CFR 2007 | Proved on paper (proof in the full version, not in the conference paper). |
| Solved limit hold'em abstractions with up to 10^12 states | CFR 2007 | Shown empirically. |
| CFR+ average strategy converges more than an order of magnitude faster than CFR | CFR+ 2014 | Shown empirically (one-card poker; an NLHE subgame). No proof given. |
| CFR+ current strategy "almost" converges by itself | CFR+ 2014 | Empirical observation. |
| A discounted variant beats CFR+ in every game tested | DCFR | Shown empirically (abstract claim). |
| Anything machine-checked | all | Nothing. |

## Setting and definitions

Plain words: regret for an action = how much better you would have done, summed over past rounds, if you had always taken that action at this decision point. "Counterfactual" means each decision point's regret is weighted by the chance that the opponent and chance reach it, as if you had played to get there.

Precise (CFR 2007):
- R_i^T(I, a) = (1/T) * sum_{t=1..T} pi_{-i}^{sigma^t}(I) * (u_i(sigma^t with I -> a, I) - u_i(sigma^t, I))  (eq. 7). pi_{-i} is the reach probability from the opponent and chance.
- R_i^{T,+}(I, a) = max(R_i^T(I, a), 0).
- Next strategy (eq. 8): sigma^{T+1}(I)(a) = R^{T,+}(I, a) / sum_b R^{T,+}(I, b) if the sum > 0, else 1/|A(I)|.
- Delta_u,i = range of player i's utilities. |I_i| = number of player i's information sets. |A_i| = max number of actions at a decision of player i.
- The output is the average strategy over iterations (not the last one).

## Algorithms in short steps

CFR (vanilla):
1. Start with uniform strategies.
2. Each iteration: walk the whole tree, compute counterfactual values, add each action's regret into R(I, a).
3. Set the new strategy by regret matching (eq. 8).
4. Add the current strategy, weighted by own reach probability, into the average.
5. Return the average strategy.

CFR+ (Tammelin 2014):
1. Regret-matching+: R+^T(I,a) = max(R+^{T-1}(I,a) + v(sigma^T with I -> a, I) - v(sigma^T, I), 0). Regrets are clamped at 0 each step, so negative regret does not pile up.
2. Alternating updates: one pass updates player 1, the next pass player 2.
3. Vector form (values for all private hands at once).
4. Weighted average with weight w_T = max(T - d, 0), where d is an averaging delay.
5. Side benefit: many regrets are exactly 0, which compresses well.

Discounted CFR (abstract only): variants that discount early regrets, reweight iterations in the average, use a non-standard regret minimizer, or use optimistic regret matching. One variant works with sampling; many work with pruning.

## Exact numbers

- CFR 2007: abstractions of limit hold'em with up to 10^12 states, "two orders of magnitude larger than previous methods".
- CFR+ 2014: plots of iterations needed to reach exploitability below 1 millibet per hand in one-card poker with various deck sizes; NLHE post-flop subgame with a 5-milliblind target and three bet sizes. Exact plotted values not extracted.

## Assumptions and limitations

- Two-player zero-sum with perfect recall for the equilibrium guarantee. For 3+ players (our 3-6 player mode) CFR has no equilibrium guarantee from these theorems.
- Bounds are for the average strategy.
- Floating-point in practice.

## What is formally verified

Nothing in these sources. No machine-checked proof of CFR convergence was found (not searched exhaustively).

## Code artifacts

None in these papers. License unknown.

## Relevance to our project

- Our engine is rule-based, so CFR is not needed for the main bot.
- For the Leduc mini-mode we need some strategy. Option: run a simple CFR in Lean (it is executable) for a few thousand iterations, round the strategy to rationals, and then prove its exact exploitability with A06's tree walk. The proof is about the final strategy, not about CFR.
- The 3-6 player mode has no "unexploitable" notion from these results; keep provable unexploitability to the heads-up mini-games.

## Candidate theorems for us

1. Regret matching outputs a probability distribution.
   ```lean
   theorem regretMatch_sum (r : List ℚ) (hne : r ≠ []) : (regretMatch r).sum = 1
   theorem regretMatch_nonneg (r : List ℚ) : ∀ p ∈ regretMatch r, 0 ≤ p
   ```
   About 1-2 hours.
2. Certify a CFR-made Leduc strategy (proof about the output, not CFR).
   ```lean
   theorem leduc_strategy_eps (σ := leducCfrRounded) : exploitabilityLeduc σ ≤ 1/1000
   ```
   About 8-15 hours (Leduc game, best-response walk, exact arithmetic; may need `native_decide`, an accepted axiom to declare).
3. Thm. 2 (folk): average regret below eps for both players implies a 2*eps equilibrium, for a finite matrix game. About 6-10 hours. Optional.
