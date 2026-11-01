# The bot and its win counts: what is proven, what is trusted

This covers the slider bot (`engine/Engine/Slider.lean`) and the win/tie/loss counts it
uses (`engine/Engine/Equity.lean`). For the rules of the game itself, see `SPEC.md`.

## What the bot does

The bot has two sliders: Risk (0 to 100) and Bluff (0 to 60%). It sees its own two cards,
the board and the chips. It never sees the other player's cards.

1. It counts how many of the other player's possible hands it beats, ties and loses to
   (`countsFor`). The sliders are not an input to this step.
2. It decides from those counts (`decideWithCounts`):
   - Facing a bet: raise pot-sized if it wins at least 75% (ties count half) and a raise is
     legal. Otherwise call if the call pays at its Risk (`callPays`). Otherwise fold.
   - No bet to face, before the river: bet the pot if it wins at least 65%. Otherwise check.
   - No bet to face, on the river: bet the pot if its hand is in the river betting set.
     Otherwise check.
   - Every bet and raise size is cut down to the legal range.

All the math is in whole numbers. No decimals are used in any decision.

## What is proven

Each theorem is checked by Lean. `#print axioms` shows only Lean's standard axioms
(`propext`, `Classical.choice`, `Quot.sound`). There is no `sorry`, `native_decide` or
`partial def` in any of this code.

| Theorem | In plain words | File |
| --- | --- | --- |
| `botDecide_legal` (T3, bot half) | Whenever the player to act may act at all, the bot's move is legal. This holds for every slider setting, seed, set of cards and board. | `Engine/Proofs/BotLegal.lean` |
| `botDecide_risk_monotone` (T4) | Take one spot. If the bot calls or raises at some Risk, it also calls or raises at every lower Risk. So more Risk can turn a call into a fold, but never a fold into a call. | `Engine/Proofs/BotRisk.lean` |
| `risk_monotone` (T4, for given counts) | The same, for any win/tie/loss counts. | `Engine/Proofs/BotRisk.lean` |
| `enumeration_exact` (T6) | The exact river and turn counts look at every possible outcome exactly once, and score each one with the spec's `showdown`. On the river, that is every hand the opponent can hold (990 of them, when the bot's two cards and the five board cards are all different). On the turn, it is every (river card, opponent hand) pair. | `Engine/Proofs/EquityExact.lean` |
| `bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it` | The bot calls only when the call is worth it at its Risk, and folds only when it is not. Both assume the pot is at least the call. No theorem yet proves that this holds in every real hand. "Worth it" means that a lost chip counts (1 + Risk/50) times as much as a won chip (MVP §3; `RiskSpec.lean`). | `Engine/Proofs/RiskUtility.lean` |

The two properties are written out on their own in `Engine/Proofs/BotSpec.lean`
(`AlwaysLegal`, `RiskMonotone`). That file also shows that each property rejects a bad bot:
a bot that always checks, a bot that bets more chips than it has, and a decision table that
calls at Risk 100 but folds at Risk 0. T3 and T4 each also have a worked example on a real
spot, with every condition met.

`Classical.choice` comes in only through the preflop lookup: `rankLetters` (the letters
`23456789TJQKA` used to name a starting hand) calls Lean's own `String.toList`, which uses it.
That code still runs, and the tests run it. The bot's decision step on its own
(`decideWithCounts_legal`, `risk_monotone`) uses only `propext` and `Quot.sound`.

## What to review

A theorem means what its statement says, so these definitions are the ones to read:

- The rules (`engine/Poker/Spec/Basics.lean`): `Legal`, `State.MayAct`, `State.toCall`,
  `State.minRaise`.
- The properties: `AlwaysLegal`, `RiskMonotone`, `Action.continues` (a call or a raise).
- The bot: `botDecide`, `decideWithCounts`, `viewOf`, `decideView`, `riverOpening`, `riverBetOrCheck`,
  `callPays`, `Counts.atLeast`, `State.raiseBounds`, `State.allIn`, `State.potToWin`,
  `clampTo`.

The reason text (`chanceText`, `betVerb`) never changes the move. The counts do not matter
for T3 or T4: both hold for any counts. T4 only needs the fact that `countsFor` has no Risk
input (`botDecide_eq`, true by definition).

## What is trusted, not proven

- **The preflop table.** `data/preflop.json` holds counts for the 169 starting hands. Each
  is an estimate from 50,000 random deals, with seed 20261031, made by
  `npx --yes tsx@4.20.6 scripts/gen-preflop.ts`. `engine/Engine/PreflopData.lean` is
  generated from it by `npx --yes tsx@4.20.6 scripts/gen-preflop-lean.ts`. Never edit it by
  hand.
- **The flop count is an estimate.** It uses 1,000 random deals from the hand's seed, with
  the same random number generator as the TypeScript (mulberry32). The same seed always
  gives the same counts.
- **The turn and river counts are exact.** The turn counts all 45,540 (river card, opponent
  hand) pairs. This is fixed, not chosen by machine speed. It takes 0.67 to 0.93 s per
  decision on 8 cores (the compiled engine, Oct 31, 2026). Hands are scored with the spec's
  own `bestScore`, so the counts rank hands exactly as the spec does.
- **The river betting set** comes from `Engine/River.lean` (`riverRole`). On the river with
  no bet to face, the bot bets pot-sized with a value hand or a bluff from that set, and
  otherwise checks. `Engine/RiverTests.lean` checks the set against the TypeScript
  `riverBettingSet`. T3 and T4 hold for any river betting set.

## How the Lean bot is tested against the TypeScript

The TypeScript bot (`src/ai/slider/`) is the reference.

- `engine/Engine/SliderTests.lean` runs the Lean bot on 249 spots the TypeScript bot
  decided: edge cases for each rule, plus 200 random spots. The build fails if any move or
  reason differs. The cases are generated by `npx --yes tsx@4.20.6 scripts/gen-slider-golden.ts`.
- `engine/Engine/SliderRiverTests.lean` checks 40 more spots, for the river with no bet to
  face, move and reason, against the TypeScript `riverOpeningFromSet`. They take about two
  minutes to build, because each one scores all 1,081 possible river hands.
- `engine/Engine/EquityTests.lean` checks the Lean counts against the TypeScript counts
  (`src/ai/slider/counts.ts`, `data/preflop.json`) on fixed spots: river, a seeded flop, and
  preflop AA and 72o. The turn spots are slow in the interpreter, so `lake exe equity-bench`
  checks them on the compiled engine.
