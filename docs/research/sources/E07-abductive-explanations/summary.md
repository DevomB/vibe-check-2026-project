# Summary: E07: Abduction-Based Explanations for Machine Learning Models (Ignatiev, Narodytska, Marques-Silva) + our live-review assessment

TL;DR: An "abductive explanation" of a decision is a set of input facts that is enough to force the decision (any input agreeing on those facts gets the same output), and from which no fact can be dropped (subset-minimal). The paper computes these with a linear number of solver calls over a logical encoding of the model.
- This is exactly the right definition for our live review: soundness = "the listed facts force the action"; minimality = "drop any listed fact and some input changes the action".
- Our bot is a small rule-based function, so we can prove these properties in Lean directly instead of calling a solver.
- Soundness is cheap (2-6 h); minimality is harder (6-12 h) and only true if we build the explanation carefully.
- Real numbers (equity) must be exact rationals; Monte Carlo equity or floats would break the proofs.

Verdict: use. It gives a precise, citable meaning for "the explanation is exactly why the bot did it".


Full extraction: [notes.md](notes.md).
