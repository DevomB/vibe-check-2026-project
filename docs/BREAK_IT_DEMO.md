# Live demo: break the engine, watch Lean refuse

About 30 seconds. It shows the proofs are about the real code: change one line so the game
pays the wrong player, and Lean will not accept it.

## Before the pitch

Build the engine once, so the demo can reuse the build:

```sh
cd engine && lake build && cd ..
```

## On stage

```sh
checks/break-it.sh --clean
```

What appears on screen:

```
  BUG PLANTED:  At a showdown, pay the pot to the player with the WORSE hand.
  (one line changed in a copy of Engine/Hand.lean; your files are untouched)

  Asking Lean to re-check the proofs...

  LEAN REFUSES.  (32s)
  The proof breaks in: Engine/Proofs/Payout.lean, line 119
  Inside:              payShowdown_ok
  Theorem that no longer holds: showdown_pays_better_hand (at a showdown, the better hand wins the pot)

  Now the same check on the code without the bug...
  ALL PROOFS PASS.  (0s)
```

What to say:

> "We just told the engine to pay the pot to the loser. One line. Lean refuses: the theorem
> that the better hand wins the pot no longer holds. Put the line back and every proof passes.
> That is the difference between tested and proved."

## Facts to get right

- The script never touches the real files. It copies `engine/` to a temporary folder, changes
  one line in `Engine/Hand.lean` there, and rebuilds only the proofs about payouts.
- The failure is in `payShowdown_ok` (`Engine/Proofs/Payout.lean`), the step of the proof of
  `showdown_pays_better_hand` that checks the showdown payout.
- The clean run says 0s because nothing changed, so Lean reuses the build it already checked.
- Second bug, if asked: `checks/break-it.sh --bug fold` gives the pot to the player who folded.
  Lean stops at the first failure, an example in `Engine/Proofs/EndsSpec.lean` (line 31) that
  plays a fold. The theorem `fold_records_other_player` is also false with this bug, but Lean
  never gets that far. The script says so on screen.

## Timing and fallback

- Measured on the demo laptop: 9 to 51 seconds for the bug run (slower when other builds were
  running at the same time). Close other builds before the pitch.
- If it is slow or the laptop misbehaves, show the recorded run in
  [`docs/break-it-sample-output.txt`](break-it-sample-output.txt) and say what it shows.
