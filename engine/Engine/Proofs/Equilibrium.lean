import Engine.Proofs.EquilibriumSpec
import Engine.Proofs.BluffCatcher
import Engine.Proofs.RiverBot

/-!
# The bot's side of the river, and the river equilibrium (game theory, part 2)

The spec, in plain words, is in `Engine/Proofs/EquilibriumSpec.lean`. These theorems say:

1. `bluff_total`: a bluff wins the pot for each fold and loses the bet for each call.
2. `bluff_breaks_even_iff`: for any bet size, a bluff breaks even exactly when calls × bet =
   folds × pot.
3. `half_calls_bluff_breaks_even`: for a pot-sized bet, that is exactly when you call half the
   time. Call more and bluffs lose (`more_calls_bluff_loses`); call less and they win
   (`fewer_calls_bluff_wins`).
4. `value_bet_never_worse`: betting a value hand never gains less than checking it.
5. `river_equilibrium_iff`: with a bluff catcher and a pot-sized bet, the river is in
   equilibrium exactly when one bet in three is a bluff and you call half the time.
6. `bot_river_bet_is_pot_sized`: the real bot (`botDecide`) bets exactly the pot when it opens
   the river with a bet and the pot is a legal size. So these results apply to its bets.
-/

/-! ## Counting answers -/

/-- Every answer is a call or a fold. -/
theorem callCount_add_foldCount (answers : List RiverChoice) :
    callCount answers + answers.count .fold = answers.length := by
  induction answers with
  | nil => rfl
  | cons a t ih =>
    cases a <;> simp_all [callCount] <;> omega

/-! ## A bluff -/

/-- **What a bluff wins.** Betting a bluff of `bet` into `pot` wins the pot for each fold and
loses the bet for each call, compared with checking it. -/
theorem bluff_total (answers : List RiverChoice) (pot bet : Nat) :
    bluffTotal answers pot bet =
      (answers.count .fold : Int) * pot - (callCount answers : Int) * bet := by
  induction answers with
  | nil => simp [bluffTotal, callCount]
  | cons a t ih =>
    simp only [bluffTotal, callCount] at ih ⊢
    cases a <;> simp [bluffGain, ih] <;> grind

/-- **When a bluff breaks even, for any bet.** It gains nothing over checking exactly when
calls × bet = folds × pot. -/
theorem bluff_breaks_even_iff (answers : List RiverChoice) (pot bet : Nat) :
    bluffTotal answers pot bet = 0 ↔ callCount answers * bet = answers.count .fold * pot := by
  rw [bluff_total]
  constructor <;> intro h
  · have : ((callCount answers : Int)) * bet = (answers.count .fold : Int) * pot := by omega
    exact_mod_cast this
  · have : ((callCount answers * bet : Nat) : Int) = (answers.count .fold * pot : Nat) := by rw [h]
    push_cast at this; omega

/-- **Calling half the time makes a pot-sized bluff break even.** The bot bets `pot` into
`pot`. Its bluff gains nothing over checking exactly when you call with half of your hands. -/
theorem half_calls_bluff_breaks_even (answers : List RiverChoice) (pot : Nat) (hpot : 0 < pot) :
    bluffTotal answers pot pot = 0 ↔ 2 * callCount answers = answers.length := by
  rw [bluff_breaks_even_iff]
  have hsum := callCount_add_foldCount answers
  constructor <;> intro h
  · have := Nat.eq_of_mul_eq_mul_right hpot h
    omega
  · have : callCount answers = answers.count .fold := by omega
    rw [this]

/-- **Call more than half the time, and a pot-sized bluff loses chips.** -/
theorem more_calls_bluff_loses (answers : List RiverChoice) (pot : Nat) (hpot : 0 < pot) :
    bluffTotal answers pot pot < 0 ↔ answers.length < 2 * callCount answers := by
  rw [bluff_total]
  have hsum := callCount_add_foldCount answers
  have hp : (0 : Int) < pot := by omega
  constructor <;> intro h
  · have h' : (answers.count .fold : Int) * pot < (callCount answers : Int) * pot := by omega
    have := Int.lt_of_mul_lt_mul_right h' (Int.le_of_lt hp)
    omega
  · have h' : (answers.count .fold : Int) < callCount answers := by omega
    have := Int.mul_lt_mul_of_pos_right h' hp
    omega

/-- **Call less than half the time, and a pot-sized bluff wins chips.** -/
theorem fewer_calls_bluff_wins (answers : List RiverChoice) (pot : Nat) (hpot : 0 < pot) :
    0 < bluffTotal answers pot pot ↔ 2 * callCount answers < answers.length := by
  rw [bluff_total]
  have hsum := callCount_add_foldCount answers
  have hp : (0 : Int) < pot := by omega
  constructor <;> intro h
  · have h' : (callCount answers : Int) * pot < (answers.count .fold : Int) * pot := by omega
    have := Int.lt_of_mul_lt_mul_right h' (Int.le_of_lt hp)
    omega
  · have h' : (callCount answers : Int) < answers.count .fold := by omega
    have := Int.mul_lt_mul_of_pos_right h' hp
    omega

/-! ## A value hand -/

/-- **Betting a value hand is never worse than checking it.** It gains the bet for each call
and nothing for each fold. -/
theorem value_bet_never_worse (answers : List RiverChoice) (bet : Nat) :
    valueTotal answers bet = (callCount answers : Int) * bet ∧ 0 ≤ valueTotal answers bet := by
  have key : valueTotal answers bet = (callCount answers : Int) * bet := by
    induction answers with
    | nil => simp [valueTotal, callCount]
    | cons a t ih =>
      simp only [valueTotal, callCount] at ih ⊢
      cases a <;> simp [valueGain, ih] <;> grind
  refine ⟨key, ?_⟩
  rw [key]
  exact Int.mul_nonneg (by omega) (by omega)

/-! ## Both sides together -/

/-- **The river equilibrium.** You hold a bluff catcher and the bot bets `pot` into `pot`.
Neither of you can gain by changing your own play alone exactly when one of the bot's bets in
three is a bluff and you call with half of your hands. -/
theorem river_equilibrium_iff (mine : List Nat) (value bluffs : List RankedHand)
    (answers : List RiverChoice) (pot : Nat) (hpot : 0 < pot)
    (hc : CatchesBluffs mine value bluffs) :
    RiverEquilibrium mine value bluffs answers pot ↔
      3 * bluffs.length = value.length + bluffs.length ∧
        2 * callCount answers = answers.length := by
  unfold RiverEquilibrium
  rw [one_third_bluffs_indifferent mine value bluffs pot hpot hc,
    half_calls_bluff_breaks_even answers pot hpot]
  have := (value_bet_never_worse answers pot).2
  constructor
  · intro ⟨h1, h2, _⟩; exact ⟨h1, h2⟩
  · intro ⟨h1, h2⟩; exact ⟨h1, h2, this⟩

/-! ## The real bot bets the pot -/

/-- **The bot's river bet is pot-sized.** On the river with nothing to call, if the bot bets
(street total `n`) and the pot-sized total, its street bet plus the pot it can win, is a legal
size, then `n` is exactly that pot-sized total. (When the pot is not a legal size, the bot
bets the nearest legal size instead: all-in if it has less than the pot.) -/
theorem bot_river_bet_is_pot_sized (sl : Sliders) (seed : Nat) (hole board : List Card)
    (s : State) (shown : Option Nat) (h5 : board.length = 5) (h0 : s.toCall = 0)
    (lo hi : Nat) (hr : s.raiseBounds = some (lo, hi))
    (hlo : lo ≤ s.bet s.toAct + s.potToWin) (hhi : s.bet s.toAct + s.potToWin ≤ hi)
    (n : Nat) (hbet : (botDecide sl seed hole board s shown).action = .raiseTo n) :
    n = s.bet s.toAct + s.potToWin := by
  have hclamp : clampTo (s.bet s.toAct + s.potToWin) lo hi = s.bet s.toAct + s.potToWin := by
    simp only [clampTo]; omega
  simp only [botDecide, decideWithCounts, decideView, viewOf, h0, h5] at hbet
  simp only [Nat.lt_irrefl, ↓reduceIte, riverOpening] at hbet
  split at hbet <;> simp only [riverBetOrCheck, hr, View.potBetTarget] at hbet
  all_goals first
    | (injection hbet with h; rw [← h, hclamp])
    | cases hbet

/-! ## Examples: every hypothesis met, and wrong answers rejected

The made-up hands of part 1: two value hands and one bluff (one bet in three is a bluff). You
hold a hand scoring `[3]`, which catches bluffs. The bot bets 100 into 100. -/

-- You call with one hand and fold with the other: the river is in equilibrium.
example : RiverEquilibrium [3] [exValueHand, exValueHand] [exBluffHand] [.call, .fold] 100 :=
  (river_equilibrium_iff [3] [exValueHand, exValueHand] [exBluffHand] [.call, .fold] 100
    (by decide) (by decide)).mpr (by decide)

-- If you always call, the bot's bluffs lose, so the bot would gain by checking them instead:
-- not an equilibrium.
example : ¬ RiverEquilibrium [3] [exValueHand, exValueHand] [exBluffHand] [.call, .call] 100 :=
  fun h => absurd ((river_equilibrium_iff [3] [exValueHand, exValueHand] [exBluffHand]
    [.call, .call] 100 (by decide) (by decide)).mp h).2 (by decide)
example : bluffTotal [.call, .call] 100 100 < 0 :=
  (more_calls_bluff_loses [.call, .call] 100 (by decide)).mpr (by decide)

-- If the bot bluffs half its bets, you gain by always calling: not an equilibrium, even when
-- you call half the time.
example : ¬ RiverEquilibrium [3] [exValueHand] [exBluffHand] [.call, .fold] 100 :=
  fun h => absurd ((river_equilibrium_iff [3] [exValueHand] [exBluffHand] [.call, .fold] 100
    (by decide) (by decide)).mp h).1 (by decide)

-- If you never call, the bot's bluffs win the pot every time.
example : 0 < bluffTotal [.fold, .fold, .fold] 100 100 :=
  (fewer_calls_bluff_wins [.fold, .fold, .fold] 100 (by decide)).mpr (by decide)

/-! ## The real bot's bet, on a real spot

`exRiverOpenState` (`Engine/Proofs/RiverBot.lean`): the river, 200 in the pot from earlier
streets, no bets yet, the bot to act, 400 chips each. The board is 2♣ 7♦ J♠ Q♥ 9♠. -/

-- Every hypothesis of `bot_river_bet_is_pot_sized` holds: five board cards, nothing to call,
-- legal sizes 10 to 400, and the pot-sized total, 0 + 200, is between them.
example : exBoard.length = 5 := rfl
example : exRiverOpenState.toCall = 0 := by decide
example : exRiverOpenState.raiseBounds = some (10, 400) := by decide
example : exRiverOpenState.bet exRiverOpenState.toAct + exRiverOpenState.potToWin = 200 := by
  decide

/-- So whatever the bot holds and whatever its settings, if it bets here, it bets 200: the pot. -/
example (sl : Sliders) (seed : Nat) (hole : List Card) (n : Nat)
    (hbet : (botDecide sl seed hole exBoard exRiverOpenState).action = .raiseTo n) : n = 200 :=
  bot_river_bet_is_pot_sized sl seed hole exBoard exRiverOpenState none rfl (by decide) 10 400
    (by decide) (by decide) (by decide) n hbet

-- A wrong size is ruled out: the bot never bets 150 here.
example (sl : Sliders) (seed : Nat) (hole : List Card) :
    (botDecide sl seed hole exBoard exRiverOpenState).action ≠ .raiseTo 150 := fun h => by
  have := bot_river_bet_is_pot_sized sl seed hole exBoard exRiverOpenState none rfl (by decide)
    10 400 (by decide) (by decide) (by decide) 150 h
  exact absurd this (by decide)

-- Compiled checks (the kernel cannot score the real betting set): 3♣ 8♣ is one of the bot's
-- bluffs at Risk 50, and the bot bets it pot-sized, 200 into 200, the same as its aces.
#guard riverRole 33 exBoard [card 3 .clubs, card 8 .clubs] == .bluff
#guard (botDecide (Sliders.ofRisk 50) 7 [card 3 .clubs, card 8 .clubs] exBoard
  exRiverOpenState).action.text == "raise 200"
#guard (botDecide (Sliders.ofRisk 50) 7 [card 14 .hearts, card 14 .diamonds] exBoard
  exRiverOpenState).action.text == "raise 200"

#print axioms half_calls_bluff_breaks_even
#print axioms river_equilibrium_iff
#print axioms bot_river_bet_is_pot_sized
