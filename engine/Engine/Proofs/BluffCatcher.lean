import Engine.Proofs.BluffCatcherSpec
import Engine.Proofs.Review
import Engine.Proofs.OneSliderRiver

/-!
# The bluff catcher on the river (game theory, part 1)

The spec, in plain words, is in `Engine/Proofs/BluffCatcherSpec.lean`. These theorems say:

1. `bluff_catcher_call_total`: with a bluff catcher, calling wins `prize` per bluff and loses
   `cost` per value hand. Nothing else counts.
2. `bluff_catcher_indifferent`: for any bet size, calling and folding are worth the same
   exactly when bluffs × prize = value hands × cost.
3. `one_third_bluffs_indifferent`: for a pot-sized bet, that is exactly when one bet in three
   is a bluff. With more bluffs, calling is better (`more_bluffs_call_better`). With fewer,
   folding is better (`fewer_bluffs_fold_better`).
4. `review_both_best_iff_one_third`: the app's review grades both call and fold Best exactly
   when one third of the bot hands you do not block are bluffs.
5. The real bot at Risk 50: its river set has 324 value hands and 160 bluffs, two short of
   the 162 that one third needs (`risk50_two_bluffs_short`). So, before your own cards
   remove any hands, a bluff catcher loses a little by calling a pot-sized bet: 1/121 of the
   bet per decision on average (`risk50_bluff_catcher_call_loses`). No whole-number Bluff
   setting gives exactly one third (`no_bluff_setting_is_exact`), and 33% is the closest
   (`bluff_33_is_closest`).

Your own two cards change the counts. On the A♠ K♥ 2♣ 5♦ 7♣ board at Risk 50, T♣ T♦ removes
proportionally more bluffs (312 value, 152 bluffs left) and calling a pot-sized bet loses,
while Q♣ T♣ removes proportionally more value hands (309 value, 156 bluffs left) and calling
wins. See the `#guard` checks at the
end of this file.
-/

/-! ## The arithmetic of a bluff catcher -/

/-- Against hands that all beat yours, calling loses `2 × cost` half-chips each. -/
theorem sum_callResult_value (mine : List Nat) (prize cost : Nat) :
    ∀ l : List RankedHand, (∀ h ∈ l, mine < h.score) →
      (l.map (callResult mine prize cost)).sum = -(2 * (cost : Int)) * l.length
  | [], _ => by simp
  | h :: t, hl => by
    have hh : mine < h.score := hl h (by simp)
    have ih := sum_callResult_value mine prize cost t (fun x hx => hl x (by simp [hx]))
    simp only [List.map_cons, List.sum_cons, ih, callResult, hh, ↓reduceIte, List.length_cons]
    push_cast; grind

/-- Against hands that yours all beats, calling wins `2 × prize` half-chips each. -/
theorem sum_callResult_bluffs (mine : List Nat) (prize cost : Nat) :
    ∀ l : List RankedHand, (∀ h ∈ l, h.score < mine) →
      (l.map (callResult mine prize cost)).sum = 2 * (prize : Int) * l.length
  | [], _ => by simp
  | h :: t, hl => by
    have hh : h.score < mine := hl h (by simp)
    have ih := sum_callResult_bluffs mine prize cost t (fun x hx => hl x (by simp [hx]))
    simp only [List.map_cons, List.sum_cons, ih, callResult, List.lt_asymm hh, hh, ↓reduceIte,
      List.length_cons]
    push_cast; grind

/-- **What calling is worth with a bluff catcher.** In half-chips (the review's unit), calling
wins `2 × prize` against each bluff and loses `2 × cost` against each value hand. -/
theorem bluff_catcher_call_total (mine : List Nat) (value bluffs : List RankedHand)
    (prize cost : Nat) (hc : CatchesBluffs mine value bluffs) :
    choiceTotal (value ++ bluffs) mine prize cost .call =
      2 * ((bluffs.length : Int) * prize - (value.length : Int) * cost) := by
  simp only [choiceTotal, List.map_append, List.sum_append,
    sum_callResult_value mine prize cost value hc.1, sum_callResult_bluffs mine prize cost bluffs hc.2]
  grind

/-- **When calling and folding are worth the same, for any bet.** With a bluff catcher, calling
pays `cost` chips to win `prize` chips (the pot, including the bet). Calling and folding are
worth the same exactly when bluffs × prize = value hands × cost. -/
theorem bluff_catcher_indifferent (mine : List Nat) (value bluffs : List RankedHand)
    (prize cost : Nat) (hc : CatchesBluffs mine value bluffs) :
    choiceTotal (value ++ bluffs) mine prize cost .call =
        choiceTotal (value ++ bluffs) mine prize cost .fold ↔
      bluffs.length * prize = value.length * cost := by
  rw [bluff_catcher_call_total mine value bluffs prize cost hc]
  simp only [choiceTotal]
  constructor <;> intro h
  · have : (bluffs.length : Int) * prize = value.length * cost := by omega
    exact_mod_cast this
  · have : ((bluffs.length * prize : Nat) : Int) = (value.length * cost : Nat) := by rw [h]
    push_cast at this; omega

/-- **One bluff in three makes calling and folding worth the same (pot-sized bet).** The bot
bets `cost` into a pot of `cost`, so calling pays `cost` to win `2 × cost`. Then a bluff
catcher's call and fold are worth the same exactly when bluffs are one third of the bot's
bets. -/
theorem one_third_bluffs_indifferent (mine : List Nat) (value bluffs : List RankedHand)
    (cost : Nat) (hcost : 0 < cost) (hc : CatchesBluffs mine value bluffs) :
    choiceTotal (value ++ bluffs) mine (2 * cost) cost .call =
        choiceTotal (value ++ bluffs) mine (2 * cost) cost .fold ↔
      3 * bluffs.length = value.length + bluffs.length := by
  rw [bluff_catcher_indifferent mine value bluffs (2 * cost) cost hc]
  constructor <;> intro h
  · have : (2 * bluffs.length) * cost = value.length * cost := by grind
    have := Nat.eq_of_mul_eq_mul_right hcost this
    omega
  · have : 2 * bluffs.length = value.length := by omega
    grind

/-- **More than one bluff in three: calling is better** (pot-sized bet, bluff catcher). -/
theorem more_bluffs_call_better (mine : List Nat) (value bluffs : List RankedHand)
    (cost : Nat) (hcost : 0 < cost) (hc : CatchesBluffs mine value bluffs) :
    choiceTotal (value ++ bluffs) mine (2 * cost) cost .fold <
        choiceTotal (value ++ bluffs) mine (2 * cost) cost .call ↔
      value.length + bluffs.length < 3 * bluffs.length := by
  rw [bluff_catcher_call_total mine value bluffs (2 * cost) cost hc]
  simp only [choiceTotal]
  have hc' : (0 : Int) < cost := by omega
  constructor <;> intro h
  · have : (value.length : Int) * cost < (2 * bluffs.length) * cost := by push_cast at h ⊢; grind
    have := Int.lt_of_mul_lt_mul_right this (Int.le_of_lt hc')
    omega
  · have : (value.length : Int) < 2 * bluffs.length := by omega
    have := Int.mul_lt_mul_of_pos_right this hc'
    push_cast; grind

/-- **Fewer than one bluff in three: folding is better** (pot-sized bet, bluff catcher). -/
theorem fewer_bluffs_fold_better (mine : List Nat) (value bluffs : List RankedHand)
    (cost : Nat) (hcost : 0 < cost) (hc : CatchesBluffs mine value bluffs) :
    choiceTotal (value ++ bluffs) mine (2 * cost) cost .call <
        choiceTotal (value ++ bluffs) mine (2 * cost) cost .fold ↔
      3 * bluffs.length < value.length + bluffs.length := by
  rw [bluff_catcher_call_total mine value bluffs (2 * cost) cost hc]
  simp only [choiceTotal]
  have hc' : (0 : Int) < cost := by omega
  constructor <;> intro h
  · have : (2 * bluffs.length : Int) * cost < (value.length) * cost := by push_cast at h ⊢; grind
    have := Int.lt_of_mul_lt_mul_right this (Int.le_of_lt hc')
    omega
  · have : (2 * bluffs.length : Int) < value.length := by omega
    have := Int.mul_lt_mul_of_pos_right this hc'
    push_cast; grind

/-! ## The app's review -/

/-- The hands the review counts are the unblocked value hands, then the unblocked bluffs. -/
theorem botHands_eq_value_append_bluffs (spot : RiverSpot) :
    spot.botHands = spot.valueHands ++ spot.bluffHands := by
  simp [RiverSpot.botHands, RiverSpot.valueHands, RiverSpot.bluffHands, List.filter_append]

/-- **The review agrees: both choices are Best exactly at one bluff in three.** The bot opened
the river with a pot-sized bet (the pot, with the bet, is twice the bet) that you can afford,
and your hand catches bluffs against the bot hands you do not block. Then the review grades
both call and fold Best exactly when one third of those hands are bluffs. -/
theorem review_both_best_iff_one_third (spot : RiverSpot)
    (hpot : spot.pot = 2 * spot.toCall) (hafford : spot.toCall ≤ spot.stack)
    (hbet : 0 < spot.toCall)
    (hc : CatchesBluffs spot.myScore spot.valueHands spot.bluffHands) :
    ((reviewRiver spot .call).label = .best ∧ (reviewRiver spot .fold).label = .best) ↔
      3 * spot.bluffHands.length = spot.valueHands.length + spot.bluffHands.length := by
  have hcost : spot.cost = spot.toCall := by simp [RiverSpot.cost]; omega
  have hprize : spot.prize = 2 * spot.toCall := by simp [RiverSpot.prize, hcost, hpot]
  rw [review_best_iff, review_best_iff]
  simp only [RiverChoice.other, RiverSpot.total, botHands_eq_value_append_bluffs, hcost, hprize]
  rw [← one_third_bluffs_indifferent spot.myScore spot.valueHands spot.bluffHands spot.toCall hbet hc]
  constructor
  · intro ⟨h1, h2⟩; omega
  · intro h; omega

/-! ## The real bot at Risk 50 -/

/-- **Risk 50 is two bluffs short of one third.** On every river board the Risk 50 set has
324 value hands and 160 bluffs. One third would need 162 bluffs (value = 2 × bluffs). -/
theorem risk50_two_bluffs_short (board : List Card) (h5 : board.length = 5)
    (hd : board.Nodup) :
    (riverBettingSet (Sliders.ofRisk 50).bluffPct board).value.length =
      2 * (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs.length + 4 := by
  obtain ⟨hv, hb⟩ := ideal_river_set board h5 hd
  rw [hv, hb]

/-- **So at Risk 50 a bluff catcher loses a little by calling a pot-sized bet.** Against the
whole Risk 50 set (before your own cards remove any hands), calling totals `-8 × cost`
half-chips over the 484 hands: on average you lose `cost / 121` chips, under 1% of the bet. -/
theorem risk50_bluff_catcher_call_loses (board : List Card) (h5 : board.length = 5)
    (hd : board.Nodup) (mine : List Nat) (cost : Nat)
    (hc : CatchesBluffs mine (riverBettingSet (Sliders.ofRisk 50).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs) :
    choiceTotal ((riverBettingSet (Sliders.ofRisk 50).bluffPct board).value ++
        (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs) mine (2 * cost) cost .call =
      -8 * (cost : Int) := by
  obtain ⟨hv, hb⟩ := ideal_river_set board h5 hd
  rw [bluff_catcher_call_total _ _ _ _ _ hc, hv, hb]
  push_cast; grind

/-- **No Bluff setting gives exactly one third.** Beside the 324 value hands of every river
set, no whole-number Bluff share from 0 to 60 gives 162 bluffs. -/
theorem no_bluff_setting_is_exact : ∀ b ≤ 60, 2 * bluffCount 324 b ≠ 324 := by
  decide

/-- **33% is the closest.** Every Bluff share from 0 to 60 is at least 4 hands away from
value = 2 × bluffs, and 33% (Risk 50) is exactly 4 away. -/
theorem bluff_33_is_closest :
    (∀ b ≤ 60, 4 ≤ ((324 : Int) - 2 * bluffCount 324 b).natAbs) ∧
      ((324 : Int) - 2 * bluffCount 324 33).natAbs = 4 := by
  decide

/-! ## Examples: every hypothesis met, and wrong answers rejected

Two value hands and one bluff: exactly one bet in three is a bluff. A hand scoring `[3]`
catches bluffs. The bot bets 100 into 100. -/

-- Every hypothesis of `one_third_bluffs_indifferent` holds here, and calling and folding are
-- worth the same.
example : choiceTotal ([exValueHand, exValueHand] ++ [exBluffHand]) [3] (2 * 100) 100 .call =
    choiceTotal ([exValueHand, exValueHand] ++ [exBluffHand]) [3] (2 * 100) 100 .fold :=
  (one_third_bluffs_indifferent [3] [exValueHand, exValueHand] [exBluffHand] 100 (by decide)
    (by decide)).mpr (by decide)

-- One value hand and one bluff (half are bluffs): calling is strictly better, not equal.
example : choiceTotal ([exValueHand] ++ [exBluffHand]) [3] (2 * 100) 100 .fold <
    choiceTotal ([exValueHand] ++ [exBluffHand]) [3] (2 * 100) 100 .call :=
  (more_bluffs_call_better [3] [exValueHand] [exBluffHand] 100 (by decide) (by decide)).mpr
    (by decide)
example : ¬ choiceTotal ([exValueHand] ++ [exBluffHand]) [3] (2 * 100) 100 .call =
    choiceTotal ([exValueHand] ++ [exBluffHand]) [3] (2 * 100) 100 .fold := by decide

-- Three value hands and one bluff (a quarter are bluffs): folding is strictly better.
example : choiceTotal ([exValueHand, exValueHand, exValueHand] ++ [exBluffHand]) [3]
      (2 * 100) 100 .call <
    choiceTotal ([exValueHand, exValueHand, exValueHand] ++ [exBluffHand]) [3]
      (2 * 100) 100 .fold :=
  (fewer_bluffs_fold_better [3] [exValueHand, exValueHand, exValueHand] [exBluffHand] 100
    (by decide) (by decide)).mpr (by decide)

-- Why the bluff-catcher condition is needed: a hand scoring `[7]` beats the value hands too.
-- At one bluff in three it is not indifferent at all: calling wins every time.
example : ¬ CatchesBluffs [7] [exValueHand, exValueHand] [exBluffHand] := by decide
example : choiceTotal ([exValueHand, exValueHand] ++ [exBluffHand]) [7] (2 * 100) 100 .fold <
    choiceTotal ([exValueHand, exValueHand] ++ [exBluffHand]) [7] (2 * 100) 100 .call := by
  decide

/-! ## The real bot, on a real board (compiled checks)

The kernel cannot evaluate the real river ranking (it is built with well-founded recursion),
so these use `#guard`, which runs the compiled code. Board: A♠ K♥ 2♣ 5♦ 7♣, Risk 50, the bot
bets 100 into 100. -/

/-- The real board for the checks below. -/
def bcBoard : List Card :=
  [card 14 .spades, card 13 .hearts, card 2 .clubs, card 5 .diamonds, card 7 .clubs]

/-- A review spot on `bcBoard`: the bot bets 100 into 100 at Risk 50, and you hold `hole`. -/
def bcSpot (hole : List Card) : RiverSpot :=
  { board := bcBoard, hole, pot := 200, toCall := 100, stack := 400,
    bluffPct := (Sliders.ofRisk 50).bluffPct }

-- Before your cards remove any: 324 value hands and 160 bluffs (`risk50_two_bluffs_short`).
#guard (riverBettingSet 33 bcBoard).value.length == 324
#guard (riverBettingSet 33 bcBoard).bluffs.length == 160

-- T♣ T♦ catches bluffs here. It removes 12 value hands and 8 bluffs: 312 and 152 remain, fewer
-- than one in three are bluffs, so folding is better and the review grades only fold Best.
#guard decide (CatchesBluffs (bcSpot [card 10 .clubs, card 10 .diamonds]).myScore
  (bcSpot [card 10 .clubs, card 10 .diamonds]).valueHands
  (bcSpot [card 10 .clubs, card 10 .diamonds]).bluffHands)
#guard (bcSpot [card 10 .clubs, card 10 .diamonds]).valueHands.length == 312
#guard (bcSpot [card 10 .clubs, card 10 .diamonds]).bluffHands.length == 152
#guard (reviewRiver (bcSpot [card 10 .clubs, card 10 .diamonds]) .fold).label == .best
#guard (reviewRiver (bcSpot [card 10 .clubs, card 10 .diamonds]) .call).label != .best

-- Q♣ T♣ also catches bluffs. It removes 15 value hands and 4 bluffs: 309 and 156 remain, more
-- than one in three, so calling is better and the review grades only call Best.
#guard decide (CatchesBluffs (bcSpot [card 12 .clubs, card 10 .clubs]).myScore
  (bcSpot [card 12 .clubs, card 10 .clubs]).valueHands
  (bcSpot [card 12 .clubs, card 10 .clubs]).bluffHands)
#guard (bcSpot [card 12 .clubs, card 10 .clubs]).valueHands.length == 309
#guard (bcSpot [card 12 .clubs, card 10 .clubs]).bluffHands.length == 156
#guard (reviewRiver (bcSpot [card 12 .clubs, card 10 .clubs]) .call).label == .best
#guard (reviewRiver (bcSpot [card 12 .clubs, card 10 .clubs]) .fold).label != .best

#print axioms one_third_bluffs_indifferent
#print axioms review_both_best_iff_one_third
#print axioms risk50_bluff_catcher_call_loses
