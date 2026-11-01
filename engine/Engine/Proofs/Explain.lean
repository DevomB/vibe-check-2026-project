import Engine.Explain
import Engine.Proofs.BotRisk
import Engine.Proofs.Review

/-!
# What we prove about the two review panels

- **The Risk explorer shows the real bot** (`exploreHand_moves`). For every bot move the
  game recorded, and every Risk from 0 to 100, the explorer's move at that Risk is the move
  `botDecide` makes at that Risk, with the same Bluff, seed, cards, board and betting state.
- **It never goes from fold back to call** (`exploreHand_risk_monotone`). This is T4
  (`botDecide_risk_monotone`) applied to the explorer's moves.
- **The range viewer's numbers add up** (`rangeOf_adds_up`, `rangeOf_counts`). The hands
  your cards block, plus the hands you beat, tie and lose to, are all the hands in the
  betting set. The beat, tie and lose numbers are the counts the review grades with.

What to review (the definitions these statements depend on): `exploreHand`, `exploreMove`,
`movesByRisk`, `countsIn`, `countsTable`, `BotMoveRecord`, `rangeOf`, `RangeSummary`, and,
from earlier files, `botDecide`, `RiskMonotone`, `reviewRiver`.

These theorems are not part of `Checks/` (Devom decides that).
-/

/-! ## The counts table -/

/-- Looking up a key in a table built as `(key, f key)` pairs finds `f key`. -/
theorem lookup_map_self {α β : Type} [BEq α] [LawfulBEq α] (f : α → β) (k : α) (c : β) :
    ∀ ks : List α, (ks.map fun x => (x, f x)).lookup k = some c → c = f k
  | [], h => by simp at h
  | x :: xs, h => by
    simp only [List.map_cons, List.lookup] at h
    split at h
    · next hx => cases h; rw [eq_of_beq hx]
    · exact lookup_map_self f k c xs h

/-- The explorer's counts for a move are `countsFor`'s, whether or not the table has them. -/
theorem countsIn_countsTable (ms : List BotMoveRecord) (m : BotMoveRecord) :
    countsIn (countsTable ms) m = countsFor m.seed m.hole m.board := by
  unfold countsIn
  split
  · next c h =>
    exact lookup_map_self (fun k : Nat × List Card × List Card => countsFor k.1 k.2.1 k.2.2)
      m.countsKey c _ h
  · rfl

/-! ## The explorer's moves -/

/-- With no bet to face, the bot's move does not depend on Risk. (The same step as in
`decideView_risk_mono`, stated as an equation.) -/
theorem decideView_no_bet (v : View) (c : Counts) (b r₁ r₂ : Nat) (hc : v.toCall = 0) :
    (decideView { v with sliders := ⟨r₁, b⟩ } c).action =
      (decideView { v with sliders := ⟨r₂, b⟩ } c).action := by
  have hc' : ¬ 0 < v.toCall := by omega
  simp only [decideView, hc', ↓reduceIte, riverOpening, decideView.checkMove, View.potBetTarget]
  split <;> (try split) <;> (try split) <;> rfl

/-- Entry `r` of `movesByRisk` is the bot's move at Risk `r`, for every `r` from 0 to 100. -/
theorem movesByRisk_getElem (sl : Sliders) (c : Counts) (m : BotMoveRecord) (r : Nat)
    (hr : r ≤ 100) :
    (movesByRisk sl c m)[r]? =
      some (decideWithCounts ⟨r, sl.bluffPct⟩ c m.hole m.board m.state).action := by
  unfold movesByRisk
  split
  · next h0 =>
    simp only [List.getElem?_replicate, show r < 101 by omega, ↓reduceIte, Option.some.injEq]
    exact decideView_no_bet (viewOf ⟨0, sl.bluffPct⟩ m.hole m.board m.state) c sl.bluffPct
      sl.risk r (by simpa [viewOf] using h0)
  · simp [show r < 101 by omega]

/-- **The Risk explorer shows the real bot.** Take the bot moves recorded in a hand, and
the game's sliders `sl`. For move number `i` and every Risk `r` from 0 to 100, the
explorer's move at Risk `r` is exactly what `botDecide` returns at Risk `r`, with the
game's Bluff and the move's recorded seed, cards, board and betting state. -/
theorem exploreHand_moves (sl : Sliders) (ms : List BotMoveRecord) (i r : Nat)
    (hi : i < ms.length) (hr : r ≤ 100) :
    ((exploreHand sl ms)[i]?.bind fun e => e.moves[r]?) =
      some (botDecide ⟨r, sl.bluffPct⟩ ms[i].seed ms[i].hole ms[i].board ms[i].state).action := by
  simp only [exploreHand, List.getElem?_map, List.getElem?_eq_getElem hi, Option.map_some,
    Option.bind_some, exploreMove, countsIn_countsTable, botDecide]
  exact movesByRisk_getElem _ _ _ r hr

/-- **The explorer never goes from fold back to call.** For each recorded move, if the
explorer shows a call or raise at Risk `r₂`, it shows one at every lower Risk too. (Past
Risk 100 there is no entry, which counts as a fold.) -/
theorem exploreHand_risk_monotone (sl : Sliders) (ms : List BotMoveRecord) (i : Nat)
    (hi : i < ms.length) :
    RiskMonotone fun r => ((exploreHand sl ms)[i]?.bind fun e => e.moves[r]?).getD .fold := by
  intro r₁ r₂ hr h
  dsimp only at h ⊢
  by_cases h2 : r₂ ≤ 100
  · rw [exploreHand_moves sl ms i r₂ hi h2] at h
    rw [exploreHand_moves sl ms i r₁ hi (by omega)]
    exact botDecide_risk_monotone sl.bluffPct _ _ _ _ r₁ r₂ hr h
  · have hnone : ((exploreHand sl ms)[i]?.bind fun e => e.moves[r₂]?) = none := by
      simp only [exploreHand, List.getElem?_map, List.getElem?_eq_getElem hi, Option.map_some,
        Option.bind_some, exploreMove]
      unfold movesByRisk
      split <;> simp <;> omega
    rw [hnone] at h
    simp [Action.continues] at h

/-! ## The range viewer -/

/-- **The range viewer's numbers add up.** The value hands and bluffs in the bot's betting
set are exactly the hands your cards block, plus the hands you beat, tie and lose to. (Each
hand left is counted once: `scoreCounts_total`, `Proofs/Review.lean`.) -/
theorem rangeOf_adds_up (spot : RiverSpot) :
    (rangeOf spot).value + (rangeOf spot).bluffs =
      (rangeOf spot).blocked + ((rangeOf spot).beat + (rangeOf spot).tie + (rangeOf spot).lose) := by
  have ht := scoreCounts_total spot.botHands spot.myScore
  have hp := List.length_eq_countP_add_countP spot.blocks
    (l := (riverBettingSet spot.bluffPct spot.board).value ++
      (riverBettingSet spot.bluffPct spot.board).bluffs)
  have hnot : (fun a => decide ¬spot.blocks a = true) = (fun h => !spot.blocks h) := by
    funext a; simp
  simp only [List.countP_eq_length_filter, List.length_append, hnot] at hp
  simp only [Counts.total, RiverSpot.botHands] at ht
  simp only [rangeOf, RiverSpot.botHands]
  omega

/-- The range viewer's beat, tie and lose numbers are the win, tie and loss counts the
review grades the decision with, whether you called or folded. -/
theorem rangeOf_counts (spot : RiverSpot) (choice : RiverChoice) :
    (reviewRiver spot choice).counts =
      ⟨(rangeOf spot).beat, (rangeOf spot).tie, (rangeOf spot).lose⟩ := rfl

/-! ## Checks: the statements can hold, and reject bad output -/

/-- `exploreHand_moves` applies to a real record: `exRecord`, the small blind's first decision
with nine-two offsuit. Its hypotheses (move 0 of one, Risk 50) hold. -/
example : ((exploreHand ⟨50, 33⟩ [exRecord])[0]?.bind fun e => e.moves[50]?) =
    some (botDecide ⟨50, 33⟩ exRecord.seed exRecord.hole exRecord.board exRecord.state).action :=
  exploreHand_moves ⟨50, 33⟩ [exRecord] 0 50 (by decide) (by decide)

/-- The statement rejects a wrong explorer. One that showed the move the bot made (a fold, at
Risk 50) at every Risk would be wrong at Risk 0, where `botDecide` calls with nine-two. -/
example : ¬ ∀ r ≤ 100, Action.fold =
    (botDecide ⟨r, 33⟩ exRecord.seed exRecord.hole exRecord.board exRecord.state).action := by
  intro h
  have h0 := congrArg Action.continues (h 0 (by decide))
  revert h0
  decide

/-- `rangeOf_adds_up` holds on a real spot with something in every place: 324 + 160 = 26 +
(449 + 9 + 0) for the king-high straight in `exRiverSpot`. -/
example : (rangeOf exRiverSpot).value + (rangeOf exRiverSpot).bluffs =
    (rangeOf exRiverSpot).blocked +
      ((rangeOf exRiverSpot).beat + (rangeOf exRiverSpot).tie + (rangeOf exRiverSpot).lose) :=
  rangeOf_adds_up exRiverSpot

#print axioms exploreHand_moves
#print axioms exploreHand_risk_monotone
#print axioms rangeOf_adds_up
#print axioms rangeOf_counts
