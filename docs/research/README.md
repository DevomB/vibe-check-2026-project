# Research phase: verified poker app (Vibecheck 2026)

> **Historical.** Written on Oct 31, before the build. The shipped product differs: other
> slider rules (no aggression slider, no quadratic Risk formula), no Kuhn or Leduc mode, a
> Node bridge instead of Python, and sampled (Monte Carlo) preflop and flop counts. A
> `KuhnPoker/` folder was never in the repo. What was built and proved is in
> [SPEC.md](../../SPEC.md) and the [README](../../README.md).

This folder holds the literature and tools research done before the build phase.
It is notes and links only: no PDFs, no project code.

- Start: Sat 2026-10-31 13:27 (local time, from `date`)
- Planned hard stop: 2026-10-31 14:57 (start + 90 minutes)
- End: 2026-10-31 13:57 (final commit; all five groups finished by 13:47)

## The product (fixed going in)

"Build your opponent, play it, get a proven game review." A No-Limit Hold'em
engine and bot written in Lean 4, with a web GUI. Fixed 500-chip stacks, one
deck, heads-up first, then 3 to 6 players with side pots. A rule-based bot with
three sliders (risk, bluff, aggression). A Kuhn and Leduc poker mini-mode. A
chess.com-style game review graded by EV loss in big blinds.

## Plan

Five research subagents ran in parallel, one per group, each aiming for about
six sources (30 in all); they delivered 40. Each source gets one folder with
one `notes.md`: a short summary at the top (with the citation and a link to
the original), then the full extraction. The lead then read every summary and
wrote the synthesis.

| Group | Topic | Folder prefix |
|---|---|---|
| A | Poker AI and game theory: CFR, solved games, Kuhn and Leduc, opponent modeling, the math of bluffing | `sources/A..` |
| B | Risk, utility and tournaments: Arrow-Pratt, CRRA/CARA, Kelly, CVaR, ICM | `sources/B..` |
| C | Verifying games, cards and randomness: verified card games, shuffles, game theory in proof assistants, hand evaluators, side-pot rules | `sources/C..` |
| D | Lean 4 engineering: verification tools, Comparator, toolchain choice, GUI shipping, performance | `sources/D..` |
| E | Game review, live review and product: chess.com and Lichess accuracy, poker review tools, luck vs skill (DIVAT, AIVAT), faithful explanations | `sources/E..` |

If time ran short, groups B, C and E had priority.

## Rules the research followed

- Every cited source was opened first. The exact URL and the fetch date are in its notes.
  Sources that could not be opened are marked UNVERIFIED and do not count.
- Every claim is labeled: machine-checked (with tool and version), proved on paper,
  shown empirically, or opinion. Preprints are marked as such.
- Non-academic sources (product docs, blogs, books) appear only in group E and for game rules,
  and are labeled.

## Files

- [INDEX.md](INDEX.md): one row per source.
- [SYNTHESIS.md](SYNTHESIS.md): ranked verification targets, novelty, MVP cut, model-vs-code check, parked ideas.
- [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md): decisions for the team or the organizers.
- `sources/<id>-<slug>/notes.md`: summary and citation at the top, full extraction below. Papers are not stored; use the links.
