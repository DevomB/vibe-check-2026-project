# Summary: C08: Verified game-tree search (Nipkow's Alpha-Beta, Isabelle AFP 2024), a published CFR+ proof error (JAIR 2019), and the chess / CFR gap

**Source:** T. Nipkow. "Alpha-Beta Pruning." Archive of Formal Proofs, 2024. https://www.isa-afp.org/entries/Alpha_Beta_Pruning.html. Burch, Moravčík, Schmid. "Revisiting CFR+ and Alternating Updates." JAIR 64, 2019. https://arxiv.org/abs/1810.11542

TL;DR: Minimax search with alpha-beta pruning is machine-checked in Isabelle (Nipkow, 2024). Poker solving (CFR) has no machine-checked proof I could find. One published CFR+ bound had a wrong proof step that later work fixed (Burch, Moravcik, Schmid, JAIR 2019). For chess, I found only small projects (a Coq retrograde-analysis line, a Lean hackathon checker), not a verified move generator.
- Gap = novelty: no verified CFR, no verified exploitability or best-response computation, no verified poker engine.
- Good message for judges: "even the published proof for a top poker algorithm had a hole; we machine-check ours" (we check our Kuhn/Leduc strategy, not CFR itself).
- For our bot and review: computing a best response in Kuhn/Leduc is a finite tree walk. That is the same kind of proof as Nipkow's minimax work, but with information sets.
- Do not try to verify CFR convergence in 34 hours. Verify the output strategy instead (certificate check, see C04 and C05).

Verdict: maybe. Use it for novelty claims and the pitch; it gives no code for us to use.


Full extraction: [notes.md](notes.md).
