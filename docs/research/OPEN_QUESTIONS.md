# Open questions

Decisions that only the team or the organizers can make. Each item gives the
options and what the research suggests. Source ids point to [INDEX.md](INDEX.md).

## For the organizers

1. **Confirm the toolchain.** CLAUDE.md says to use Lean 4.35, and its tools list says
   "ideally 4.53". Lean v4.53 does not exist (D01), so we read it as a typo and pin
   `leanprover/lean4:v4.35.0`, which the repo already does. Please confirm that judges also use v4.35.0.
2. **How do judges run Comparator?** Do judges write the trusted challenge file of theorem
   statements, or do we? We plan to ship `comparator.json` plus a `Challenge.lean` holding our main
   statements as `sorry`s (D02). Will judges run `lake check` and `lake comparator` on Linux on
   the repo as it is? The sandbox (bubblewrap) is Linux only, and we develop on Windows, so we test in WSL2.
3. **`native_decide`.** In v4.35 each use adds its own axiom, and `lake check` allows only
   `propext`, `Classical.choice` and `Quot.sound` (D02). We plan to ban it. Is there any
   accepted way to use it, such as a glob in `permitted_axioms`? That is not documented.
4. **Non-Lean helper code.** All game logic is in Lean. The Kuhn prototype uses a small
   Python standard-library server that passes requests to the Lean binary. Is that acceptable,
   and must `make install` work on a machine without Python? (Core v4.35 has `Std.Http.Server`,
   so a pure-Lean server is possible. Its Windows behavior is unknown, D06.)
5. **What `make install` may download.** elan plus the toolchain is about 545-595 MB (D06).
   We plan to skip Mathlib, which would add several GB. Do judges expect Windows, macOS or Linux?
   A Makefile needs a POSIX shell, so on Windows that means WSL or Git Bash.

## For the team

6. **Mathlib: no (recommended).** The risk-slider theorem we need (W9 in SYNTHESIS) reduces to
   `E[X^2] >= 0` and needs no Mathlib (B01, B02). Only the general Pratt theorem (M7) needs Mathlib's Jensen.
7. **Bluff slider spec: "share" or "count"?** "Twice the bluff share" (2s/(1+2s)) is not
   "twice as many bluff hands" (that gives 2s/(1+3s)) (A03). At slider 2 the bot needs 2s bluff
   hands per value hand, which its range may not hold. Then the bot must cap the share, and the
   theorem needs a matching condition. Pick one wording before writing the theorem.
8. **Review label cutoffs in big blinds.** No poker tool publishes numeric cutoffs (E05), and
   chess.com's ranges share their endpoints (E01). We must choose half-open bb ranges, such as
   Best = 0, Good < 0.5 bb, and so on. The cutoffs are part of the spec.
9. **Exact numbers everywhere.** Use `Rat` or integer chips in the bot, equity and review, with
   no `Float`. Lichess's `exp`-based accuracy formula cannot be copied; design a rational one (E02).
10. **Payout structure.** Heads-up winner-takes-all makes money value linear in chips. Then
    risk aversion is a style that costs chips, and the review can show that cost (B04).
    With 3-6 players, do we add a multi-place payout? Only then is caution correct play (B05).
11. **Quadratic utility caveat.** The recommended risk family gets more cautious as the
    stack grows (B01). Accept and disclose this, or pick another exact family.
12. **Randomness boundary.** Proofs cover functions of explicit draws. The OS random source
    and the step from random bytes to a fair draw are trusted (C01, C02). Agree to state this in the README.
13. **Odd chips.** TDA Rule 21 gives the odd chip to the first seat left of the button. It does
    not say how to split two or more odd chips (C07). Pick a rule and write it into the spec.
14. **Live hints.** Real-money sites and GTO Wizard ban real-time assistance (E05). They are fine in
    our app against our own bot, but say so in the demo.
15. **Scope after the MVP.** The stretch ladder in SYNTHESIS puts luck/skill and live review before
    side pots. Agree on it, or move 3-6 players up if the demo needs a full table.
