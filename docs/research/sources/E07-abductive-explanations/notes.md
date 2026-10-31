# E07: Abduction-Based Explanations for Machine Learning Models (Ignatiev, Narodytska, Marques-Silva) + our live-review assessment

## Summary

**Source:** Ignatiev, Narodytska, Marques-Silva. "Abduction-Based Explanations for Machine Learning Models." AAAI 2019. https://arxiv.org/abs/1811.10656. DOI 10.1609/aaai.v33i01.33011511

TL;DR: An "abductive explanation" of a decision is a set of input facts that is enough to force the decision (any input agreeing on those facts gets the same output), and from which no fact can be dropped (subset-minimal). The paper computes these with a linear number of solver calls over a logical encoding of the model.
- This is exactly the right definition for our live review: soundness = "the listed facts force the action"; minimality = "drop any listed fact and some input changes the action".
- Our bot is a small rule-based function, so we can prove these properties in Lean directly instead of calling a solver.
- Soundness is cheap (2-6 h); minimality is harder (6-12 h) and only true if we build the explanation carefully.
- Real numbers (equity) must be exact rationals; Monte Carlo equity or floats would break the proofs.

Verdict: use. It gives a precise, citable meaning for "the explanation is exactly why the bot did it".

## Citation
- Alexey Ignatiev, Nina Narodytska, João Marques-Silva. "Abduction-Based Explanations for Machine Learning Models." AAAI Conference on Artificial Intelligence (AAAI-19), 2019, pages 1511-1519, DOI 10.1609/aaai.v33i01.33011511.
- Preprint: arXiv:1811.10656 (v1, 2018-11-26).
- Fetched 2026-10-31: https://mlanthology.org/aaai/2019/ignatiev2019aaai-abduction (BibTeX: venue, pages, DOI); http://export.arxiv.org/api/query?id_list=1811.10656,2004.03685 (arXiv metadata); https://arxiv.org/pdf/1811.10656 (full text, read; not saved in repo). The official AAAI page https://ojs.aaai.org/index.php/AAAI/article/view/3964 was blocked by a bot wall (also unsure that is the right article number).
- Source type: peer-reviewed conference paper (AAAI-19) + preprint.
- Citation count: not looked up.

## Claim status
| Claim | Status |
|---|---|
| A subset-minimal explanation is a prime implicant of (model encoding -> prediction), given the input | Proved on paper (standard logic result; the paper cites Marquis). |
| Subset-minimal explanation needs a linear number of oracle (solver) calls | Proved on paper / algorithmic argument. |
| Cardinality-minimal (smallest) explanation is hard (second level of the polynomial hierarchy, cited to Eiter and Gottlob 1995; the exact symbol was garbled in our text copy) and needs, in the worst case, exponentially many calls | Cited complexity results (proved elsewhere). |
| The approach scales and gives small explanations on UCI, PennML and MNIST data | Shown empirically (SMT oracle Yices2; MILP oracle CPLEX 12.8.0; 1800 s time limit, 4 GB memory). Some datasets were not fully explained within 1800 s. |
| The explanation is correct (any input matching it gets the same prediction) | Guaranteed by construction, because each step checks entailment with a solver; the solver is trusted (not proof-producing). |

## Setting and definitions
- Plain words: you have a model M and an input. The model gives prediction p. An explanation is a subset of the input's feature values such that, whatever the other features are, M still predicts p. "Subset-minimal" means removing any one feature from the explanation breaks this. "Cardinality-minimal" means no smaller explanation exists at all.
- Precise (paper): encode M as a formula F in some logic theory T. The input is a cube C (a conjunction of literals "feature = value"). E is the prediction. A subset-minimal explanation C_m is a subset of C with `C_m ∧ F ⊨ E` and no proper subset has this property; equivalently C_m is a prime implicant of `F → E` contained in C.
- Algorithm 1 (subset-minimal): start with the full input C; for each literal l, if `C \ {l}` still entails E (checked by an oracle), drop l. One pass, linear number of oracle calls.
- Oracles used: SMT (Yices2 reported; Z3 also tried) and MILP (CPLEX 12.8.0). Neural networks with ReLU are encoded as MILP with indicator constraints.

## Main results (empirical)
- On average, subset-minimal explanations kept 28.5% to 86.7% of the features depending on the dataset, mean 60.5%. Best case (australian): 1 feature, about 7% of the sample. Some samples cannot be reduced at all.
- The MILP oracle computed a subset-minimal explanation of a sample "in a fraction of a second" and outperformed SMT.
- Not all datasets finished in 1800 s in total (examples named in the paper: australian, auto, backache).

## Assumptions and limitations
- Needs an exact logical encoding of the model. Approximate models (sampling) do not fit.
- Trusts the solver.
- Explanations are about the model, not about the world: they say why the model decided, not whether the decision was good.

## What is formally verified
No machine-checked proofs. Correctness rests on the solver answers.

## Code artifacts and licenses
The paper mentions a prototype implementation; we did not see a repository link or license in the extracted text. Unsure.

## Relevance to our project: live review assessment (question 5)
Plan: the bot's decision function returns `(action, explanation)`. The explanation is a small record of exact numbers and the comparison that fired, e.g. `{equity := 41/100, potOdds := 1/4, bluffTerm := 0, aggressionTerm := 3/100, rule := .callIfEquityAtLeastOddsPlusMargin}`.

Can we prove the following?
1. Soundness (replay): "evaluating the explanation alone gives the same action".
   - If the bot is written as `decide obs = let ex := explain obs; (replay ex, ex)`, this is true by definition (rfl). That is honest but weak: it only shows the action is computed from the explanation record.
   - Stronger and still cheap: prove the numbers in the explanation are the numbers the bot's real formula uses, e.g. `(decide obs).2.equity = equity obs.hole obs.board` and `(decide obs).2.potOdds = obs.toCall / (obs.pot + obs.toCall)`. Also mostly rfl.
   - Estimate: 1 to 3 h.
2. Sufficiency (Ignatiev-style, the meaningful one): any other situation that agrees on the listed facts gets the same action.
   - `∀ o', agrees o' ex → (decide o').1 = (decide o).1`. Needs `decide` to depend on obs only through the explanation's fields. Provable by rewriting `decide` into "compute features, then a pure decision on features". If the bot uses randomness (bluff slider), the random draw must be one of the listed facts (e.g. `bluffRoll := 37/100`) and the RNG seed logged.
   - Estimate: 3 to 6 h.
3. Minimality / completeness: "the explanation lists every condition the action depended on, and nothing extra".
   - Two readings. (a) Completeness = sufficiency (item 2): nothing outside the list mattered. (b) Minimality: for each listed fact, changing only that fact (keeping the others) can change the action. For a decision list (if c1 then A elif c2 then B ...), the natural explanation is "c1 false, c2 false, c3 true". That is sufficient but not always minimal (an earlier failed guard may be irrelevant for this action). To prove minimality we must either compute the explanation as Ignatiev's Algorithm 1 does (drop facts that are not needed) or prove, per rule, a witness that flips the action.
   - Proving minimality for continuous facts needs explicit witness inputs per rule; with a handful of rules this is case work.
   - Estimate: 6 to 12 h. Recommend: do soundness + sufficiency first; claim minimality only if proved.
4. Practical risks:
   - Equity must be exact (full enumeration over runouts and the opponent range, as rationals). Monte Carlo equity with a fixed seed is reproducible but the explanation would then say "estimated equity", and the "exact" claim would be about the estimate.
   - The GUI must render the explanation record, not a free-text paraphrase. If an LLM writes prose, label it unverified; only the numbers and the comparison are proved.
   - Floats: use `Rat` (or scaled `Int`) in the decision path, or proofs will stall.

## Candidate theorems for us
1. Replay soundness.
   - Lean shape: `theorem decide_replay (o : Obs) : replay (decide o).2 = (decide o).1`
   - Estimate: 0.5 to 1 h (rfl or simp if built that way).
2. Explanation numbers are the real ones.
   - Lean shape: `theorem explain_equity (o : Obs) : (decide o).2.equity = equityOf o.hole o.board o.range`
   - Estimate: 0.5 to 2 h.
3. Sufficiency (abductive explanation).
   - Lean shape: `theorem decide_sufficient (o o' : Obs) (h : Agrees o' (decide o).2) : (decide o').1 = (decide o).1`
   - Estimate: 3 to 6 h.
4. Subset-minimality per rule.
   - Lean shape: `theorem explanation_minimal (o : Obs) (f : Fact) (hf : f ∈ (decide o).2.facts) : ∃ o', AgreesExcept o' (decide o).2 f ∧ (decide o').1 ≠ (decide o).1`
   - Estimate: 6 to 12 h.
5. Bad-output check: an explanation with a wrong number is rejected.
   - Lean shape: `example : ¬ Agrees o' {ex with equity := 9/10} ...` or `example : replay {ex with rule := .fold} ≠ (decide o).1 := by decide`.
   - Estimate: 0.5 h.
