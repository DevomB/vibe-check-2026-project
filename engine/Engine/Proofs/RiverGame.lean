import Engine.Proofs.RiverGameSpec
import Engine.Proofs.OneSlider
import Engine.Proofs.OneSliderRiver

/-!
# The one-street river game: what we prove about the bot's river bet

The bot's river bluff share at Risk 50 "matches the textbook ratio". These theorems say what
that means, with the review's own EV definitions and the bot's real betting sets:

- **A bluff-catcher's call is worth `2·(bluffs·prize − value·cost)` half-chips**
  (`polarized_call_total`), so it is break-even exactly when `bluffs·prize = value·cost`
  (`caller_indifferent_iff`); for a pot-sized bet, exactly when one bet in three is a bluff
  (`pot_bet_indifferent_iff`).
- **Against the bot's real sets**: at Risk 50 a bluff-catcher facing a pot-sized bet of `b`
  loses `8·b` half-chips over 484 hands, that is `4·b` chips in total or under 1% of the bet
  per call (`ideal_bluff_catcher_total`); at Risk 100 it gains `1296·b` half-chips over 810
  hands, 0.8 bets per call, so calling the maniac down wins (`maniac_bluff_catcher_total`);
  at Risk 0 it loses `648·b` half-chips, so folding is right (`rock_bluff_catcher_total`).
  These totals are over the whole betting set, before the hands your cards block are removed; the review's grade removes them (`RiverSpot.botHands`), so the total at a real table differs by the blocked hands.
- **More bluffs never lower a bluff-catcher's call** (`more_bluffs_more_call_total`).
- **The bettor's side of the same model**: a bluff gains nothing exactly when the caller
  defends with share `pot / (pot + bet)` of its bluff-catchers (`bettor_indifferent_iff`);
  defending more makes every bluff lose, defending less makes it gain.

What this does not say: anything about streets before the river, about a caller who is not a
bluff-catcher, about the bot as the caller (its call rule is not stated in these terms), or
about whole hands. It is the one textbook property the bot's river set has: a bluff-catcher
is, within 1%, indifferent to calling it. It holds only inside the one-street model, and it is
not a claim that the bot plays well.

What to review: `Polarized`, `callTotal`, `bluffGain` (`RiverGameSpec.lean`), the review's
`callResult` and `choiceTotal`, `riverBettingSet`, `Sliders.ofRisk`.
-/

/-! ## Sums over a range -/

/-- If `f` is `k` on every element of a list, the sum of `f` over it is `length × k`. -/
theorem sum_map_eq_length_mul {α : Type} (l : List α) (f : α → Int) (k : Int)
    (h : ∀ x ∈ l, f x = k) : (l.map f).sum = l.length * k := by
  induction l with
  | nil => simp
  | cons x t ih =>
    rw [List.map_cons, List.sum_cons, h x (by simp), ih (fun y hy => h y (by simp [hy])),
      List.length_cons]
    push_cast
    rw [Int.add_mul, Int.one_mul, Int.add_comm]

/-- Against a bluff-catcher, every value hand costs the call and every bluff pays the prize. -/
theorem polarized_call_total (mine : List Nat) (value bluffs : List RankedHand)
    (prize cost : Nat) (hp : Polarized mine value bluffs) :
    callTotal value bluffs mine prize cost =
      2 * ((bluffs.length : Int) * prize - (value.length : Int) * cost) := by
  simp only [callTotal, choiceTotal]
  rw [List.map_append, List.sum_append,
    sum_map_eq_length_mul value _ (-(2 * (cost : Int)))
      (fun h hh => by simp [callResult, hp.1 h hh]),
    sum_map_eq_length_mul bluffs _ (2 * (prize : Int)) (fun h hh => by
      have h1 := hp.2 h hh
      have h2 : ¬ mine < h.score := List.lt_asymm h1
      simp [callResult, h1, h2])]
  have e1 : (value.length : Int) * -(2 * (cost : Int)) = -(2 * ((value.length : Int) * cost)) := by
    rw [Int.mul_neg]; congr 1; ac_rfl
  have e2 : (bluffs.length : Int) * (2 * (prize : Int)) = 2 * ((bluffs.length : Int) * prize) := by
    ac_rfl
  rw [e1, e2]
  omega

/-! ## Indifference -/

/-- **The caller's indifference equation.** A bluff-catcher's call is break-even exactly when
the bluffs' prize equals the value hands' cost: `bluffs × prize = value × cost`. -/
theorem caller_indifferent_iff (mine : List Nat) (value bluffs : List RankedHand)
    (prize cost : Nat) (hp : Polarized mine value bluffs) :
    callTotal value bluffs mine prize cost = 0 ↔
      (bluffs.length : Int) * prize = (value.length : Int) * cost := by
  rw [polarized_call_total _ _ _ _ _ hp]
  omega

/-- **One bet in three.** Facing a pot-sized bet (the prize is twice the cost), a
bluff-catcher's call is break-even exactly when the bettor has one bluff for every two value
hands: bluffs are a third of its bets. -/
theorem pot_bet_indifferent_iff (mine : List Nat) (value bluffs : List RankedHand) (cost : Nat)
    (hc : 0 < cost) (hp : Polarized mine value bluffs) :
    callTotal value bluffs mine (2 * cost) cost = 0 ↔ 2 * bluffs.length = value.length := by
  rw [caller_indifferent_iff _ _ _ _ _ hp]
  push_cast
  constructor
  · intro h
    have h' : (2 * (bluffs.length : Int)) * cost = (value.length : Int) * cost := by
      rw [← h]; ac_rfl
    have := Int.eq_of_mul_eq_mul_right (by omega) h'
    omega
  · intro h
    have hz : (2 * (bluffs.length : Int)) = value.length := by omega
    rw [← hz]; ac_rfl

/-- More bluffs in the range never make a bluff-catcher's call worth less. -/
theorem more_bluffs_more_call_total (mine : List Nat) (value bluffs bluffs' : List RankedHand)
    (prize cost : Nat) (hp : Polarized mine value bluffs) (hp' : Polarized mine value bluffs')
    (hlen : bluffs.length ≤ bluffs'.length) :
    callTotal value bluffs mine prize cost ≤ callTotal value bluffs' mine prize cost := by
  rw [polarized_call_total _ _ _ _ _ hp, polarized_call_total _ _ _ _ _ hp']
  have : (bluffs.length : Int) * prize ≤ (bluffs'.length : Int) * prize :=
    Int.mul_le_mul_of_nonneg_right (by omega) (by omega)
  omega

/-! ## The bot's real sets -/

/-- At Risk 100 (Bluff 60%) the river set has 324 value hands and 486 bluffs. -/
theorem maniac_river_set (board : List Card) (h5 : board.length = 5) (hd : board.Nodup) :
    (riverBettingSet (Sliders.ofRisk 100).bluffPct board).value.length = 324 ∧
    (riverBettingSet (Sliders.ofRisk 100).bluffPct board).bluffs.length = 486 := by
  have h := bluff_frequency (Sliders.ofRisk 100).bluffPct board h5 hd (ofRisk_bluff_le_60 100)
  have h60 : (Sliders.ofRisk 100).bluffPct = 60 := rfl
  rw [h60] at h ⊢
  simp only [NearestWhole] at h
  exact ⟨h.1, by omega⟩

/-- At Risk 0 (Bluff 0%) the river set has 324 value hands and no bluffs. -/
theorem rock_river_set (board : List Card) (h5 : board.length = 5) (hd : board.Nodup) :
    (riverBettingSet (Sliders.ofRisk 0).bluffPct board).value.length = 324 ∧
    (riverBettingSet (Sliders.ofRisk 0).bluffPct board).bluffs.length = 0 := by
  have h := bluff_frequency (Sliders.ofRisk 0).bluffPct board h5 hd (ofRisk_bluff_le_60 0)
  have h0 : (Sliders.ofRisk 0).bluffPct = 0 := rfl
  rw [h0] at h ⊢
  simp only [NearestWhole] at h
  exact ⟨h.1, by omega⟩

/-- **Risk 50 is within 1% of indifference.** On a river board with no card twice, a
bluff-catcher facing the Risk 50 bot's pot-sized bet of `b` chips loses `8·b` half-chips in
total over the 484 hands the bot bets: `4·b` chips, which is `b/121` per call, under 1% of
the bet. Exact indifference would need 162 bluffs (`pot_bet_indifferent_iff`: twice the bluffs
equals the 324 value hands); the rounding rule gives 160, within two hands of it. These totals are over the whole betting set, before the hands your cards block are removed; the review's grade removes them (`RiverSpot.botHands`), so the total at a real table differs by the blocked hands. -/
theorem ideal_bluff_catcher_total (board : List Card) (h5 : board.length = 5) (hd : board.Nodup)
    (mine : List Nat) (b : Nat)
    (hp : Polarized mine (riverBettingSet (Sliders.ofRisk 50).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs) :
    callTotal (riverBettingSet (Sliders.ofRisk 50).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs mine (2 * b) b = -(8 * (b : Int)) := by
  rw [polarized_call_total _ _ _ _ _ hp, (ideal_river_set board h5 hd).1,
    (ideal_river_set board h5 hd).2]
  push_cast
  omega

/-- **Calling the maniac down wins.** At Risk 100 a bluff-catcher facing the pot-sized bet
gains `1296·b` half-chips over the 810 hands the bot bets: `648·b` chips, or 0.8 bets per
call. These totals are over the whole betting set, before the hands your cards block are removed; the review's grade removes them (`RiverSpot.botHands`), so the total at a real table differs by the blocked hands. -/
theorem maniac_bluff_catcher_total (board : List Card) (h5 : board.length = 5) (hd : board.Nodup)
    (mine : List Nat) (b : Nat)
    (hp : Polarized mine (riverBettingSet (Sliders.ofRisk 100).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 100).bluffPct board).bluffs) :
    callTotal (riverBettingSet (Sliders.ofRisk 100).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 100).bluffPct board).bluffs mine (2 * b) b = 1296 * (b : Int) := by
  rw [polarized_call_total _ _ _ _ _ hp, (maniac_river_set board h5 hd).1,
    (maniac_river_set board h5 hd).2]
  omega

/-- **Folding to the rock is right.** At Risk 0 the bot never bluffs, so a bluff-catcher
facing its pot-sized bet loses `648·b` half-chips over the 324 hands it bets: the whole call,
every time. These totals are over the whole betting set, before the hands your cards block are removed; the review's grade removes them (`RiverSpot.botHands`), so the total at a real table differs by the blocked hands. -/
theorem rock_bluff_catcher_total (board : List Card) (h5 : board.length = 5) (hd : board.Nodup)
    (mine : List Nat) (b : Nat)
    (hp : Polarized mine (riverBettingSet (Sliders.ofRisk 0).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 0).bluffPct board).bluffs) :
    callTotal (riverBettingSet (Sliders.ofRisk 0).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 0).bluffPct board).bluffs mine (2 * b) b = -(648 * (b : Int)) := by
  rw [polarized_call_total _ _ _ _ _ hp, (rock_river_set board h5 hd).1,
    (rock_river_set board h5 hd).2]
  omega

/-! ## The bettor's side: the defence frequency -/

/-- **The bettor's indifference equation.** A bluff gains nothing over checking exactly when
the caller calls with share `pot / (pot + bet)` of its bluff-catchers:
`calls × (pot + bet) = hands × pot`. For a pot-sized bet that is half of them. -/
theorem bettor_indifferent_iff (hands calls pot bet : Nat) :
    bluffGain hands calls pot bet = 0 ↔ (calls : Int) * (pot + bet) = hands * pot := by
  unfold bluffGain
  rw [Int.sub_mul, Int.mul_add]
  omega

/-- Defending more than that share makes every bluff lose. -/
theorem defend_more_bluff_loses (hands calls pot bet : Nat)
    (h : (hands : Int) * pot < calls * (pot + bet)) : bluffGain hands calls pot bet < 0 := by
  unfold bluffGain
  rw [Int.sub_mul]
  rw [Int.mul_add] at h
  omega

/-- Defending less than that share makes every bluff gain. -/
theorem defend_less_bluff_gains (hands calls pot bet : Nat)
    (h : (calls : Int) * (pot + bet) < hands * pot) : 0 < bluffGain hands calls pot bet := by
  unfold bluffGain
  rw [Int.sub_mul]
  rw [Int.mul_add] at h
  omega

/-! ## Checks: the statements hold on a real board, and reject bad output

The board is `boardAK257` (A K 2 5 7). A pair of sevens (7c 3d) beats every bluff in the
Risk 100 set, so in the Risk 50 set too, and loses to every value hand: a bluff-catcher at
every Risk. (A pair of twos would do at Risk 50 but is itself among the 486 bluffs at Risk
100.) These guards rank the
board in the interpreter; the kernel's `decide` would be too slow for 1,081 hands, so the
`Polarized` hypothesis is shown by `#guard` rather than by `decide`. -/

/-- A bluff-catcher on `boardAK257` at every Risk: a pair of sevens. -/
def catcherAK257 : List Nat := bestScore ([card 7 .clubs, card 3 .diamonds] ++ boardAK257)

#guard Polarized catcherAK257 (riverBettingSet (Sliders.ofRisk 50).bluffPct boardAK257).value
  (riverBettingSet (Sliders.ofRisk 50).bluffPct boardAK257).bluffs
#guard Polarized catcherAK257 (riverBettingSet (Sliders.ofRisk 100).bluffPct boardAK257).value
  (riverBettingSet (Sliders.ofRisk 100).bluffPct boardAK257).bluffs
-- Calling a 100 bet into 100 with it: −800 half-chips at Risk 50, +129,600 at Risk 100,
-- −64,800 at Risk 0, as the theorems say.
#guard callTotal (riverBettingSet (Sliders.ofRisk 50).bluffPct boardAK257).value
  (riverBettingSet (Sliders.ofRisk 50).bluffPct boardAK257).bluffs catcherAK257 200 100 == -800
#guard callTotal (riverBettingSet (Sliders.ofRisk 100).bluffPct boardAK257).value
  (riverBettingSet (Sliders.ofRisk 100).bluffPct boardAK257).bluffs catcherAK257 200 100 == 129600
#guard callTotal (riverBettingSet (Sliders.ofRisk 0).bluffPct boardAK257).value
  (riverBettingSet (Sliders.ofRisk 0).bluffPct boardAK257).bluffs catcherAK257 200 100 == -64800

/-- `pot_bet_indifferent_iff` with every hypothesis met, on the small example range: one
bluff beside two value hands is exactly break-even against a pot-sized bet. -/
example : callTotal exValueHands exBluffHands [5] (2 * 100) 100 = 0 :=
  (pot_bet_indifferent_iff [5] exValueHands exBluffHands 100 (by decide) (by decide)).2 (by decide)

/-- The statement rejects a wrong ratio: two bluffs beside two value hands are not
break-even. -/
example : ¬ callTotal exValueHands (exBluffHands ++ exBluffHands) [5] (2 * 100) 100 = 0 := by
  rw [pot_bet_indifferent_iff [5] _ _ 100 (by decide) (by decide)]
  decide

/-- `more_bluffs_more_call_total` with every hypothesis met: two bluffs beside the two value
hands are worth at least as much to the caller as one. -/
example : callTotal exValueHands exBluffHands [5] 200 100 ≤
    callTotal exValueHands (exBluffHands ++ exBluffHands) [5] 200 100 :=
  more_bluffs_more_call_total [5] exValueHands exBluffHands (exBluffHands ++ exBluffHands) 200 100
    (by decide) (by decide) (by decide)

/-- `bettor_indifferent_iff` with every hypothesis met: calling with 2 of 4 bluff-catchers
against a pot-sized bluff. A caller who defends with 1 of 4 lets the bluff gain. -/
example : bluffGain 4 2 100 100 = 0 := (bettor_indifferent_iff 4 2 100 100).2 (by decide)
example : 0 < bluffGain 4 1 100 100 := defend_less_bluff_gains 4 1 100 100 (by decide)
example : bluffGain 4 3 100 100 < 0 := defend_more_bluff_loses 4 3 100 100 (by decide)

#print axioms polarized_call_total
#print axioms caller_indifferent_iff
#print axioms pot_bet_indifferent_iff
#print axioms more_bluffs_more_call_total
#print axioms ideal_bluff_catcher_total
#print axioms maniac_bluff_catcher_total
#print axioms rock_bluff_catcher_total
#print axioms bettor_indifferent_iff
#print axioms defend_more_bluff_loses
#print axioms defend_less_bluff_gains
