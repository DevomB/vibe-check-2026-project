# Summary: E02: Lichess Accuracy (win% from centipawns, per-move and game accuracy)

TL;DR: Lichess publishes its full accuracy formula and code. Win% comes from a logistic curve on centipawns; per-move accuracy is an exponential of the win% drop; game accuracy averages a volatility-weighted mean and a harmonic mean.
- Win% = 50 + 50 * (2 / (1 + exp(-0.00368208 * centipawns)) - 1).
- Move accuracy (code) = clamp(103.1668100711649 * exp(-0.04354415386753951 * winDiff) - 3.166924740191411 + 1, 0, 100); exactly 100 when win% does not drop.
- The "+1 uncertainty bonus" plus clamp means a move that loses up to about 0.224 win% points still scores 100 (our arithmetic from the constants). So "100 iff no loss" is FALSE for Lichess. Our design should avoid this on purpose.
- Game accuracy = (volatility-weighted mean + harmonic mean) / 2, with window size clamp((n-1)/10, 2, 8) and weights = std. dev. of win% clamped to [0.5, 12].
- exp and floats make this hard to prove in Lean; use a rational formula instead.

Verdict: use. It is the only fully published accuracy formula; copy the shape, fix the "100 iff no loss" gap, and use rationals.


Full extraction: [notes.md](notes.md).
