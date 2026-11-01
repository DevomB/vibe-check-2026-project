# Aarav's overnight report: river set, review, T9 (Nov 1, 2026)

Branch: `aarav/review-lost-comparator` (pushed; not merged). Base: main at 3356666 plus the
step 1 commit df6904a, which was merged to main earlier in the evening (before the "never
merge" instruction) and is green on the Lean proofs Action.

Everything below passes `cd engine && lake build` (no warnings in the changed files),
`checks/audit.sh`, `lake comparator` and `lake check` on the branch head, c438dfc.

## What is on the branch, in order

| Commit | Step | What |
| --- | --- | --- |
| df6904a (on main) | 1 | `review_lost` added to Challenge and Comparator, statement copied unchanged |
| 5b7e7d8 | 2 | `Engine/Proofs/RiverBot.lean`: `botDecide_river_follows_set`, `review_hands_ne_nil`; both in Challenge and Comparator |
| b4d508f | 3 | `rankRiverHands_sorted` plus `value_strongest`, `bluffs_weakest` (BluffFrequency.lean); `cardId`, `RanksAbove` (BluffSpec.lean); main theorem in Challenge and Comparator |
| f8faac9 | 5 | Two stale comments fixed (RiverBench.lean, River.lean) |
| 855d9fd | 6 | `tests/diff/run.ts` records commit, dirty flag and Lean toolchain |
| 6b67216 | 4 | Review.lean: `botHands_ne_nil_of_board` and examples with every condition met for `review_worth`, `review_lost`, `review_label_monotone`, `review_call_best_iff_equity`; known-bad reviews rejected |
| 6fa95ed | 6 | Diff tests rerun: all 11 checks pass; README "Last result" updated |
| c438dfc | 7 | T9 `every_hand_ends` (EndsSpec.lean, Ends.lean); in Challenge and Comparator |

Not touched: Makefile, package.json, any lockfile, lean-toolchain, lakefile, lake-manifest,
scripts/, Poker/Spec/, Session.lean, Slider.lean code, Protocol.lean, src/, README.md,
MVP.txt, SPEC.md, docs/. Existing theorem statements and spec definitions are unchanged.
Review.lean gained one import (`Engine.Proofs.BluffFrequency`) for the counting lemmas.

## Statements to approve (plain words, then the Lean as written in Checks/Challenge.lean)

### Step 2: the bot bets exactly its river betting set

Plain words: on the river, with nothing to call and some bet legal, the bot bets exactly when
its two cards are a value hand or a designated bluff in `riverBettingSet`, and checks exactly
when they are not. The seed and the Risk setting play no part.

```lean
theorem botDecide_river_follows_set (sl : Sliders) (seed : Nat) (a b : Card)
    (board : List Card) (s : State) (h5 : board.length = 5) (h0 : s.toCall = 0)
    (hbet : ∃ n, Legal s (.raiseTo n)) :
    ((∃ n, (botDecide sl seed [a, b] board s).action = .raiseTo n) ↔
      ∃ h ∈ (riverBettingSet sl.bluffPct board).value ++ (riverBettingSet sl.bluffPct board).bluffs,
        h.cards = (a, b) ∨ h.cards = (b, a)) ∧
    ((botDecide sl seed [a, b] board s).action = .check ↔
      ¬ ∃ h ∈ (riverBettingSet sl.bluffPct board).value ++ (riverBettingSet sl.bluffPct board).bluffs,
        h.cards = (a, b) ∨ h.cards = (b, a))
```

"A bet is allowed" is written as "some raise is legal" (`∃ n, Legal s (.raiseTo n)`), the
spec's own notion. "Bets" is "the move is a `raiseTo`".

Corollary (plain words): when the human faces the bot's opening river bet and no card was
dealt twice, the review's hand list is not empty, because the bot's own hand is in it.

```lean
theorem review_hands_ne_nil (h : Hand) (sl : Sliders) (seed n : Nat) (s : State)
    (h5 : h.board.length = 5) (h0 : s.toCall = 0)
    (hbet : (botDecide sl seed (h.hole (other h.chips.toAct)) h.board s).action = .raiseTo n)
    (hnd : h.dealtCards.Nodup) :
    (riverSpotOf h sl.bluffPct).botHands ≠ []
```

Here `h` is the hand in which the human (the player to act) faces the bet; `s` is the state
the bot decided in (nothing to call). Devom's Session proofs can feed `s := the chips before
the bot's move` and `hnd` from `no_card_dealt_twice`.

### Step 3: the river ranking is strongest first

Plain words: `rankRiverHands` lists every candidate hand above every hand after it: by
showdown score, and among equal scores by card IDs with the lower IDs first (first cards
compared first, then second cards), as MVP §5 asks.

```lean
theorem rankRiverHands_sorted (board : List Card) :
    (rankRiverHands board).Pairwise RanksAbove
```

with, in `Engine/Proofs/BluffSpec.lean` (new definitions, nothing existing changed):

```lean
/-- A card's ID: its place in a new deck (`fullDeck`): 2c = 0, 2d = 1, ..., As = 51. -/
def cardId (c : Card) : Nat :=
  4 * c.rank.val + match c.suit with | .clubs => 0 | .diamonds => 1 | .hearts => 2 | .spades => 3

/-- `x` ranks above `y`: a higher showdown score, or the same score and lower card IDs. -/
def RanksAbove (x y : RankedHand) : Prop :=
  y.score < x.score ∨
    (x.score = y.score ∧
      (cardId x.cards.1 < cardId y.cards.1 ∨
        (cardId x.cards.1 = cardId y.cards.1 ∧ cardId x.cards.2 < cardId y.cards.2)))
```

`example : ∀ c ∈ fullDeck, fullDeck.idxOf c = cardId c := by decide` checks the IDs against
the deck order.

Readable consequences (proved in BluffFrequency.lean, not in Challenge; say if you want them
there too):

- `value_strongest`: every value hand scores at least as well as every candidate hand
  outside the value set.
- `bluffs_weakest`: every designated bluff scores no better than every candidate hand that is
  not a bluff. This is stronger than the task's wording ("every non-value hand that is not a
  bluff"): it also covers the value hands.

### Step 7 (stretch): every hand ends

Plain words: from any game the engine can reach, every run of accepted moves has at most 200
moves (`botFuel`). So no hand goes on forever, and the bot loop never runs out of fuel.

```lean
theorem every_hand_ends (g : Game) (hg : g.Reachable) (as : List Action) (h' : Hand)
    (hrun : RunsTo g.hand as h') : as.length ≤ 200
```

with, in the new `Engine/Proofs/EndsSpec.lean`:

```lean
/-- `h` reaches `h'` by the moves `as`, each one accepted by the engine `st`. -/
def RunsWith (st : Hand → Action → Except String Hand) : Hand → List Action → Hand → Prop
  | h, [], h' => h' = h
  | h, a :: as, h' => ∃ h₁, st h a = .ok h₁ ∧ RunsWith st h₁ as h'

/-- `h` reaches `h'` by the moves `as`, each one accepted by `step`. -/
def RunsTo : Hand → List Action → Hand → Prop := RunsWith step
```

The proof shows at most 117 moves; 200 was chosen to match `botFuel` (`example : botFuel =
200 := rfl` is in Ends.lean). The idea: a measure of the hand (stacks / 10, streets left,
players still to act, players with chips) goes down on every accepted move that does not end
the hand. A by-product, `reachable_acted`: in every reachable hand that is not over, the
player to act has not acted yet this round.

### Step 4 extra: the review always has a hand to consider (not in Challenge)

```lean
theorem botHands_ne_nil_of_board (spot : RiverSpot) (h5 : spot.board.length = 5)
    (hd : spot.board.Nodup) (hhole : spot.hole.length ≤ 2) : spot.botHands ≠ []
```

Plain words: on a river board, whatever the human's two cards and the Bluff setting, the bot
can hold at least one hand of its betting set (324 value hands, at most 2 × 47 blocked). This
discharges the `spot.botHands ≠ []` condition of `review_worth` and
`review_call_best_iff_equity` in every real spot, so their examples on `exRiverSpot` now have
every condition proved instead of `#guard`ed. Worth adding to Challenge if you agree.

## Step 4: examples and rejected bad outputs

- `review_worth`, `review_lost`, `review_call_best_iff_equity`: instantiated on `exRiverSpot`
  with conditions proved (via `botHands_ne_nil_of_board`).
- `review_label_monotone`: a free call (`exFreeCallSpot`, the human has no chips left) lost
  nothing, so its label is at least as good as folding's in `exRiverSpot`; the `Frac.LE`
  condition is proved from `review_lost`.
- Rejected: a review that says folding is worth one big blind; one that counts the call worth
  per hand instead of per two hands; a grader that always reports nothing lost; a bot that
  always checks on the river; a ranking with a weaker hand first; a ranking that breaks a tie
  the wrong way; an engine that accepts every move and never changes the hand.
- `botDecide_river_follows_set` is instantiated on a real spot (`exRiverOpenState`, the red
  aces on 2c 7d Js Qh 9s at Bluff 33%) with every condition proved. For
  `review_hands_ne_nil` the "bot bet" condition on `exRiverHand` is checked by `#guard`
  (compiled code) and the example takes it as a hypothesis: the kernel cannot work out a real
  betting set, and I found no honest way around that.

## Diff-test numbers (step 6)

Run on commit 855d9fd, Linux x64 (WSL2), Node 22.21.1, Lean v4.35.0, seed 20261031, about 4
minutes, checkout clean (`dirty: false` in `results.json`):

| Check | Passed |
| --- | --- |
| Ranking, 100,000 random deals | 100,000 / 100,000 |
| Ranking, A-6 / T-A / heart-heavy deals | 2,000 / 2,000 each |
| Exact vs known hand, flop / turn / river | 30 / 30 each |
| Exact vs random hand (`countsFor`), turn, 45,540 outcomes | 20 / 20 |
| Exact vs random hand (`countsFor`), river, 990 outcomes | 60 / 60 |
| Flop estimate within 4 SE | 12 / 12, largest gap 1.17 SE |
| Preflop table within 4 SE | 36 / 36, largest gap 1.97 SE |

Deals: 106,000 ranking deals plus 30 + 30 + 30 + 20 + 60 + 12 + 36 = 218 equity spots; 11
checks, 0 failures. For Devom's job 3 (MVP §7): the "48 of 48, still needs including" line is
stale; the harness, cases and results are in `tests/diff/`; the 36 preflop checks are
"starting hand against a random hand" (the preflop table vs the library's Monte Carlo), not
hand against hand. Note: the Oct 31 run reported a largest preflop gap of 2.19 SE with the
same seed; this run gives 1.97 SE. Both pass; the difference may come from the library's
sampling on a different platform or from `data/preflop.json` having changed since then.

## Things to know

- Step 1 was merged to main (df6904a) before the "never merge" message arrived. Nothing else
  touched main. The remote branch `aarav/river-bot-link` (same content as 5b7e7d8) is a
  leftover from before the single-branch instruction; it can be deleted.
- To run the diff harness I installed Node 22 under `~/.local/node22` (official tarball,
  checksum verified) because WSL had no Node; nothing in the repo changed for that.
  `tests/node_modules` was created by `npm ci` from the committed lockfile.
- Comments fixed: RiverBench.lean no longer claims MVP §5 asks for "well under a second";
  River.lean's measurement date is Oct 31, 2026 (commit 6384ca5).
- New definitions a reviewer must trust: `cardId`, `RanksAbove` (BluffSpec.lean), `RunsWith`,
  `RunsTo` (EndsSpec.lean). Everything else in the statements already existed.
- Theorem names Devom's Session proofs may want: `review_hands_ne_nil`,
  `botHands_ne_nil_of_board`, `every_hand_ends`, `reachable_acted`, `step_measure`.

## How to check

```sh
git switch aarav/review-lost-comparator
cd engine && lake build && ../checks/audit.sh && lake comparator && lake check
```
