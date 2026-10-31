# Summary: B03: Isabelle AFP, "Von-Neumann-Morgenstern Utility Theorem" (Parsert and Kaliszyk, 2018)

**Source:** Parsert, Kaliszyk. "Von-Neumann-Morgenstern Utility Theorem." Archive of Formal Proofs, 2018. https://www.isa-afp.org/entries/Neumann_Morgenstern_Utility.html


TL;DR: The only proof-assistant formalization of expected utility I found is this Isabelle/HOL entry in the Archive of Formal Proofs. It proves the von Neumann-Morgenstern theorem: for a finite, non-empty set of outcomes, a preference over lotteries is rational, independent and continuous exactly when it is ranked by expected utility. It has **no risk aversion, no concavity, no Arrow-Pratt, no Pratt theorem**.

- Machine-checked (Isabelle/HOL, AFP). License LGPL. Utilities are `real`-valued; lotteries are `pmf`s.
- It justifies "the bot ranks options by expected utility" as a sensible model of a rational player, but we would not port it.
- So a Lean proof of a discrete Pratt theorem would be, as far as I found, new in a proof assistant. That is a good line for the pitch, but say "we found no prior formalization", not "first ever".
- Lean Reservoir and Coq/Rocq: **not checked** (Reservoir search is rendered by JavaScript and did not answer my query; no time for Rocq).

Verdict: maybe. Good for the related-work slide and the "no prior formal Pratt" claim; nothing to reuse in code.


Full extraction: [notes.md](notes.md).
