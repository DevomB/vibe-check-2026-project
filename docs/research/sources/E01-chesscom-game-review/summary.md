# Summary: E01: Chess.com Game Review: move labels and Accuracy (CAPS2)

**Source:** Chess.com Help Center. "How are moves classified?" https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-and-etc. "What is Accuracy in Analysis?" https://support.chess.com/en/articles/8708970-what-is-accuracy-in-analysis-how-is-it-measured

TL;DR: Chess.com labels each move by "expected points" lost (0.00 to 1.00 scale, from engine eval plus player rating) using a fixed table. Accuracy (CAPS2) is 0 to 100 but its formula is not published.
- The label table: Best 0.00; Excellent 0.00-0.02; Good 0.02-0.05; Inaccuracy 0.05-0.10; Mistake 0.10-0.20; Blunder 0.20-1.00 (expected points lost).
- Best means exactly zero loss. We can copy this and prove `label = Best ↔ loss = 0`.
- Their ranges share endpoints and the page does not say which label a boundary value gets. Use half-open ranges in bb; prove the labeling is total and monotone.
- Great, Brilliant and Miss use extra verbal rules; skip them or define them precisely.
- Accuracy formula is secret, so "100 iff no loss" cannot be checked for chess.com. For us it can be a theorem.

Verdict: use. It defines the UX we copy and shows which parts (labels, 100 = no loss) we can make exact.


Full extraction: [notes.md](notes.md).
