import Engine.Proofs.OneSlider
import Engine.Proofs.RiverBot

/-!
# One Risk slider, the river half: more Risk never turns a river bet into a check

`more_risk_never_folds_a_call` (`Engine/Proofs/OneSlider.lean`) covers the bot facing a bet.
This file covers the other place the slider acts: the river with no bet to face, where the
bot bets the hands in its river betting set and the set's bluff part grows with the Bluff
share that `Sliders.ofRisk` gives.

- `bluffCount_step`, `bluffCount_mono_60`: beside the 324 value hands of a river board, the
  bluff count never falls as the Bluff share rises through 0 to 60. Checked one step at a
  time by `decide` (60 steps), then chained.
- `more_risk_never_checks_a_bet`: on a river board with no card twice, with nothing to call
  and a bet allowed, if the bot bets at Risk `r` it bets at every higher Risk `r'`. The value
  hands are the same at every Risk; the bluffs at `r` are a tail of the bluffs at `r'`.

What to review: `Sliders.ofRisk`, `riverBettingSet`, `bluffCount`, `botDecide`, and the earlier
theorems `botDecide_river_follows_set` and `length_rankRiverHands`.
-/

/-- Beside 324 value hands, one more point of Bluff share never means fewer bluffs, for every
share the slider can set. -/
theorem bluffCount_step : ∀ b, b < 60 → bluffCount 324 b ≤ bluffCount 324 (b + 1) := by decide

/-- Beside 324 value hands, a bigger Bluff share (up to 60) never means fewer bluffs. -/
theorem bluffCount_mono_60 {b b' : Nat} (h : b ≤ b') (hb' : b' ≤ 60) :
    bluffCount 324 b ≤ bluffCount 324 b' := by
  obtain ⟨d, rfl⟩ : ∃ d, b' = b + d := ⟨b' - b, by omega⟩
  induction d with
  | zero => exact Nat.le_refl _
  | succ d ih => exact Nat.le_trans (ih (by omega) (by omega)) (bluffCount_step (b + d) (by omega))

/-- **More Risk never checks a bet.** On a river board (five different cards), with nothing to
call and a bet allowed, if the bot bets its two cards at Risk `r`, it bets them at every
higher Risk `r'`: the value hands are the same, and the bluffs only grow. -/
theorem more_risk_never_checks_a_bet (seed : Nat) (a b : Card) (board : List Card) (s : State)
    (h5 : board.length = 5) (hd : board.Nodup) (h0 : s.toCall = 0)
    (hbet : ∃ n, Legal s (.raiseTo n)) {r r' : Nat} (hr : r ≤ r')
    (hc : ∃ n, (botDecide (Sliders.ofRisk r) seed [a, b] board s).action = .raiseTo n) :
    ∃ n, (botDecide (Sliders.ofRisk r') seed [a, b] board s).action = .raiseTo n := by
  rw [(botDecide_river_follows_set (Sliders.ofRisk r) seed a b board s h5 h0 hbet).1] at hc
  rw [(botDecide_river_follows_set (Sliders.ofRisk r') seed a b board s h5 h0 hbet).1]
  obtain ⟨h, hmem, hcards⟩ := hc
  refine ⟨h, ?_, hcards⟩
  have hn := length_rankRiverHands h5 hd
  have hv : valueCount 1081 = 324 := by decide
  have hk : bluffCount 324 (Sliders.ofRisk r).bluffPct ≤ bluffCount 324 (Sliders.ofRisk r').bluffPct :=
    bluffCount_mono_60 (ofRisk_bluff_monotone hr) (ofRisk_bluff_le_60 r')
  simp only [riverBettingSet, hn, hv, List.mem_append] at hmem ⊢
  rcases hmem with hval | hbl
  · exact Or.inl hval
  · right
    -- The bluffs at `r` are the last `k` ranked hands, the bluffs at `r'` the last `k' ≥ k`.
    have hdd := List.drop_drop (l := rankRiverHands board)
      (j := 1081 - bluffCount 324 (Sliders.ofRisk r').bluffPct)
      (i := (1081 - bluffCount 324 (Sliders.ofRisk r).bluffPct) -
        (1081 - bluffCount 324 (Sliders.ofRisk r').bluffPct))
    rw [show 1081 - bluffCount 324 (Sliders.ofRisk r').bluffPct +
        ((1081 - bluffCount 324 (Sliders.ofRisk r).bluffPct) -
          (1081 - bluffCount 324 (Sliders.ofRisk r').bluffPct)) =
        1081 - bluffCount 324 (Sliders.ofRisk r).bluffPct by omega] at hdd
    rw [← hdd] at hbl
    exact List.drop_subset _ _ hbl

/-! ## Checks -/

-- The bluff count at the slider's two ends and the textbook point.
#guard bluffCount 324 0 == 0
#guard bluffCount 324 33 == 160
#guard bluffCount 324 60 == 486

/-- The statement rejects a bot whose river bets shrink with Risk: one that bet at Risk 50 and
checked at Risk 100 would contradict it. (Stated about the betting set, which decides those
bets: eight-six is a bluff on this board at Risk 100 but not at Risk 50, the other way round
from what the theorem forbids, and so is allowed.) -/
example : riverBets (Sliders.ofRisk 100).bluffPct exBoard [card 8 .clubs, card 6 .diamonds] = true →
    ¬ (riverBets (Sliders.ofRisk 100).bluffPct exBoard [card 8 .clubs, card 6 .diamonds] = false) := by
  intro h h'; rw [h] at h'; cases h'

#print axioms more_risk_never_checks_a_bet
