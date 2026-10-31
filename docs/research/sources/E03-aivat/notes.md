# E03: AIVAT (Burch, Schmid, Moravčík, [Morrill,] Bowling)

## Summary (also in summary.md)
TL;DR: AIVAT scores a played hand as "base value + one correction term per chance event and per known-strategy player action". Each correction is "expected value before the choice minus value after the observed choice", using ANY fixed value function. The proved theorem: every correction term has expected value 0, so the estimate is unbiased. Nothing else (variance) is proved.
- What must be known: the chance probabilities (public) and the strategy of the players whose actions get corrections. Our bot is known code, so its actions and the deal qualify; the human's actions do not.
- The value function can be arbitrary (any fixed heuristic). It only affects variance, not unbiasedness.
- The mean-zero fact is a finite weighted sum identity. We can prove it in Lean over rationals without measure theory.
- "Result = baseline + luck terms + skill terms" is a telescoping sum on one recorded hand. Exact, no probability needed.
- Results: about 10x fewer hands needed in no-limit hold'em (shown empirically, 1 million games, one-sided).

Verdict: use. It is the theory behind our luck-vs-skill graph and tells us exactly which terms have mean zero and why.

## Citation
- Preprint / workshop version: Neil Burch, Martin Schmid, Matej Moravčík, Michael Bowling. "AIVAT: A New Variance Reduction Technique for Agent Evaluation in Imperfect Information Games." arXiv:1612.06915 (v1 2016-12-20, v2 2017-01-19). Comment on arXiv: "To appear at AAAI-17 Workshop on Computer Poker and Imperfect Information Games". Subject cs.AI.
  - Fetched 2026-10-31: https://arxiv.org/abs/1612.06915 , http://export.arxiv.org/api/query?search_query=id:1612.06915&max_results=1 , https://arxiv.org/pdf/1612.06915 (text read; PDF not saved in repo), https://ar5iv.arxiv.org/html/1612.06915 (author list check).
  - The arXiv version lists 4 authors (no Dustin Morrill).
- Peer-reviewed version: same title, authors Burch, Schmid, Moravčík, Dustin Morrill, Bowling. AAAI Conference on Artificial Intelligence (AAAI-18), 2018, pages 949-956, DOI 10.1609/aaai.v32i1.11481.
  - Fetched 2026-10-31: https://mlanthology.org/aaai/2018/burch2018aaai-aivat (BibTeX with pages and DOI). The official page https://ojs.aaai.org/index.php/AAAI/article/view/11481 was blocked by a bot wall (not opened). So the AAAI metadata is verified only via mlanthology.
  - All technical content below is from the arXiv v2 text. The AAAI-18 version may differ (it has an extra author). Unsure how much.
- Source type: preprint (arXiv) + peer-reviewed conference paper (AAAI-18).
- Citation count: not looked up (Semantic Scholar returned HTTP 429).

## Claim status
| Claim | Status |
|---|---|
| Lemma 1: each correction term k_H has expected value 0 | Proved on paper (in the paper). Not machine-checked. |
| Theorem 1: the sum of all correction terms has expected value 0 | Proved on paper (follows from Lemma 1 by linearity). |
| AIVAT(z) is unbiased | Proved on paper, given that the base value (imaginary observations, Bowling et al. 2008) is unbiased, which the paper cites rather than reproves. |
| With perfect value functions and all strategies known, variance can be zero | Stated as an argument, shown empirically (Leduc self-play: SD cut "a little less than 99.9%"). |
| More than 10x fewer hands needed in no-limit | Shown empirically. |

## Setting and definitions (plain words first)
- A game is a tree of events: chance events (cards dealt) and player decisions. A player decides at an "information set": the set of game states they cannot tell apart (for example, all possible opponent hole cards).
- Known-strategy players P_a: chance (always) plus any player whose strategy (probability of each action at each information set) we know. Unknown players P_o: everyone else. If P_a = {chance}, AIVAT reduces to MIVAT.
- Value function u_h(a): any fixed function giving an estimate of the expected value after action a at state h. The paper says "arbitrary".
- Observed game: one terminal state z (one full played hand).
- Correction term at a decision point (simplified form the paper uses to explain): `E_a[u_h(a)] - u_h(o)` where o is the observed outcome. In words: "what we expected before the choice" minus "what we estimate after the choice we actually saw". Its expectation is 0 if a is drawn from the probabilities used in E_a.
- Full AIVAT correction term for a part H of the partition (exact formula from the paper, ASCII rendering of the paper's notation):
  `k_H(z) = [ sum_{a in A(H)} sum_{h in H} pi_{P_a}(h·a) u_h(a) ] / [ sum_{h in H} pi_{P_a}(h) ]  -  [ sum_{h in H} pi_{P_a}(h·a_O) u_h(a_O) ] / [ sum_{h in H} pi_{P_a}(h·a_O) ]`
  and k_H(z) = 0 if z does not pass through H. Here pi_{P_a}(h) is the probability that the known players (incl. chance) play to reach h, and a_O is the observed action. H groups states that the unknown players cannot tell apart from the known players' side (same unknown-player reach probabilities; in poker: same betting, same board, same unknown player's cards, different known player's cards).
- Partition conditions on H (paper's 3 properties): (1) all states in H have the same unknown-player reach probability; (2) no state in H is a prefix of another (so a terminal state passes through at most one state of H); (3) all states in H share the same action set (actions are padded with probability 0).
- Base value (imaginary observations): `sum_{z' in W} pi_{P_a}(z') v_p(z') / sum_{z' in W} pi_{P_a}(z')`: average the payoff over all terminal states that look the same to the unknown players, weighted by the known players' reach probability. In poker: re-evaluate the hand with every possible private hand of the known player, weighted by how likely it is given the observed play.
- Estimator: `AIVAT(z) = base value + sum_{H} k_H(z)` (Equation 1).

## Main results (exact statements)
- Lemma 1: for every H, `E_z[k_H(z)] = 0`.
- Theorem 1: `E_{z in Z}[ sum_{H} k_H(z) ] = 0`.
- Conditions used in the proof: (a) z is drawn from the true joint play; (b) the probabilities pi_{P_a} used inside k_H are the true probabilities of the known players and of chance; (c) the partition properties 1-3; (d) u_h is any fixed function (it cancels; no assumption on its accuracy). The unknown players' strategy can be anything; it cancels because of property 1 (the proof multiplies by pi_{P_o}(H)/pi_{P_o}(H) = 1).
- Unbiasedness meaning (paper's words, paraphrased): a player cannot look better by changing their play to exploit the estimator.

## Experimental results (shown empirically)
- Leduc hold'em (small research poker), 100,000 games; value functions from self-play equilibrium (MCCFR). Self-play, both strategies known: per-game SD cut by "a little less than 99.9%"; only one strategy known: 99.8%; MIVAT 33.8%; MIVAT + imaginary observations 45.1%. Dissimilar strategies (one calls/raises at random): AIVAT cuts SD by 48% to 75%; MIVAT + imaginary observations 25%.
- Heads-up no-limit hold'em: blinds 1/2 chips, 200-chip stacks (100 bb), 1 million games, only one agent's strategy used. Value function from a small abstraction with 8 million information sets. MIVAT + imaginary observations: 39% SD reduction; AIVAT: "a bit more than" 68%; MIVAT alone: 18%.
- Conclusion: about 3x lower SD, so about 10x less data for the same significance.
- (The extracted table columns were garbled in our text copy; we only report numbers stated in the prose.)

## Relation to DIVAT and MIVAT (as described in this paper)
- DIVAT (Zinkevich et al. 2006; Billings and Kan): needs a strategy for all players to make value estimates by self-play.
- MIVAT (White and Bowling, IJCAI 2009, pp. 1976-1981 per this paper's reference list; not opened by us): allows an arbitrary value function, adds a correction `E_a[u(a)] - u(o)` per chance event only. Accounts for lucky cards but not lucky randomized actions.
- Imaginary observations (Bowling et al., ICML 2008): use a known strategy to average over states that look the same to the opponent.
- AIVAT = MIVAT-style terms for chance AND known-strategy actions + imaginary observations, matched so they do not double count.

## Assumptions and limitations
- Needs exact probabilities for chance and for the known player. A bot with true randomness (mixed strategy) must expose its probabilities; a deterministic bot has probability 1 on its chosen action, so its action terms are 0 (no luck from its choices).
- Unbiased is a statement about the average over many hands. On a single hand the correction terms are not zero; they are the luck.
- Variance reduction depends on value-function quality; not proved.
- Human (unknown strategy) decisions get no correction term. Their effect stays in the residual.

## What is formally verified
Nothing is machine-checked in the paper. Proofs are on paper, short (a few lines of sum manipulation).

## Code artifacts and licenses
None linked in the arXiv text. Unsure whether code exists.

## Relevance to our project
Our setting fits AIVAT very well: the bot is known code (P_a = {chance, bot}), the human is the unknown player. This gives a principled luck/skill split for the review graph.

Exact identities we can prove on one recorded hand, with no probability theory:
1. Telescoping. Let V_0, V_1, ..., V_n be the value estimates after each event of the hand, with V_n = actual chips won. Then `V_n - V_0 = sum_k (V_k - V_{k-1})`. Tag each step as luck (chance or bot event) or skill (human decision). So `actual = V_0 + luckSum + skillSum`, exactly. This is our seed theorem "EV plus luck equals the actual result".
2. Mean zero, as a finite sum. At a luck step with options a (probabilities p a, summing to 1) and before-value defined as `V_before = sum_a p a * V_after a`, we get `sum_a p a * (V_after a - V_before) = 0`. Pure algebra over Rat with Finset/List sums. This is the AIVAT Lemma 1 core.
3. Skill step sign. If the before-value at a human decision is defined as the best action value (max over legal actions, averaged over the bot's possible hidden cards as in imaginary observations), the skill term is `-(EV loss)` and is <= 0, and = 0 iff the human chose a best action.

Important design point on hidden cards: the human decides at an information set (does not know the bot's cards). If the skill term used the true bot cards, the verdict would depend on hidden cards (violating our seed property). AIVAT's answer: average over the bot's possible private hands, weighted by the probability the bot (known code) would have played this way with each hand (pi_{P_a}). The gap between the averaged value and the true-card value then becomes a luck term (the "which hand did the bot actually have" chance event), still mean zero under that weighting. Computing that weighting needs the bot's action probability for every possible hole-card pair (1,326 combos minus blockers): cheap if the bot is a fast function.

Caveat: exact EV before the river needs the bot's future play over all future cards, which may be expensive; the brief already plans "clearly labeled estimates" there. AIVAT shows any fixed estimate u keeps the luck terms mean-zero, so estimates are fine for the identity; only the labels' exactness suffers.

## Candidate theorems for us
1. Luck plus skill equals result (telescoping on a recorded hand).
   - Plain: for any recorded hand, baseline + sum of luck terms + sum of skill terms = chips actually won.
   - Lean shape: `theorem result_decomposes (h : RecordedHand) : (h.values.getLast?).getD 0 = h.baseline + luckSum h + skillSum h`, or with a list of steps: `theorem telescope (v : List Rat) (v0 : Rat) : (v0 :: v).getLast (by simp) = v0 + (deltas v0 v).sum`
   - Estimate: 2 to 4 h including the step tagging.
2. Each luck term has weighted mean 0 under the true probabilities.
   - Lean shape: `theorem luck_mean_zero {α} (opts : List α) (p : α → Rat) (V : α → Rat) (hp : (opts.map p).sum = 1) : (opts.map fun a => p a * (V a - (opts.map fun b => p b * V b).sum)).sum = 0`
   - Estimate: 1 to 2 h.
3. Skill term is minus the EV loss, never positive, zero iff best action.
   - Lean shape: `theorem skill_nonpos (q : Action → Rat) (legal : List Action) (a : Action) (ha : a ∈ legal) : q a - best q legal ≤ 0` and `theorem skill_zero_iff : q a - best q legal = 0 ↔ ∀ b ∈ legal, q b ≤ q a`
   - Estimate: 1 to 2 h.
4. Hidden-card independence of the skill term: the human's skill term depends only on the information set.
   - Lean shape: `theorem skill_info_only (s t : State) (h : s.humanView = t.humanView) (a : Action) : skillTerm s a = skillTerm t a`
   - Estimate: 1 to 3 h if skillTerm is defined as a function of `humanView`; then it is close to rfl.
5. (Stretch) Full probabilistic unbiasedness over a finite deal space (sum over all deals of prob * correction = 0) for one bot decision, using the bot's actual code for its probabilities. 6 to 12 h; only if time remains.
