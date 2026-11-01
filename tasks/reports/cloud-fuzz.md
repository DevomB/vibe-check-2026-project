Build path changed: no

# Cloud fuzz of the compiled game program

**Result: no failures.** 2,232 games through the real `poker` program. No crash, hang, stuck
turn, chip error, accepted illegal move, changed state after a rejection, replay difference,
wrong review label, or reply over 3 seconds.

## What was tested

- **Commit tested:** `df6904a` ("Put review_lost under Comparator"), `origin/main`.
- **Build:** `cd engine && lake build` with Lean 4.35.0, 2 min 17 s, no errors.
  - The cloud sandbox blocks `release.lean-lang.org`, so I installed the same Lean 4.35.0
    release from GitHub and linked it with `elan toolchain link`.
  - No build files were changed.
- **Command:** `node tools/fuzz-engine.mjs --games 3000 --minutes 45 --workers 3 --seed 2026`
  - 3 programs ran at once on a 4-core machine.
- **Totals:**
  - The run stopped at the 45-minute limit (45 min 2 s), before 3,000 games.
  - 2,232 games, 64,573 hands and 257,876 requests.
  - 17,840 of the requests were deliberately bad.
  - Every game ended in game over. None reached the 400-hand cap.
- **Sliders:** every pair of Risk {0, 25, 50, 75, 100} and Bluff {0, 20, 33, 60}, about 110
  games each.
- **Replays:** 126 games were replayed in a fresh program. Every reply matched byte for byte.
- **Reviews:** 893 river decisions were graded: Best 441, Good 61, Inaccuracy 114, Mistake 99,
  Blunder 178.

## Failures

None. No repro files were written.

What was checked on every reply:

- **Chips.** `pot` + both stacks + both bets = 1,000, all whole numbers.
- **Status.** The status is one of the three allowed values.
- **While playing:**
  - the human is to act;
  - `legal` is set;
  - the bot's cards are hidden.
  - There was never a stuck turn.
- **Legal options.**
  - `check` is allowed exactly when nothing is owed.
  - `call` = min(owed, stack).
  - The bot's bet < raise `min` ≤ `max` ≤ stack + bet.
- **Bad requests.** Each bad request got an error, and the state that came back equalled the
  previous state with `events` emptied, compared as full JSON. The bad requests covered:
  - raises below `min`, above `max`, or when no raise is allowed;
  - `check` facing a bet, and `call` with nothing to call;
  - negative, decimal, string and missing amounts;
  - an unknown action;
  - `next_hand` while playing, and `act` after the hand or game was over;
  - reviews of hand 0 and of hands not yet played;
  - unknown commands and broken JSON;
  - sliders out of range, and a seed that is not digits.
- **`state` and reviews.** Neither changed the state.
- **Next hand.** It was accepted in `handOver` and moved the hand number up by 1.
- **Game over:**
  - one player has all 1,000 chips;
  - `next_hand`, `call`, `fold` and `raise` are all rejected afterwards, with the state
    unchanged.
- **Reviews:**
  - every label is one of the five, or null for an ungraded move;
  - only river calls and folds are graded;
  - fold is worth 0;
  - the label matches the MVP §6 band for the BB lost;
  - the sign of the call's worth agrees with equity had vs. equity needed;
  - the number of graded moves equals the number of times the human called or folded
    against the bot's opening river bet;
  - `bot_reasons` is set once the hand is over.

To show the checks can fail, I ran the script once against a wrapper that corrupted replies.
It reported each kind of corruption: an extra chip in the pot, a crash (and restarted the
program), the bot's cards shown, and a state changed after a rejection or by a review.

## Speed (ms per reply)

Each move is filed under the street of the state that came back. That is where the bot did
its last thinking. "showdown" means the hand ended at a showdown.

| Reply           | Count  | Median | 95th % |   Max |
|-----------------|-------:|-------:|-------:|------:|
| preflop         | 32,839 |    0.1 |    0.2 |    15 |
| flop            | 35,853 |     40 |    119 |   306 |
| turn            | 13,105 |    444 |    788 | 1,169 |
| river           |  4,893 |     77 |    767 | 1,090 |
| showdown        |  4,365 |    0.5 |    572 |   951 |
| new_game        |  2,232 |    0.3 |    0.8 |   250 |
| next_hand       | 62,341 |    0.2 |    0.5 |    18 |
| review          | 70,691 |    0.1 |    2.5 |   128 |
| state           |  4,789 |    0.1 |    2.9 |    14 |
| rejected        | 26,768 |    0.1 |    2.3 |    21 |

- No reply took more than 3 seconds. The slowest was a turn reply at 1.17 s.
- The turn is the slow street, because of the exact enumeration (MVP §5).
- These times are with 3 programs sharing 4 cores. A single game on the demo laptop should be
  a little faster. Recheck on the demo hardware, as MVP §15 says.

## Reviews near a band edge

There were 9 cases near a band edge. All of them have the right label:

- **8 calls worth exactly −2.00 BB, labelled Mistake.**
  - Mistake is [2, 5) BB lost, so exactly 2 is a Mistake.
  - All of them had Bluff 0, where the bot's bets are all value bets.
  - Seeds 6163025236636917295, 4068729929915784360, 3218435530271916526,
    2963171542849928448, 10731288181451434460, 1722359134704754223, 2068968608739671021,
    375846222710943384.
- **1 fold where calling was worth +0.01 BB, labelled Good.**
  - Seed 13228377812355096299, Risk 75, Bluff 33, hand 57.
  - This is correct: a little more than 0 was lost.

## Limits of this run

- The human plays at random, so long careful lines are rare.
- The script checks the invariants above. It does not check every rule in MVP §4 on its own,
  for example the exact min-raise after a short all-in. The Lean proofs and
  `src/lean/program.test.ts` cover those.
- Timings come from a cloud machine, not the demo laptop.

## Rerun

On any machine with Node and the built engine (`cd engine && lake build`):

```
node tools/fuzz-engine.mjs --games 300
```

On Windows it finds `engine\.lake\build\bin\poker.exe`. You can also set `POKER_BIN`.
Results and any repro files go to `fuzz-out/`. Rerun one failure with
`node tools/fuzz-engine.mjs --replay fuzz-out/repro-001-<kind>.json`.
