import Engine.Proofs.BluffCatcher
import Engine.Proofs.OneSlider
import Engine.Proofs.OneSliderRiver

/-!
# The bluff catcher against the other Risk settings, and for any bet size

`Engine/Proofs/BluffCatcher.lean` proves the caller's side of the one-street river model at
Risk 50: against a bluff catcher, calling adds up to `2·(bluffs·prize − value·cost)` half-chips
(`bluff_catcher_call_total`), it is break-even exactly at one bluff in three for a pot-sized bet,
and the Risk 50 set is two bluffs short of that (`risk50_bluff_catcher_call_loses`).
`Engine/Proofs/Equilibrium.lean` proves the bot's side. This file adds three facts:

- **Risk 100.** Against the Risk 100 set (486 bluffs) a bluff catcher facing a pot-sized bet of
  `cost` gains `1296·cost` half-chips over the 810 hands the bot bets, 0.8 bets per call, so
  calling the maniac down wins (`maniac_bluff_catcher_total`).
- **Risk 0.** Against the Risk 0 set (no bluffs) it loses `648·cost` half-chips, the whole call
  every time, so folding is right (`rock_bluff_catcher_total`).
- **More bluffs never lower a bluff catcher's call**, for any bet size
  (`more_bluffs_more_call_total`).

The two totals are over the whole betting set, before the hands the caller's cards block are
removed; the review's grade removes them (`RiverSpot.botHands`), so the total at a real table
differs by the blocked hands (`review_both_best_iff_one_third` is the statement through the
review itself). One street, a bluff catcher, the bot as bettor; not a claim that the bot plays
well.

What to review: `CatchesBluffs`, `choiceTotal`, `riverBettingSet`, `Sliders.ofRisk`.
-/

/-! ## More bluffs never lower the call -/

/-- Against a bluff catcher, adding bluffs to the range never makes calling worth less, for any
prize and cost. -/
theorem more_bluffs_more_call_total (mine : List Nat) (value bluffs bluffs' : List RankedHand)
    (prize cost : Nat) (hc : CatchesBluffs mine value bluffs)
    (hc' : CatchesBluffs mine value bluffs') (hlen : bluffs.length ≤ bluffs'.length) :
    choiceTotal (value ++ bluffs) mine prize cost .call ≤
      choiceTotal (value ++ bluffs') mine prize cost .call := by
  rw [bluff_catcher_call_total _ _ _ _ _ hc, bluff_catcher_call_total _ _ _ _ _ hc']
  have : (bluffs.length : Int) * prize ≤ (bluffs'.length : Int) * prize :=
    Int.mul_le_mul_of_nonneg_right (by omega) (by omega)
  omega

/-! ## The bot's Risk 100 and Risk 0 sets -/

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

/-- **Calling the maniac down wins.** On a river board with no card twice, a bluff catcher
facing the Risk 100 bot's pot-sized bet of `cost` gains `1296·cost` half-chips over the 810
hands the bot bets: `648·cost` chips, or 0.8 bets per call. The total is over the whole
betting set, before the hands the caller's cards block are removed. -/
theorem maniac_bluff_catcher_total (board : List Card) (h5 : board.length = 5) (hd : board.Nodup)
    (mine : List Nat) (cost : Nat)
    (hc : CatchesBluffs mine (riverBettingSet (Sliders.ofRisk 100).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 100).bluffPct board).bluffs) :
    choiceTotal ((riverBettingSet (Sliders.ofRisk 100).bluffPct board).value ++
        (riverBettingSet (Sliders.ofRisk 100).bluffPct board).bluffs) mine (2 * cost) cost .call =
      1296 * (cost : Int) := by
  rw [bluff_catcher_call_total _ _ _ _ _ hc, (maniac_river_set board h5 hd).1,
    (maniac_river_set board h5 hd).2]
  omega

/-- **Folding to the rock is right.** At Risk 0 the bot never bluffs, so a bluff catcher facing
its pot-sized bet of `cost` loses `648·cost` half-chips over the 324 hands it bets: the whole
call, every time. The total is over the whole betting set, before the hands the caller's
cards block are removed. -/
theorem rock_bluff_catcher_total (board : List Card) (h5 : board.length = 5) (hd : board.Nodup)
    (mine : List Nat) (cost : Nat)
    (hc : CatchesBluffs mine (riverBettingSet (Sliders.ofRisk 0).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 0).bluffPct board).bluffs) :
    choiceTotal ((riverBettingSet (Sliders.ofRisk 0).bluffPct board).value ++
        (riverBettingSet (Sliders.ofRisk 0).bluffPct board).bluffs) mine (2 * cost) cost .call =
      -(648 * (cost : Int)) := by
  rw [bluff_catcher_call_total _ _ _ _ _ hc, (rock_river_set board h5 hd).1,
    (rock_river_set board h5 hd).2]
  omega

/-! ## Checks: the statements hold on a real board, and reject bad output

The board is `boardAK257` (A K 2 5 7). A pair of sevens (7c 3d) beats every bluff in the Risk
100 set, so in the Risk 50 set too, and loses to every value hand: a bluff catcher at every
Risk. (A pair of twos would do at Risk 50 but is itself among the 486 bluffs at Risk 100.)
These guards rank the board in the interpreter; the kernel's `decide` would be too slow for
1,081 hands, so the real-board instances are `#guard`s, and the kernel example uses the
one-hand range from `BluffCatcherSpec.lean`. -/

/-- A bluff catcher on `boardAK257` at every Risk: a pair of sevens. -/
def catcherAK257 : List Nat := bestScore ([card 7 .clubs, card 3 .diamonds] ++ boardAK257)

#guard CatchesBluffs catcherAK257 (riverBettingSet (Sliders.ofRisk 100).bluffPct boardAK257).value
  (riverBettingSet (Sliders.ofRisk 100).bluffPct boardAK257).bluffs
#guard CatchesBluffs catcherAK257 (riverBettingSet (Sliders.ofRisk 0).bluffPct boardAK257).value
  (riverBettingSet (Sliders.ofRisk 0).bluffPct boardAK257).bluffs
-- Calling a 100 bet into 100 with it: +129,600 half-chips at Risk 100, −64,800 at Risk 0.
#guard choiceTotal ((riverBettingSet (Sliders.ofRisk 100).bluffPct boardAK257).value ++
  (riverBettingSet (Sliders.ofRisk 100).bluffPct boardAK257).bluffs) catcherAK257 200 100 .call == 129600
#guard choiceTotal ((riverBettingSet (Sliders.ofRisk 0).bluffPct boardAK257).value ++
  (riverBettingSet (Sliders.ofRisk 0).bluffPct boardAK257).bluffs) catcherAK257 200 100 .call == -64800

/-- `more_bluffs_more_call_total` with every hypothesis met: two bluffs beside one value hand
are worth at least as much to the caller as one. -/
example : choiceTotal ([exValueHand] ++ [exBluffHand]) [3] 200 100 .call ≤
    choiceTotal ([exValueHand] ++ [exBluffHand, exBluffHand]) [3] 200 100 .call :=
  more_bluffs_more_call_total [3] [exValueHand] [exBluffHand] [exBluffHand, exBluffHand] 200 100
    (by decide) (by decide) (by decide)

/-- The statement rejects the reverse: fewer bluffs are not worth more to the caller. -/
example : ¬ choiceTotal ([exValueHand] ++ [exBluffHand]) [3] 200 100 .call <
    choiceTotal ([exValueHand] ++ []) [3] 200 100 .call := by decide

#print axioms more_bluffs_more_call_total
#print axioms maniac_bluff_catcher_total
#print axioms rock_bluff_catcher_total
