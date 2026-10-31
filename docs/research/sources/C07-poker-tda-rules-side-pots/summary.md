# Summary: C07: Poker TDA Rules (2026, Version 1.1) on side pots, odd chips, short all-ins, heads-up; plus real pot-award bugs

TL;DR: The official tournament rules (Poker TDA, 2026 v1.1, 21 Sept 2026) say little about how side pots are built. They say each side pot is split on its own, the odd chip goes to the first seat left of the button, and a short all-in does not reopen betting for players who already acted. We must write the side-pot construction ourselves, which is exactly where proofs add value. Real sites have paid pots to the wrong player (GGPoker 2022, UltimateBet 2008).
- Rule 23: "Each side pot will be split separately." Rule 21: odd chip to the first seat left of the button (board games, like Hold'em).
- Rule 49-A (no-limit): a short all-in, or several short all-ins together, below a full raise does not reopen betting for players who already acted. Rule 45-A: a raise must be at least the largest prior full bet or raise in the round.
- Rule 36-C: heads-up, the small blind is the button, acts first preflop and last after the flop.
- The TDA text gives no side-pot construction algorithm and no order for awarding pots. Our spec must define both; the theorems below make that spec checkable.
- Non-academic bug reports (labelled) show wrong-winner bugs caused by edge cases (a game-mode flag, a disconnect at the moment of award). These make a good motivation slide.

Verdict: use. It is the rule source for the engine and gives the plain-English statements we should prove.


Full extraction: [notes.md](notes.md).
