import Engine.Explain
import Engine.Proofs.BotRisk
import Engine.Proofs.OneSlider
import Engine.Proofs.Review

/-!
# What we prove about the two review panels

- **The Risk explorer shows the real bot** (`exploreHandAt_moves`). For every bot move the
  game recorded, and every Risk from 0 to 100, the explorer's move at that Risk is the move
  `botDecide` makes with the settings `Sliders.ofRisk` gives for that Risk, and the move's
  recorded seed, cards, board and betting state. On the river this includes the Bluff
  changing with Risk; the ranking shortcut (`riverMoveRanked`) is shown to agree with
  `riverOpening`.
- **Facing a bet, more Risk never turns a call into a fold**
  (`exploreHandAt_more_risk_continues`): `more_risk_never_folds_a_call` applied to the
  explorer's moves.
- The same two facts for the sweep over the internal caution (`exploreHand_moves`,
  `exploreHand_risk_monotone`, T4 applied), which the app showed before the one-slider
  change. `exploreHandAt` and `exploreHand` are one function, `exploreHandWith`, with
  different settings per Risk.
- **The range viewer's numbers add up** (`rangeOf_adds_up`, `rangeOf_counts`). The hands
  your cards block, plus the hands you beat, tie and lose to, are all the hands in the
  betting set. The beat, tie and lose numbers are the counts the review grades with.

What to review (the definitions these statements depend on): `exploreHandAt`, `exploreHand`,
`exploreHandWith`, `exploreMoveWith`, `movesBySetting`, `riverMoveRanked`, `countsIn`,
`countsTable`, `BotMoveRecord`, `rangeOf`, `RangeSummary`, and, from earlier files,
`botDecide`, `Sliders.ofRisk`, `RiskMonotone`, `reviewRiver`.

These statements are registered in `Checks/Challenge.lean` and `comparator.json`.
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

/-! ## The river, ranked once -/

/-- `riverBettingSet` is `bettingSetRanked` on the board's ranking. -/
theorem riverBettingSet_ranked (bluffPct : Nat) (board : List Card) :
    riverBettingSet bluffPct board = bettingSetRanked (rankRiverHands board) bluffPct := rfl

/-- `riverRole` is `riverRoleRanked` on the board's ranking. -/
theorem riverRole_ranked (bluffPct : Nat) (board hole : List Card) :
    riverRole bluffPct board hole = riverRoleRanked (rankRiverHands board) bluffPct hole := rfl

/-- On the river with no bet to face, the bot's move is `riverMoveRanked` on the board's
ranking. -/
theorem decideView_river_no_bet (v : View) (c : Counts) (hc : v.toCall = 0)
    (h5 : v.board.length = 5) :
    (decideView v c).action = riverMoveRanked (rankRiverHands v.board) v := by
  have hc' : ¬ 0 < v.toCall := by omega
  simp only [decideView, hc', ↓reduceIte, h5, riverOpening, riverBetOrCheck, riverMoveRanked,
    ← riverRole_ranked]
  split <;> rename_i hrole <;> simp only [hrole] <;>
    (try (split <;> rename_i hraise <;> (try simp only [hraise]))) <;> rfl

/-! ## The explorer's moves -/

/-- With no bet to face, the bot's move does not depend on caution. (The same step as in
`decideView_risk_mono`, stated as an equation.) -/
theorem decideView_no_bet (v : View) (c : Counts) (b r₁ r₂ : Nat) (hc : v.toCall = 0) :
    (decideView { v with sliders := ⟨r₁, b⟩ } c).action =
      (decideView { v with sliders := ⟨r₂, b⟩ } c).action := by
  have hc' : ¬ 0 < v.toCall := by omega
  simp only [decideView, hc', ↓reduceIte, riverOpening, decideView.checkMove, View.potBetTarget]
  split <;> (try split) <;> (try split) <;> rfl

/-- With no bet to face before the river, the bot reads no setting: any two settings give
the same move. -/
theorem decideView_no_bet_sliders (v : View) (c : Counts) (sl sl' : Sliders) (hc : v.toCall = 0)
    (h5 : v.board.length ≠ 5) :
    (decideView { v with sliders := sl } c).action =
      (decideView { v with sliders := sl' } c).action := by
  have hc' : ¬ 0 < v.toCall := by omega
  simp only [decideView, hc', ↓reduceIte, h5, decideView.checkMove, View.potBetTarget]
  split <;> (try split) <;> rfl

/-- `movesBySetting` always has 101 entries. -/
theorem movesBySetting_length (sliderAt : Nat → Sliders) (c : Counts) (m : BotMoveRecord) :
    (movesBySetting sliderAt c m).length = 101 := by
  unfold movesBySetting
  split <;> (try split) <;> simp

/-- Entry `r` of `movesBySetting` is the bot's move with the settings at Risk `r`, for every
`r` from 0 to 100. -/
theorem movesBySetting_getElem (sliderAt : Nat → Sliders) (c : Counts) (m : BotMoveRecord)
    (r : Nat) (hr : r ≤ 100) :
    (movesBySetting sliderAt c m)[r]? =
      some (decideWithCounts (sliderAt r) c m.hole m.board m.state).action := by
  have hr' : r < 101 := by omega
  unfold movesBySetting
  split
  · next h0 =>
    split
    · next h5 =>
      simp only [List.getElem?_map, List.getElem?_range hr', Option.map_some, Option.some.injEq]
      rw [decideWithCounts, decideView_river_no_bet _ c (by simpa [viewOf] using h0)
        (by simpa [viewOf] using h5)]
      rfl
    · next h5 =>
      simp only [List.getElem?_replicate, hr', ↓reduceIte, Option.some.injEq]
      exact decideView_no_bet_sliders (viewOf (sliderAt 0) m.hole m.board m.state) c
        (sliderAt 0) (sliderAt r) (by simpa [viewOf] using h0) (by simpa [viewOf] using h5)
  · simp [hr']

/-- For any settings per Risk: the explorer's move at Risk `r` (0 to 100) for move `i` is
`botDecide` with the settings at `r` and the move's recorded inputs. -/
theorem exploreHandWith_moves (sliderAt : Nat → Sliders) (risk : Nat) (ms : List BotMoveRecord)
    (i r : Nat) (hi : i < ms.length) (hr : r ≤ 100) :
    ((exploreHandWith sliderAt risk ms)[i]?.bind fun e => e.moves[r]?) =
      some (botDecide (sliderAt r) ms[i].seed ms[i].hole ms[i].board ms[i].state).action := by
  simp only [exploreHandWith, List.getElem?_map, List.getElem?_eq_getElem hi, Option.map_some,
    Option.bind_some, exploreMoveWith, countsIn_countsTable, botDecide]
  exact movesBySetting_getElem _ _ _ r hr

/-- Past Risk 100 there is no entry. -/
theorem exploreHandWith_none (sliderAt : Nat → Sliders) (risk : Nat) (ms : List BotMoveRecord)
    (i r : Nat) (hi : i < ms.length) (hr : 100 < r) :
    ((exploreHandWith sliderAt risk ms)[i]?.bind fun e => e.moves[r]?) = none := by
  simp only [exploreHandWith, List.getElem?_map, List.getElem?_eq_getElem hi, Option.map_some,
    Option.bind_some, exploreMoveWith]
  rw [List.getElem?_eq_none]
  rw [movesBySetting_length]; omega

/-- **The Risk explorer shows the real bot.** Take the bot moves recorded in a hand and the
game's Risk. For move number `i` and every Risk `r` from 0 to 100, the explorer's move at
Risk `r` is exactly what `botDecide` returns with the settings a new game at Risk `r` would
use (`Sliders.ofRisk r`) and the move's recorded seed, cards, board and betting state. -/
theorem exploreHandAt_moves (risk : Nat) (ms : List BotMoveRecord) (i r : Nat)
    (hi : i < ms.length) (hr : r ≤ 100) :
    ((exploreHandAt risk ms)[i]?.bind fun e => e.moves[r]?) =
      some (botDecide (Sliders.ofRisk r) ms[i].seed ms[i].hole ms[i].board ms[i].state).action :=
  exploreHandWith_moves Sliders.ofRisk risk ms i r hi hr

/-- **Facing a bet, the explorer never goes from call back to fold as Risk rises.** For a
recorded move that faced a bet, if the explorer shows a call or raise at Risk `r`, it shows
one at every higher Risk `r'` up to 100. -/
theorem exploreHandAt_more_risk_continues (risk : Nat) (ms : List BotMoveRecord) (i : Nat)
    (hi : i < ms.length) (hbet : 0 < ms[i].state.toCall) (r r' : Nat) (hr : r ≤ r')
    (hr' : r' ≤ 100)
    (h : (((exploreHandAt risk ms)[i]?.bind fun e => e.moves[r]?).getD .fold).continues) :
    (((exploreHandAt risk ms)[i]?.bind fun e => e.moves[r']?).getD .fold).continues := by
  rw [exploreHandAt_moves risk ms i r hi (by omega), Option.getD_some] at h
  rw [exploreHandAt_moves risk ms i r' hi hr', Option.getD_some]
  exact more_risk_never_folds_a_call _ _ _ _ hr hbet h

/-- The caution sweep shows the real bot: at caution `r` with the game's Bluff. -/
theorem exploreHand_moves (sl : Sliders) (ms : List BotMoveRecord) (i r : Nat)
    (hi : i < ms.length) (hr : r ≤ 100) :
    ((exploreHand sl ms)[i]?.bind fun e => e.moves[r]?) =
      some (botDecide ⟨r, sl.bluffPct⟩ ms[i].seed ms[i].hole ms[i].board ms[i].state).action :=
  exploreHandWith_moves (fun r => ⟨r, sl.bluffPct⟩) sl.risk ms i r hi hr

/-- The caution sweep never goes from fold back to call as caution rises: T4
(`botDecide_risk_monotone`) applied to its moves. (Past 100 there is no entry, which counts
as a fold.) -/
theorem exploreHand_risk_monotone (sl : Sliders) (ms : List BotMoveRecord) (i : Nat)
    (hi : i < ms.length) :
    RiskMonotone fun r => ((exploreHand sl ms)[i]?.bind fun e => e.moves[r]?).getD .fold := by
  intro r₁ r₂ hr h
  dsimp only at h ⊢
  by_cases h2 : r₂ ≤ 100
  · rw [exploreHand_moves sl ms i r₂ hi h2] at h
    rw [exploreHand_moves sl ms i r₁ hi (by omega)]
    exact botDecide_risk_monotone sl.bluffPct _ _ _ _ r₁ r₂ hr h
  · rw [exploreHand, exploreHandWith_none _ _ _ _ _ hi (by omega)] at h
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

/-- `exploreHandAt_moves` applies to a real record: `exRecord`, the small blind's first
decision with nine-two offsuit. Its hypotheses (move 0 of one, Risk 50) hold. -/
example : ((exploreHandAt 50 [exRecord])[0]?.bind fun e => e.moves[50]?) =
    some (botDecide (Sliders.ofRisk 50) exRecord.seed exRecord.hole exRecord.board
      exRecord.state).action :=
  exploreHandAt_moves 50 [exRecord] 0 50 (by decide) (by decide)

/-- The statement rejects a wrong explorer. One that showed the move the bot made at Risk
50 (a fold) at every Risk would be wrong at Risk 100, where `botDecide` calls with nine-two. -/
example : ¬ ∀ r ≤ 100, Action.fold =
    (botDecide (Sliders.ofRisk r) exRecord.seed exRecord.hole exRecord.board exRecord.state).action := by
  intro h
  have h100 := congrArg Action.continues (h 100 (by decide))
  revert h100
  decide

/-- `exploreHandAt_more_risk_continues` with every hypothesis met: the same record faces a
bet of 5, and from the call at Risk 26 follows the call at Risk 100. -/
example (h : (((exploreHandAt 50 [exRecord])[0]?.bind fun e => e.moves[26]?).getD Action.fold).continues) :
    (((exploreHandAt 50 [exRecord])[0]?.bind fun e => e.moves[100]?).getD Action.fold).continues :=
  exploreHandAt_more_risk_continues 50 [exRecord] 0 (by decide) (by decide) 26 100 (by decide)
    (by decide) h

/-- `exploreHand_moves` still applies to the caution sweep at the old settings. -/
example : ((exploreHand ⟨50, 33⟩ [exRecord])[0]?.bind fun e => e.moves[50]?) =
    some (botDecide ⟨50, 33⟩ exRecord.seed exRecord.hole exRecord.board exRecord.state).action :=
  exploreHand_moves ⟨50, 33⟩ [exRecord] 0 50 (by decide) (by decide)

/-- `rangeOf_adds_up` holds on a real spot with something in every place: 324 + 160 = 26 +
(449 + 9 + 0) for the king-high straight in `exRiverSpot`. -/
example : (rangeOf exRiverSpot).value + (rangeOf exRiverSpot).bluffs =
    (rangeOf exRiverSpot).blocked +
      ((rangeOf exRiverSpot).beat + (rangeOf exRiverSpot).tie + (rangeOf exRiverSpot).lose) :=
  rangeOf_adds_up exRiverSpot

#print axioms exploreHandAt_moves
#print axioms exploreHandAt_more_risk_continues
#print axioms exploreHand_moves
#print axioms exploreHand_risk_monotone
#print axioms rangeOf_adds_up
#print axioms rangeOf_counts
