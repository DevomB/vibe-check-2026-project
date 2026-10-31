# B07: Davis, Waugh and Bowling (2019), "Solving Large Extensive-Form Games with Strategy Constraints" (risk in imperfect-information games)

## Summary (also in summary.md)

TL;DR: The closest game-solving paper I found on risk in imperfect-information games. It extends CFR (counterfactual regret minimization, the standard poker-solving algorithm) to **Constrained CFR**, which finds the best strategy subject to any convex constraints, such as "probability of a bad event at most b". It keeps CFR's O(1/sqrt(T)) convergence rate. Risk is handled as a **hard constraint**, not as a utility. Experiments: a security game with a risk bound, and opponent modeling in Leduc Hold'em.

- Machine-checked: no. Proofs on paper (appendix), experiments empirical. Peer-reviewed: AAAI 2019 (per arXiv comment).
- I found **no** paper on "risk-averse CFR" or a utility-based risk-averse poker bot in my arXiv searches (queries listed below). A related empirical paper (Haaf et al. 2021) fits a CRRA utility to Pluribus's play.
- For us: risk as "expected value minus r times a penalty" (B01) is simpler, exact in `Rat`, and gives a clean monotone theorem. Constrained CFR is a solver idea, too heavy for a rule-based bot.
- Its Leduc Hold'em use connects to our Kuhn/Leduc mini-mode (other group).

Verdict: ignore for implementation; cite as related work ("risk in poker solvers is usually a constraint, not a utility").

## Citation

- Trevor Davis, Kevin Waugh, Michael Bowling, "Solving Large Extensive-Form Games with Strategy Constraints", arXiv:1809.07893 v2 (Feb 2019). arXiv comment: "Appeared in AAAI 2019". Peer-reviewed conference (AAAI 2019). Citation count not looked up.
- Related, abstract only: C. Grace Haaf, Devansh Singh, Cinny Lin, Scofield Zou, "Rational AI: A comparison of human and AI responses to triggers of economic irrationality in poker", arXiv:2111.07295 (2021, preprint, econ.TH).

## URLs fetched (fetched 2026-10-31)

- http://export.arxiv.org/api/query?id_list=1809.07893 (abstract, metadata)
- https://export.arxiv.org/abs/1809.07893 (comment "Appeared in AAAI 2019")
- https://arxiv.org/pdf/1809.07893v2 (full text, read as text in a temp folder outside the repo)
- http://export.arxiv.org/api/query?id_list=2111.07295 (Haaf et al. abstract)
- Searches run (arXiv API): `abs:risk AND abs:poker`; `abs:"risk-averse" AND abs:"extensive-form"`; `abs:"risk aversion" AND abs:"imperfect-information"`; plus one web search for risk-averse / risk-sensitive CFR. None returned a risk-averse-utility CFR paper. Two 2026 preprints with "risk" in the title appeared ("RSD-Poker", arXiv:2609.33669; "SafeAdapt-Poker", arXiv:2610.20473); **titles only, not opened, UNVERIFIED**.

## Claim status

| Claim | Status |
|---|---|
| Constrained CFR converges to the minimax-optimal strategy within the feasible set, at rate O(1/sqrt(T)), with memory proportional to the number of constraints (Theorem 1) | Proved on paper |
| Strategy converges to the feasible set at O(1/sqrt(T)) up to an approximation error from bounding the multipliers (Theorem 2); fully, under Slater's condition (Theorem 3) | Proved on paper |
| Opponent modeling from partial observations converges to a best response as games and iterations grow (Theorem 6) | Proved on paper |
| In the security game (size w = 8, 100,000 iterations), risk within 0.001 of the bound and exploitability within 0.001 of the LP solution | Shown empirically (CPLEX 12.7.1 as reference) |
| Leduc Hold'em opponent modeling works (10 runs, 10^6 iterations) | Shown empirically |
| Pluribus becomes "more risk-averse and rational" after a loss or gain trigger, humans more risk-seeking (Haaf et al.) | Shown empirically, 10,000 hands, random utility model with CRRA utility (abstract only) |
| Machine-checked | No |

## Setting and definitions

- **Extensive-form game:** a game tree with chance moves and hidden information (poker).
- **CFR:** an iterative algorithm; in two-player zero-sum games its average strategy approaches a Nash equilibrium.
- **Exploitability:** how much a best-responding opponent could win against a strategy.
- **Strategy constraint:** a limit on what the strategy may do, e.g. "the chance of not returning to base is at most b_r" (their security-game risk bound). Constraints must be convex (linear in the paper's examples).
- **Constrained CFR (CCFR):** CFR plus Lagrange multipliers (weights on each constraint) updated by gradient ascent.

## Assumptions and limitations

- Two-player zero-sum; convex constraints; rates depend on step sizes and bounds on multipliers.
- Risk is a probability bound on an event, not a risk attitude over money. No Arrow-Pratt link.

## What is formally verified

Nothing.

## Code artifacts and licenses

No code link noted in the text I read (**not checked** further).

## Relevance to our project

- Related work for the "risk" part of the pitch: solvers model risk as constraints; we model it as a utility with a proven monotone slider.
- Haaf et al. used CRRA to describe Pluribus's risk attitude; CRRA needs real powers, which is one reason we choose quadratic utility instead (exact in `Rat`).

## Candidate theorems for us

1. **Penalty-monotone choice** (an idea in the spirit of "risk as a secondary objective", but for our score form): "as the Risk slider rises, the bot never switches to an action with a bigger risk penalty." If the score of action i is a_i - r * p_i (expected value minus slider times penalty), and i is a best action at r and j is a best action at s > r, then p_j <= p_i. Proof: add the two optimality inequalities to get (s - r)(p_i - p_j) >= 0.
   ```lean
   theorem chosen_penalty_antitone (acts : List Action) (ev pen : Action → ℚ) (r s : ℚ)
       (hrs : r < s) (i j : Action)
       (hi : ∀ k ∈ acts, ev k - r * pen k ≤ ev i - r * pen i)
       (hj : ∀ k ∈ acts, ev k - s * pen k ≤ ev j - s * pen j)
       (hi' : i ∈ acts) (hj' : j ∈ acts) :
       pen j ≤ pen i
   ```
   1-2 h. Works for quadratic utility (B01) because there the gain is a straight line in r. This covers risky-vs-risky choices too (bet sizes), which Pratt's theorem does not.
