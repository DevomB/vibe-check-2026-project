# Summary: C01: Fisher–Yates shuffle (Isabelle AFP entry, Manuel Eberl)

**Source:** M. Eberl. "Fisher-Yates shuffle." Archive of Formal Proofs, 2016 (BSD). https://www.isa-afp.org/entries/Fisher_Yates.html

TL;DR: A machine-checked Isabelle/HOL proof that Fisher–Yates (forward and backward) gives every ordering of a list the same probability. BSD license, maintained up to Isabelle2026.
- The spec shape to copy: "the output distribution equals the uniform distribution over all orderings of the input" (`fisher_yates xs = shuffle xs`).
- Key invariant: after step i, the first i cards are fixed and the rest are a uniform shuffle.
- It assumes perfectly uniform index draws. Turning random bytes into a uniform index (modulo bias) is outside it, and will be outside ours too. The README must say so.
- Cheaper route for us: make our shuffle a pure function of explicit draws `d_k < 52 - k` and prove draws-to-deck is a bijection. That gives uniformity by counting, about our real code, with no probability library. About 8–15 h total; the permutation part alone is 1–3 h.
- No poker or card-game content. It is prior art for the shuffle only.

Verdict: use. It is the reference result for the shuffle claim and gives the invariant for our Lean proof.


Full extraction: [notes.md](notes.md).
