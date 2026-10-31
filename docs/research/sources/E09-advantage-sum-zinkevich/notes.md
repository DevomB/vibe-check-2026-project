# E09: Optimal Unbiased Estimators for Evaluating Agent Performance (Zinkevich, Bowling, Bard, Kan, Billings; AAAI 2006): the "advantage sum"

## Summary

**Source:** Zinkevich, Bowling, Bard, Kan, Billings. "Optimal Unbiased Estimators for Evaluating Agent Performance." AAAI 2006. https://cdn.aaai.org/AAAI/2006/AAAI06-092.pdf

TL;DR: This is the clean theory under DIVAT, MIVAT and AIVAT. Take ANY value function V. At every event whose probabilities are known (cards, and any agent whose strategy is known), add "expected value of the next step (one-step lookahead Q) minus the value after the step that happened". The result (the "advantage sum") is unbiased for every possible behaviour of the unknown agents (Theorem 1). With V = true conditional expectation it is the minimum-variance unbiased estimator (Theorem 3).
- Exact formula: `u^(h) = u(h) + sum over known steps t of ( Q(h(t)) - V(h(t+1)) )`, with `Q(h) = sum_e V(h·e) k(e|h)`.
- Theorem 1 proof is three lines of finite-sum algebra (uses only `sum_e k(e|h) = 1`). Very Lean-friendly.
- This is our luck/skill split: luck term at a known step = `V(after) - Q(before)`; skill steps are the human's steps. Then "actual result = V(start) + luck + skill" is a telescoping identity, provided V equals Q at known nodes.
- The unknown agent (our human) can do anything; unbiasedness still holds.
- Empirical: limit hold'em, 7.2x and 5.7x fewer hands needed than money counting.

Verdict: use. Best single source for the exact identity we want to prove; simpler notation than AIVAT.

## Citation
- Martin Zinkevich, Michael H. Bowling, Nolan Bard, Morgan Kan, Darse Billings. "Optimal Unbiased Estimators for Evaluating Agent Performance." AAAI Conference on Artificial Intelligence (AAAI-06), 2006, pages 573-579 (per mlanthology; other listings say 573-578, unsure which is right). No DOI listed.
- Fetched 2026-10-31: https://cdn.aaai.org/AAAI/2006/AAAI06-092.pdf (official AAAI PDF, read as text; not saved in repo) and https://mlanthology.org/aaai/2006/zinkevich2006aaai-optimal (BibTeX).
- Source type: peer-reviewed conference paper (AAAI-06). Some proofs (Theorems 2, 3, 5) are only sketched; full proofs are in a separate technical report we did not open.
- Citation count: not looked up.

## Claim status
| Claim | Status |
|---|---|
| Theorem 1: for any V and known dynamics k, the advantage sum is an unbiased estimator of u for every true dynamics that agrees with k | Proved on paper, full proof in the paper. Not machine-checked. |
| Theorem 2: every unbiased estimator equals an advantage sum for some V (on histories possible under k) | Proof sketched; full proof in a tech report (not opened). |
| Theorem 3: with V = the true conditional expectation, the advantage sum has minimum variance among unbiased estimators | Proof sketched (non-constructive existence step). |
| Lemma 4 / Theorem 5: a V close to the true one gives variance close to the minimum (explicit bounds) | Stated; proofs in tech report. |
| DIVAT is an instance; large variance reduction in limit poker | Shown empirically. |

## Setting and definitions
- Plain words: a game is a sequence of events. For some events we know the probabilities (cards; a bot whose code we have). For others we do not (a human's choices). A value function V is any guess of "expected final result from here". The estimator corrects the actual result by removing the effect of each known random event, replaced by its expected effect.
- Precise (paper's notation, ASCII):
  - Histories h (sequences of events), terminal histories O (finite), utility u : O -> R.
  - K: the set of non-terminal histories where the next-event distribution k(e|h) is known.
  - Value function V : H -> R (any function).
  - One-step lookahead: `Q_{V,k}(h) = sum_{e in E} V(h·e) k(e|h)` (Equation 7).
  - Advantage sum: `u^_{V,k}(h) = u(h) + sum_{t such that h(t) in K} ( Q_{V,k}(h(t)) - V(h(t+1)) )` (Equation 8), where h(t) is the first t events.
  - Unbiased for k: `E[u^] = E[u]` under every true dynamics sigma that agrees with k on K.
- "Natural" V: V(h) = E_rho[u | h] for a belief rho about the full dynamics (Equation 6).

## Main results (exact)
- Theorem 1 proof core (Equation 9 and the next line): for a fixed known history h' at step t,
  `E[ I(h(t) = h') (Q(h') - V(h(t+1))) ] = Pr[h'] * ( Q(h') - sum_e k(e|h') V(h'·e) ) = 0`, using `sum_e k(e|h') = 1` and the definition of Q. Then sum over t and h' by linearity.
- Assumptions used: O finite (game ends within T events; no-op events pad to length T); the true dynamics agree with k on K.
- Theorem 3: V = V_sigma (true conditional expectation) gives minimum variance.
- Lemma 4: `E[ |u^_{V,k} - u^_{V',k}| ] <= 2 * sum_h Pr[h] |V(h) - V'(h)|`. Theorem 5 bounds the variance gap by `4 * u_max * sum_h Pr[h] |V(h) - V'(h)|`. (Copied as seen in our text extraction; symbols with primes may be slightly garbled. Unsure on exact placement of primes.)

## Empirical results
- Limit hold'em, self-play of a program: money SD 5.5 sb/h vs DIVAT advantage sum 2.0 sb/h: 7.2 times fewer hands for similar accuracy.
- Seventy thousand hands experiment: money SD 4.9 sb/h; DIVAT advantage sum needs 5.7 times fewer hands (we saw "need 5.7 times the number of hands to have a money estimate" in the text).
- Break-even example: about 800 hands with money vs 100 hands with DIVAT advantage sum (from the text; context partly garbled). Analysis cost 0.418 seconds per hand on average.

## Assumptions and limitations
- Unbiased only on average over many hands. On one hand the correction terms are the luck you had, not zero.
- Needs exact known probabilities for known events. For our bot: its action probabilities (deterministic bot: probability 1 on its action, so its correction is 0).
- Hidden information: the paper's histories include everything; it does not by itself say how to grade a human who cannot see the bot's cards. AIVAT (E03) adds that with information-set averaging.

## What is formally verified
Nothing machine-checked.

## Code artifacts and licenses
None in the paper.

## Relevance to our project: the exact identity
Let the hand's events be e_1..e_n, h(t) the first t events, V any value function with V(terminal) = actual result u. Tag each step t as known (chance or bot) or human.
1. Telescoping (pure algebra, one hand): `u = V(h(0)) + sum_t ( V(h(t+1)) - V(h(t)) )`.
2. If V is defined so that V(h) = Q(h) at known nodes (V is the expectation over the next known event), each known step's term `V(h(t+1)) - V(h(t)) = V(h(t+1)) - Q(h(t))` is exactly minus the paper's correction: we call it luck. Human steps are skill.
3. So `actual = baseline + luck + skill`, exactly, with baseline = V(h(0)). And the advantage sum (paper's estimator) equals `baseline + skill`, i.e. "result minus luck".
4. Mean zero of each luck term is Equation 9: a finite weighted sum. No measure theory needed if we state it as `sum_e k(e|h) * (V(h·e) - Q(h)) = 0`.
5. For the human step, define V(before) at a human node as the best action's value (averaged over the bot's possible cards, as in AIVAT) so that skill = -(EV loss) <= 0. Then V at human nodes is not an expectation, which is fine: Theorem 1 needs nothing at unknown nodes.

## Candidate theorems for us
1. Telescoping decomposition on a recorded hand.
   - Lean shape: `theorem actual_eq_baseline_add_luck_add_skill (steps : List Step) (v0 : Rat) (h : chains v0 steps) : finalValue v0 steps = v0 + luckSum steps + skillSum steps`
   - Estimate: 2 to 4 h.
2. One-step mean zero (Equation 9 core).
   - Lean shape: `theorem correction_mean_zero (es : List E) (k : E → Rat) (V : E → Rat) (hk : (es.map k).sum = 1) : (es.map fun e => k e * (V e - (es.map fun e' => k e' * V e').sum)).sum = 0`
   - Estimate: 1 to 2 h.
3. (Stretch) Full Theorem 1 for a finite game tree as an inductive type: expected advantage sum = expected utility for every human strategy.
   - Lean shape: `theorem advantageSum_unbiased (g : GameTree) (V : Hist → Rat) (σ : HumanStrategy) : expect g σ (advantageSum V) = expect g σ utility`
   - Estimate: 8 to 16 h (tree induction, expectations as finite sums). Good only if the core is done early.
