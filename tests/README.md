# Differential tests

The Lean engine against our `poker-calculations` library, pinned to exactly `4.0.3`
(MVP section 7). Versions below 4.0.0 are not used: 2.2.0 to 3.2.0 had an evaluator bug.

## Run

From the repo root:

```sh
cd engine && lake build difftest && cd ..
cd tests && npm ci && npm run diff
```

`npm run diff -- --deals=2000` does a quick run with fewer random ranking deals. The full run
takes a few minutes, most of it in the library's exact flop equity.

## What is compared

The Lean side is `engine/DiffTest.lean`, a small driver that answers with the spec's `showdown`
and the bot's `countsFor`. `diff/run.ts` deals distinct cards itself (the library accepts
duplicate cards), passes cards as `"Ah"`, and never asks the library for exact preflop equity.

| Check | Lean | Library | Passes when |
| --- | --- | --- | --- |
| Hand ranking, 100,000 random deals | `showdown`, kind of best hand | `evaluateHandStrength`, `evaluateHandCategory` | same winner and same kinds, every deal |
| Hand ranking, 2,000 deals each from A-6, T-A and heart-heavy cards | same | same | same, every deal |
| Exact equity against a known hand, flop / turn / river | every board finish, `showdown` | `exactHuEquityVsKnownHand` | equal (to 1e-9) |
| Exact equity against a random hand, turn / river | `countsFor` | `exactHuEquityVsRandomHand` | equal, and 45,540 / 990 outcomes |
| Flop estimate | `countsFor` (1,000 seeded deals) | `exactHuEquityVsRandomHand` | within 4 standard errors |
| Preflop table | `countsFor` (table, 50,000 deals per hand) | `simulateHandOutcomeDetailed`, 100,000 deals | within 4 combined standard errors |

The library's royal flush counts as a straight flush, since the spec has no separate kind for it.

## Last result

Oct 31, 2026, Windows x64, Node 22.20.0, seed 20261031: **all 11 checks passed, 0 failures.**

| Check | Passed |
| --- | --- |
| Ranking, random deals | 100,000 / 100,000 |
| Ranking, A-6 / T-A / heart-heavy deals | 2,000 / 2,000 each |
| Exact vs known hand, flop / turn / river | 30 / 30 each |
| Exact vs random hand (`countsFor`), turn, 45,540 outcomes | 20 / 20 |
| Exact vs random hand (`countsFor`), river, 990 outcomes | 60 / 60 |
| Flop estimate within 4 standard errors | 12 / 12 (largest gap 1.17 SE) |
| Preflop table within 4 standard errors | 36 / 36 (largest gap 2.19 SE) |

## Files

- `diff/run.ts`: the harness.
- `diff/cases.json`: every case and both answers. The ranking deals are too many to store; for
  those it keeps the seed, the count, a SHA-256 of the requests and the first ten. The same seed
  always gives the same deals, so a rerun reproduces them and the hash confirms it.
- `diff/results.json`: pass or fail for each check, with up to 20 failing cases each.
