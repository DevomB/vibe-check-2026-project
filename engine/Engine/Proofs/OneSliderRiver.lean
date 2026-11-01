import Engine.Proofs.OneSlider
import Engine.Proofs.RiverBot

/-!
# One Risk slider, the river half: more Risk never turns a river bet into a check

`more_risk_never_folds_a_call` (`Engine/Proofs/OneSlider.lean`) covers the bot facing a bet.
This file covers the other place the slider acts: the river with no bet to face, where the
bot bets the hands in its river betting set and the set's bluff part grows with the Bluff
share that `Sliders.ofRisk` gives.

- `bluffCount_mono`: beside any number of value hands, the bluff count never falls as the
  Bluff share rises (plain arithmetic on the rounding formula).
- `more_bluff_never_checks_a_bet`: on a river board, with nothing to call and a bet allowed,
  if the bot bets at one setting it bets at every setting with a Bluff share at least as big.
  The value hands are the same; the bluffs at the smaller share are a tail of the bluffs at
  the bigger one (`mem_bettingSet_mono`).
- `more_risk_never_checks_a_bet`: the same along the slider, through `ofRisk_bluff_monotone`.

What to review: `Sliders.ofRisk`, `riverBettingSet`, `bluffCount`, `botDecide`, and the earlier
theorem `botDecide_river_follows_set`. The arithmetic lemma and the general theorem were
written by a helper session and checked here.
-/

/-- The bluff count never falls as the Bluff share rises, beside any number of value hands. -/
theorem bluffCount_mono (v : Nat) {b b' : Nat} (hb : b ≤ b') (hb' : b' < 100) :
    bluffCount v b ≤ bluffCount v b' := by
  unfold bluffCount
  have hD' : 0 < 2 * (100 - b') := by omega
  have hb100 : 0 < 100 - b := by omega
  rw [Nat.le_div_iff_mul_le hD']
  have h1 : (2 * v * b + (100 - b)) / (2 * (100 - b)) * (2 * (100 - b)) ≤ 2 * v * b + (100 - b) :=
    Nat.div_mul_le_self _ _
  have hbb : b * (100 - b') ≤ b' * (100 - b) := Nat.mul_le_mul hb (Nat.sub_le_sub_left hb 100)
  have h3 : (2 * v * b + (100 - b)) * (100 - b') ≤ (2 * v * b' + (100 - b')) * (100 - b) := by
    calc (2 * v * b + (100 - b)) * (100 - b')
        = 2 * v * (b * (100 - b')) + (100 - b) * (100 - b') := by rw [Nat.add_mul]; ac_rfl
      _ ≤ 2 * v * (b' * (100 - b)) + (100 - b') * (100 - b) := by
          rw [Nat.mul_comm (100 - b) (100 - b')]
          exact Nat.add_le_add_right (Nat.mul_le_mul_left _ hbb) _
      _ = (2 * v * b' + (100 - b')) * (100 - b) := by rw [Nat.add_mul]; ac_rfl
  have h4 := Nat.le_trans (Nat.mul_le_mul_right (100 - b') h1) h3
  have h5 : (2 * v * b + (100 - b)) / (2 * (100 - b)) * (2 * (100 - b)) * (100 - b') =
      (2 * v * b + (100 - b)) / (2 * (100 - b)) * (2 * (100 - b')) * (100 - b) := by ac_rfl
  rw [h5] at h4
  exact Nat.le_of_mul_le_mul_right h4 hb100

/-- The last `k` entries of a list are among its last `k'` entries when `k ≤ k'`. -/
theorem mem_drop_sub_of_le {α : Type} (l : List α) {k k' : Nat} (h : k ≤ k') :
    ∀ x ∈ l.drop (l.length - k), x ∈ l.drop (l.length - k') := by
  intro x hx
  have : l.drop (l.length - k) =
      (l.drop (l.length - k')).drop ((l.length - k) - (l.length - k')) := by
    rw [List.drop_drop]; congr 1; omega
  rw [this] at hx
  exact List.drop_subset _ _ hx

/-- A hand in the river betting set at Bluff `b` is in it at every Bluff `b' ≥ b` (below 100):
the value hands are the same, and the bluffs at `b` are a tail of the bluffs at `b'`. -/
theorem mem_bettingSet_mono (board : List Card) {b b' : Nat} (hb : b ≤ b') (hb' : b' < 100)
    (h : RankedHand)
    (hmem : h ∈ (riverBettingSet b board).value ++ (riverBettingSet b board).bluffs) :
    h ∈ (riverBettingSet b' board).value ++ (riverBettingSet b' board).bluffs := by
  simp only [riverBettingSet, List.mem_append] at hmem ⊢
  rcases hmem with hval | hbl
  · exact Or.inl hval
  · exact Or.inr (mem_drop_sub_of_le _ (bluffCount_mono _ hb hb') h hbl)

/-- **More Bluff never checks a bet.** On a river board, with nothing to call and a bet
allowed: if the bot bets its two cards at one setting, it bets them at every setting with a
Bluff share at least as big (and below 100). -/
theorem more_bluff_never_checks_a_bet (sl sl' : Sliders) (seed : Nat) (a b : Card)
    (board : List Card) (s : State) (h5 : board.length = 5) (h0 : s.toCall = 0)
    (hbet : ∃ n, Legal s (.raiseTo n)) (hb : sl.bluffPct ≤ sl'.bluffPct)
    (hb' : sl'.bluffPct < 100)
    (hc : ∃ n, (botDecide sl seed [a, b] board s).action = .raiseTo n) :
    ∃ n, (botDecide sl' seed [a, b] board s).action = .raiseTo n := by
  rw [(botDecide_river_follows_set sl seed a b board s h5 h0 hbet).1] at hc
  rw [(botDecide_river_follows_set sl' seed a b board s h5 h0 hbet).1]
  obtain ⟨h, hmem, hcards⟩ := hc
  exact ⟨h, mem_bettingSet_mono board hb hb' h hmem, hcards⟩

/-- **More Risk never checks a bet.** On a river board, with nothing to call and a bet allowed,
if the bot bets its two cards at Risk `r`, it bets them at every higher Risk `r'`: the value
hands are the same, and the bluffs only grow (`ofRisk_bluff_monotone`). -/
theorem more_risk_never_checks_a_bet (seed : Nat) (a b : Card) (board : List Card) (s : State)
    (h5 : board.length = 5) (h0 : s.toCall = 0) (hbet : ∃ n, Legal s (.raiseTo n))
    {r r' : Nat} (hr : r ≤ r')
    (hc : ∃ n, (botDecide (Sliders.ofRisk r) seed [a, b] board s).action = .raiseTo n) :
    ∃ n, (botDecide (Sliders.ofRisk r') seed [a, b] board s).action = .raiseTo n :=
  more_bluff_never_checks_a_bet _ _ seed a b board s h5 h0 hbet (ofRisk_bluff_monotone hr)
    (by have := ofRisk_bluff_le_60 r'; omega) hc

/-! ## Checks -/

-- The bluff count at the slider's two ends and the textbook point.
#guard bluffCount 324 0 == 0
#guard bluffCount 324 33 == 160
#guard bluffCount 324 60 == 486

/-- The river board of `exRiverView` (`Engine/Slider.lean`): A K 2 5 7, two hearts. -/
def boardAK257 : List Card :=
  [card 14 .spades, card 13 .diamonds, card 2 .clubs, card 5 .hearts, card 7 .hearts]

-- The direction the theorem allows, on a real board: queen-jack is the best no-pair hand, so
-- it is among the 486 bluffs at Risk 100 (Bluff 60%) but not among the 160 at Risk 50 (33%).
-- More Risk turned a check into a bet. The reverse, a hand bet at Risk 50 and checked at
-- Risk 100, is what the theorem rules out; `riverBets` decides these bets
-- (`botDecide_river_follows_set`). This is also why `botDecide_no_bet_off_river` leaves the
-- river out: with no bet to face, the two settings differ only there.
#guard riverBets (Sliders.ofRisk 100).bluffPct boardAK257 [card 12 .clubs, card 11 .diamonds] == true
#guard riverBets (Sliders.ofRisk 50).bluffPct boardAK257 [card 12 .clubs, card 11 .diamonds] == false
-- Eight-six is weak enough to be a bluff at both; two aces are a value hand at both.
#guard riverBets (Sliders.ofRisk 50).bluffPct boardAK257 [card 8 .clubs, card 6 .diamonds] == true
#guard riverBets (Sliders.ofRisk 50).bluffPct boardAK257 [card 14 .clubs, card 14 .hearts] == true

/-- That board with 100 in the pot, 450 behind each, and the bot to act with nothing to call. -/
def stateAK257 : State :=
  { stack := fun _ => 450, pot := 100, bet := fun _ => 0, lastRaise := 10, toAct := 1 }

/-- Every hypothesis met on that spot, and the forbidden shape rejected: the bot cannot bet
queen-jack at Risk 50 and check it at Risk 100. (It does the opposite, as the guards above
show, which the theorem allows.) -/
example (n : Nat) :
    ¬ ((botDecide (Sliders.ofRisk 50) 1 [card 12 .clubs, card 11 .diamonds] boardAK257
          stateAK257).action = .raiseTo n ∧
       (botDecide (Sliders.ofRisk 100) 1 [card 12 .clubs, card 11 .diamonds] boardAK257
          stateAK257).action = .check) := by
  rintro ⟨hbet50, hcheck100⟩
  obtain ⟨m, hm⟩ := more_risk_never_checks_a_bet (r := 50) (r' := 100) 1 _ _ boardAK257
    stateAK257 (by decide) (by decide) ⟨100, by decide⟩ (by decide) ⟨n, hbet50⟩
  rw [hm] at hcheck100
  cases hcheck100

/-- `ideal_river_set` on a real board with both hypotheses met: at Risk 50 the A K 2 5 7 board
has 324 value hands and 160 bluffs. -/
example : (riverBettingSet (Sliders.ofRisk 50).bluffPct boardAK257).value.length = 324 ∧
    (riverBettingSet (Sliders.ofRisk 50).bluffPct boardAK257).bluffs.length = 160 :=
  ideal_river_set boardAK257 (by decide) (by decide)

#print axioms more_bluff_never_checks_a_bet
#print axioms more_risk_never_checks_a_bet
