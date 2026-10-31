# Summary: E05: Poker review tools: GTO Wizard Analyzer, PokerTracker 4 All-in Equity graphs, RTA policies

TL;DR: GTO Wizard's analyzer reports EV loss per action in big blinds and colors actions green / yellow (inaccuracy) / red (blunder), but publishes no numeric thresholds. PokerTracker 4's "All-in Equity" line replaces the result of all-in hands by (equity x pot - amount bet), using the opponent's actual cards; it is explicitly a luck measure.
- EV loss in bb per decision is the industry unit (GTO Wizard: "lost 7.65 bb"). Good, matches our plan.
- No public tool gives label thresholds in bb. We must choose and justify our own; they are part of the spec.
- GTO Wizard grades against pre-solved GTO solutions (preflop to turn) and an exact river solve; bet sizes are snapped to the nearest solved size. Our grades are against our known bot instead: stronger claim (exact best response) for river and all-in spots.
- PokerTracker excludes hands with unknown hole cards and multiway hands with unequal stacks. Its all-in equity uses the opponent's real cards: fine for a luck graph, wrong for a decision grade.
- Real-time assistance (RTA) is banned by GTO Wizard's terms (per press report) and by sites such as ACR. Our "live hints" are fine against our own bot in our app, but say so in the pitch.

Verdict: use. It sets the units (bb), the UX (three colors, EV-loss filter) and the luck-graph convention we should match.


Full extraction: [notes.md](notes.md).
