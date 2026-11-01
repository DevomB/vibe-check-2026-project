import Engine.Slider
import Engine.Proofs.BotRisk
import Engine.Proofs.BluffFrequency

/-!
# One Risk slider: what we prove about `Sliders.ofRisk`

The player sets one number, Risk (0 to 100). `Sliders.ofRisk` turns it into the bot's two
internal settings: caution (how heavily a lost chip counts; the `risk` field) and Bluff (the
bluff share of the river betting set). These theorems say what that mapping guarantees:

- Bluff never goes above 60 (`ofRisk_bluff_le_60`), so T7 `bluff_frequency` holds at every
  Risk.
- More Risk never bluffs less (`ofRisk_bluff_monotone`) and never weighs a lost chip more
  (`ofRisk_caution_antitone`).
- Facing a bet, more Risk never turns a call or raise into a fold
  (`more_risk_never_folds_a_call`).
- Risk 50 is the textbook setting: plain chip profit and a 33% bluff share
  (`ideal_is_textbook`), which on every river board is 160 bluffs beside 324 value hands
  (`ideal_river_set`).

Also here: the Risk number the bot quotes in its reason never changes its move
(`botDecide_action_shown`).

What to review: `Sliders.ofRisk`, `botDecide`, `Action.continues`, `riverBettingSet`, and the
earlier theorems `botDecide_risk_monotone` (T4) and `bluff_frequency` (T7).

None of this says the bot plays well. The 33% is the break-even bluff share against a
pot-sized bet in the one-street textbook model; the bot's earlier streets and its win-chance
estimate are not covered by that model.
-/

/-! ## The Risk quoted in a reason never changes the move -/

/-- Changing only the Risk number a view quotes leaves the move the same. -/
theorem decideView_action_shown (v : View) (c : Counts) (r : Option Nat) :
    (decideView { v with shownRisk := r } c).action = (decideView v c).action := by
  simp only [decideView, decideView.callOrFold, decideView.checkMove, riverOpening,
    riverBetOrCheck]
  split <;> (try split) <;> (try split) <;> (try split) <;> rfl

/-- The move `botDecide` makes does not depend on the Risk number it quotes. -/
theorem botDecide_action_shown (sl : Sliders) (seed : Nat) (hole board : List Card) (s : State)
    (shown : Option Nat) :
    (botDecide sl seed hole board s shown).action = (botDecide sl seed hole board s).action :=
  decideView_action_shown (viewOf sl hole board s) (countsFor seed hole board) shown

/-! ## The mapping -/

/-- At every Risk the bluff share is at most 60, the most `bluff_frequency` allows. -/
theorem ofRisk_bluff_le_60 (r : Nat) : (Sliders.ofRisk r).bluffPct ≤ 60 := by
  simp only [Sliders.ofRisk]
  split <;> simp only <;> omega

/-- More Risk never bluffs less. -/
theorem ofRisk_bluff_monotone {r r' : Nat} (h : r ≤ r') :
    (Sliders.ofRisk r).bluffPct ≤ (Sliders.ofRisk r').bluffPct := by
  simp only [Sliders.ofRisk]
  split <;> split <;> simp only <;> omega

/-- More Risk never weighs a lost chip more: the internal caution falls or stays. -/
theorem ofRisk_caution_antitone {r r' : Nat} (h : r ≤ r') :
    (Sliders.ofRisk r').risk ≤ (Sliders.ofRisk r).risk := by
  simp only [Sliders.ofRisk]
  split <;> split <;> simp only <;> omega

/-! ## Facing a bet, only caution matters -/

/-- Facing a bet, the move does not read Bluff: the same caution gives the same move at any
Bluff. -/
theorem decideView_facing_bet_bluff (v : View) (c : Counts) (k b b' : Nat) (hc : 0 < v.toCall) :
    (decideView { v with sliders := ⟨k, b⟩ } c).action =
      (decideView { v with sliders := ⟨k, b'⟩ } c).action := by
  simp only [decideView, decideView.callOrFold, hc, ↓reduceIte]
  split <;> (try split) <;> (try split) <;> rfl

/-- The same, for the whole bot. -/
theorem botDecide_facing_bet_bluff (k b b' seed : Nat) (hole board : List Card) (s : State)
    (hbet : 0 < s.toCall) :
    (botDecide ⟨k, b⟩ seed hole board s).action = (botDecide ⟨k, b'⟩ seed hole board s).action :=
  decideView_facing_bet_bluff (viewOf ⟨k, b'⟩ hole board s) (countsFor seed hole board) k b b' hbet

/-- **More Risk never folds a call.** Facing a bet in one spot (the same seed, cards, board
and chips), if the bot calls or raises at Risk `r`, it also calls or raises at every higher
Risk `r'`. -/
theorem more_risk_never_folds_a_call (seed : Nat) (hole board : List Card) (s : State)
    {r r' : Nat} (hr : r ≤ r') (hbet : 0 < s.toCall)
    (hc : (botDecide (Sliders.ofRisk r) seed hole board s).action.continues) :
    (botDecide (Sliders.ofRisk r') seed hole board s).action.continues := by
  -- Facing a bet the bot reads only caution (T4), and caution falls as Risk rises.
  have h1 : (botDecide ⟨(Sliders.ofRisk r).risk, (Sliders.ofRisk r).bluffPct⟩ seed hole board
      s).action.continues := hc
  have h2 : (botDecide ⟨(Sliders.ofRisk r').risk, (Sliders.ofRisk r).bluffPct⟩ seed hole board
      s).action.continues :=
    botDecide_risk_monotone (Sliders.ofRisk r).bluffPct seed hole board s
      (Sliders.ofRisk r').risk (Sliders.ofRisk r).risk (ofRisk_caution_antitone hr) h1
  rw [botDecide_facing_bet_bluff (Sliders.ofRisk r').risk (Sliders.ofRisk r).bluffPct
    (Sliders.ofRisk r').bluffPct seed hole board s hbet] at h2
  exact h2

/-! ## Risk 50 is the textbook setting -/

/-- Risk 50 is plain chip profit (caution 0) with a 33% bluff share. -/
theorem ideal_is_textbook : Sliders.ofRisk 50 = ⟨0, 33⟩ := by decide

/-- At Risk 50, on every river board with no card twice, the bot's betting set has 324 value
hands and 160 bluffs: 160 of 484 bets are bluffs, the whole number of hands nearest to a
33% share. -/
theorem ideal_river_set (board : List Card) (h5 : board.length = 5) (hd : board.Nodup) :
    (riverBettingSet (Sliders.ofRisk 50).bluffPct board).value.length = 324 ∧
    (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs.length = 160 := by
  have h := bluff_frequency (Sliders.ofRisk 50).bluffPct board h5 hd (ofRisk_bluff_le_60 50)
  have h33 : (Sliders.ofRisk 50).bluffPct = 33 := rfl
  rw [h33] at h ⊢
  simp only [NearestWhole] at h
  exact ⟨h.1, by omega⟩

/-! ## Checks: the statements can hold, and reject bad mappings -/

-- The mapping at the five marked points, and the direction of each number.
#guard (List.range 101).all fun r => (Sliders.ofRisk r).bluffPct ≤ 60
#guard (List.range 100).all fun r =>
  (Sliders.ofRisk r).bluffPct ≤ (Sliders.ofRisk (r + 1)).bluffPct
    && (Sliders.ofRisk (r + 1)).risk ≤ (Sliders.ofRisk r).risk

/-- `more_risk_never_folds_a_call` on a real spot with every condition met: at the start of a
hand the small blind owes 5 (`exStart`), and with nine-two offsuit the bot calls at Risk 26
and so at Risk 100 too. -/
example : (botDecide (Sliders.ofRisk 100) 1 [card 9 .spades, card 2 .hearts] [] exStart).action.continues :=
  more_risk_never_folds_a_call 1 [card 9 .spades, card 2 .hearts] [] exStart (r := 26)
    (by decide) (by decide) (by decide)

/-- A known-bad mapping: more Risk means more caution and fewer bluffs, and the bluff share
starts at 100. The statements reject it. -/
def badMap (r : Nat) : Sliders := ⟨r, 100 - r⟩

example : ¬ (badMap 0).bluffPct ≤ 60 := by decide
example : ¬ (badMap 0).bluffPct ≤ (badMap 1).bluffPct := by decide
example : ¬ (badMap 1).risk ≤ (badMap 0).risk := by decide

#print axioms more_risk_never_folds_a_call
#print axioms ideal_river_set
