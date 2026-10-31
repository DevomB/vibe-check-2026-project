# Summary: E08: Jacovi and Goldberg, "Towards Faithfully Interpretable NLP Systems" (ACL 2020)

TL;DR: An opinion paper that separates "plausibility" (does the explanation convince people?) from "faithfulness" (does it reflect the model's real reasoning?). It warns that generated text explanations can be plausible with no faithfulness guarantee, that "inherently interpretable" is a claim to be checked, and that user-study success does not show faithfulness.
- Gives us the vocabulary for the live-review pitch: our explanations are faithful by proof, not just plausible.
- Directly supports our design choice: LLM-written commentary is plausible-only; proved explanation records are faithful.
- Their "Model Assumption" (two models with the same predictions use the same reasoning) is the informal version of our replay theorem.
- They doubt strict faithfulness is reachable for neural NLP; for a small rule-based bot it is reachable, and provable. That contrast is a good talk slide.

Verdict: use (for framing and citation; no theorems come from it directly).


Full extraction: [notes.md](notes.md).
