# E08: Jacovi and Goldberg, "Towards Faithfully Interpretable NLP Systems" (ACL 2020)

## Summary (also in summary.md)
TL;DR: An opinion paper that separates "plausibility" (does the explanation convince people?) from "faithfulness" (does it reflect the model's real reasoning?). It warns that generated text explanations can be plausible with no faithfulness guarantee, that "inherently interpretable" is a claim to be checked, and that user-study success does not show faithfulness.
- Gives us the vocabulary for the live-review pitch: our explanations are faithful by proof, not just plausible.
- Directly supports our design choice: LLM-written commentary is plausible-only; proved explanation records are faithful.
- Their "Model Assumption" (two models with the same predictions use the same reasoning) is the informal version of our replay theorem.
- They doubt strict faithfulness is reachable for neural NLP; for a small rule-based bot it is reachable, and provable. That contrast is a good talk slide.

Verdict: use (for framing and citation; no theorems come from it directly).

## Citation
- Alon Jacovi, Yoav Goldberg. "Towards Faithfully Interpretable NLP Systems: How should we define and evaluate faithfulness?" Proceedings of ACL 2020 (58th Annual Meeting of the Association for Computational Linguistics). arXiv:2004.03685 (v1 2020-04-07; v3 latest), arXiv comment: "Accepted to ACL 2020".
- Fetched 2026-10-31: http://export.arxiv.org/api/query?id_list=1811.10656,2004.03685 (metadata), https://arxiv.org/pdf/2004.03685 (full text, read; not saved in repo). The ACL Anthology page https://aclanthology.org/2020.acl-main.386/ failed with a certificate error, so the anthology ID, pages and DOI are UNVERIFIED (venue is confirmed only by the arXiv comment).
- Source type: peer-reviewed conference paper (ACL 2020), self-described "opinion piece".
- Citation count: not looked up.

## Claim status
| Claim | Status |
|---|---|
| Plausibility and faithfulness are different and are often conflated | Opinion / argument, supported by a literature survey. |
| Post-hoc generated text explanations have no faithfulness guarantee | Argument (example-based). |
| Current evaluation methods rest on three assumptions (Model, Prediction, Linearity) | Survey and classification by the authors. |
| User performance in HCI studies does not show faithfulness | Argument with a fictional counter-example. |
| Strict (binary) faithfulness is likely unreachable; use a graded notion | Opinion. |

## Setting and definitions
- Plain words: an explanation is faithful if it tells the truth about how the system actually decided. It is plausible if people find it convincing. You can have either without the other.
- Paper's wording (short quotes): faithful means it "accurately represents the reasoning process behind the model's prediction"; plausibility is "how convincing the interpretation is to humans".
- Assumption 1 (Model Assumption): two models make the same predictions iff they use the same reasoning process. Basis of "fidelity": how well an explanation that is itself a model mimics the original's decisions.
- Assumption 2 (Prediction Assumption): on similar inputs, the model makes similar decisions iff its reasoning is similar.
- Assumption 3 (Linearity Assumption): some input parts matter more than others, and their contributions are independent.

## Main points (guidelines from the paper, paraphrased)
- Be explicit about whether you evaluate faithfulness or plausibility.
- Do not trust "inherent interpretability" claims; check them like any post-hoc method.
- Faithfulness evaluation should not rely on user performance (a fictional system with random-word explanations can still raise user performance).
- Evaluate faithfulness on a graded scale rather than yes/no; the authors call strict global faithfulness a "unicorn".

## Assumptions and limitations
- Focus on neural NLP models. Rule-based or verified systems are outside its main concern.
- No formal definitions; the assumptions are informal.

## What is formally verified
Nothing (position paper).

## Code artifacts and licenses
None.

## Relevance to our project
- Framing for the live review: "Our bot's explanations are faithful by proof: the shown numbers and comparison are exactly what the code used, and the action follows from them alone." Contrast with LLM commentary: plausible, not faithful.
- The paper's warning about "inherent interpretability" applies to us: "rule-based bot, so it is interpretable" is a claim. The Lean theorems (E07 candidates 1 to 4) are what make it more than a claim.
- Fidelity = "explanation-as-model reproduces the decision". Our replay theorem is fidelity 100%, proved for all inputs, not measured on a test set.

## Candidate theorems for us
1. Fidelity 100% for all inputs (same as E07 replay/sufficiency, stated as fidelity).
   - Lean shape: `theorem explanation_fidelity (o : Obs) : replay (decide o).2 = (decide o).1`
   - Estimate: 0.5 to 1 h (shared with E07).
2. No free-text in the trusted path: the GUI explanation is a pure rendering of the record.
   - Lean shape (if the renderer is in Lean): `theorem render_mentions_numbers (ex : Explanation) : (render ex).contains (toString ex.equity) = true` (weak; a design rule more than a theorem).
   - Estimate: 1 to 2 h; low value; optional.
