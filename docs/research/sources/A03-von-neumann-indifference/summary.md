# Summary: A03: Von Neumann's poker model and the indifference principle (bluff share by bet size)

**Source:** C. Ferguson, T. S. Ferguson. "On the Borel and von Neumann Poker Models." Venue unsure. https://www.math.ucla.edu/~tom/papers/poker1.pdf


TL;DR: Ferguson and Ferguson restate von Neumann's one-bet poker model with exact formulas and derive them from "indifference equations". From their first equation, the bluff share of the betting range is B/(2B+2) for a bet of B into a pot of 2. That is s/(1+2s) with s = bet / pot. We believed s/(1+2s), and it is confirmed under the conditions below.

What matters for us:
- Balanced bluff share = s/(1+2s) = the caller's required equity (pot odds). It holds for one final betting decision, a polarized betting range, a caller who can only call or fold, and chip-EV (risk-neutral) payoffs.
- With slider k in [0, 2], k * s/(1+2s) <= 2s/(1+2s) < 1 for every bet size. So the target share never reaches 1. But the needed bluffs per value hand is 2s at k = 2, which can be more bluff hands than the range has.
- "Twice the bluff share" (2s/(1+2s)) is not "twice as many bluff hands" (that gives share 2s/(1+3s)). The spec must pick one.
- Von Neumann's exact solution: value B/((B+1)(B+4)); at B = 2 (pot-sized bet), a = 1/9, b = 7/9, c = 5/9, value 1/9, and B = 2 is the best bet size.
- Nothing here is machine-checked. The algebra is a 1-2 hour Lean target.

Verdict: use. It gives the exact baseline for the bluff slider and its conditions.


Full extraction: [notes.md](notes.md).
