import Engine.Proofs.ReviewSpec

/-!
# The review is sound (T5) and never uses hindsight (T8)

T5 `review_sound` (MVP §8): for a graded call or fold, Best means no chips lost against the
better of the two choices, under the review's model of the bot's hands, and a bigger loss
never gets a better label. It says nothing about raising.

1. `review_worth`: the review's worth of calling is the chips calling wins against each of
   the bot's possible hands (`choiceTotal`), averaged, in big blinds. Folding is worth 0.
2. `review_lost`: the big blinds a choice lost is the better choice's worth minus its own.
3. `review_best_iff`: the label is Best exactly when the choice was worth at least as much
   as the other one. When both are worth the same, both are Best.
4. `review_label_monotone`: a decision that lost more never gets a better label.
5. `review_call_best_iff_equity`: calling is Best exactly when the equity the human had is
   at least the equity needed.

T8 `no_hindsight`:
6. `no_hindsight`: two hands that look the same to the human get the same review, whatever
   cards the bot really holds and whatever cards are still in the deck.
7. `bot_hand_in_review`: the bot's real hand is one of the hands the review considers, so in
   a real game that list is never empty.
-/

/-! ## Counting wins, ties and losses -/

/-- Counting one more hand adds that hand's call result. -/
theorem addScores_callNum (c : Counts) (mine : List Nat) (prize cost : Nat) (h : RankedHand) :
    let c' := c.addScores mine h.score
    2 * c'.win * (prize : Int) + c'.tie * ((prize : Int) - cost) - 2 * c'.loss * (cost : Int) =
      2 * c.win * (prize : Int) + c.tie * ((prize : Int) - cost) - 2 * c.loss * (cost : Int) +
        callResult mine prize cost h := by
  simp only [Counts.addScores, callResult]
  split
  · simp only; push_cast; grind
  · split
    · simp only; push_cast; grind
    · simp only; push_cast; grind

/-- The review's call total, worked out from counts, is the sum of the call results. -/
theorem foldl_callNum (mine : List Nat) (prize cost : Nat) :
    ∀ (hands : List RankedHand) (c₀ : Counts),
    let c := hands.foldl (fun c h => c.addScores mine h.score) c₀
    2 * c.win * (prize : Int) + c.tie * ((prize : Int) - cost) - 2 * c.loss * (cost : Int) =
      2 * c₀.win * (prize : Int) + c₀.tie * ((prize : Int) - cost) - 2 * c₀.loss * (cost : Int) +
        (hands.map (callResult mine prize cost)).sum
  | [], c₀ => by simp
  | h :: hs, c₀ => by
    simp only [List.foldl_cons, List.map_cons, List.sum_cons]
    rw [foldl_callNum mine prize cost hs, addScores_callNum]
    grind

/-- The number of hands counted grows by one per hand. -/
theorem foldl_total (mine : List Nat) :
    ∀ (hands : List RankedHand) (c₀ : Counts),
    (hands.foldl (fun c h => c.addScores mine h.score) c₀).total = c₀.total + hands.length
  | [], c₀ => by simp
  | h :: hs, c₀ => by
    simp only [List.foldl_cons, List.length_cons]
    rw [foldl_total mine hs]
    simp only [Counts.addScores, Counts.total]
    split
    · simp only; omega
    · split <;> (simp only; omega)

/-- The review's call total is the spec's `choiceTotal` for calling. -/
theorem scoreCounts_callNum (hands : List RankedHand) (mine : List Nat) (prize cost : Nat) :
    let c := scoreCounts mine hands
    2 * c.win * (prize : Int) + c.tie * ((prize : Int) - cost) - 2 * c.loss * (cost : Int) =
      choiceTotal hands mine prize cost .call := by
  simp only [scoreCounts, choiceTotal]
  rw [foldl_callNum]
  simp [Counts.zero]

/-- Every hand is counted once: as a win, a tie or a loss. -/
theorem scoreCounts_total (hands : List RankedHand) (mine : List Nat) :
    (scoreCounts mine hands).total = hands.length := by
  have := foldl_total mine hands Counts.zero
  simpa [scoreCounts, Counts.zero, Counts.total] using this

/-! ## Labels -/

/-- The label is Best exactly when nothing was lost. -/
theorem labelFor_best_iff (x : Frac) : labelFor x = .best ↔ x.num ≤ 0 := by
  simp only [labelFor]
  by_cases h : x.num ≤ 0
  · simp [h]
  · simp only [h, ite_false, iff_false]
    repeat' split
    all_goals simp

/-- If `b` is below the line `p / q`, so is any smaller `a`. -/
theorem below_of_le {a b : Frac} (ha : 0 < a.den) (hb : 0 < b.den)
    (hab : a.num * b.den ≤ b.num * a.den) (p q : Nat)
    (hbelow : b.num * q < p * b.den) : a.num * q < p * a.den := by
  have h1 : a.num * b.den * q ≤ b.num * a.den * q :=
    Int.mul_le_mul_of_nonneg_right hab (by omega)
  have h2 : b.num * q * a.den < p * b.den * a.den :=
    Int.mul_lt_mul_of_pos_right hbelow (by omega)
  rw [Int.mul_right_comm a.num, Int.mul_right_comm b.num] at h1
  rw [Int.mul_right_comm (p : Int)] at h2
  exact Int.lt_of_mul_lt_mul_right (Int.lt_of_le_of_lt h1 h2) (by omega)

/-- If `b` is at most 0, so is any smaller `a`. -/
theorem nonpos_of_le {a b : Frac} (hb : 0 < b.den)
    (hab : a.num * b.den ≤ b.num * a.den) (hbnp : b.num ≤ 0) : a.num ≤ 0 := by
  have h1 : b.num * a.den ≤ 0 * a.den := Int.mul_le_mul_of_nonneg_right hbnp (by omega)
  rw [Int.zero_mul] at h1
  apply Int.not_lt.mp
  intro hpos
  have : 0 < a.num * b.den := Int.mul_pos hpos (by omega)
  omega

/-- A bigger loss never gets a better label. -/
theorem labelFor_monotone {a b : Frac} (ha : 0 < a.den) (hb : 0 < b.den) (hab : a.LE b) :
    (labelFor a).rank ≤ (labelFor b).rank := by
  have h0 : b.num ≤ 0 → a.num ≤ 0 := nonpos_of_le hb hab
  have h1 := below_of_le ha hb hab 1 2
  have h2 := below_of_le ha hb hab 2 1
  have h3 := below_of_le ha hb hab 5 1
  simp only [labelFor]
  repeat' split
  all_goals simp only [ReviewLabel.rank]
  all_goals first | omega | simp_all

/-! ## The grade, for any list of bot hands -/

theorem grade_lost (hands : List RankedHand) (mine : List Nat) (prize cost : Nat)
    (choice : RiverChoice) :
    (gradeRiver hands mine prize cost choice).lost.num =
      max (choiceTotal hands mine prize cost .call) (choiceTotal hands mine prize cost .fold) -
        choiceTotal hands mine prize cost choice := by
  have key := scoreCounts_callNum hands mine prize cost
  simp only at key
  cases choice <;> simp [gradeRiver, key, choiceTotal]

theorem grade_best_iff (hands : List RankedHand) (mine : List Nat) (prize cost : Nat)
    (choice : RiverChoice) :
    (gradeRiver hands mine prize cost choice).label = .best ↔
      choiceTotal hands mine prize cost choice.other ≤ choiceTotal hands mine prize cost choice := by
  have hl := grade_lost hands mine prize cost choice
  have hb : (gradeRiver hands mine prize cost choice).label =
      labelFor (gradeRiver hands mine prize cost choice).lost := rfl
  rw [hb, labelFor_best_iff, hl]
  cases choice <;> simp [RiverChoice.other, choiceTotal] <;> omega

/-! ## T5: the review is sound -/

/-- **The worth of each choice.** When the bot can hold at least one hand, the review's worth
of calling is the spec's total for calling over twice the number of hands, in big blinds
(`2 * hands * bigBlind` half-chips make one big blind per hand). Folding is worth 0. -/
theorem review_worth (spot : RiverSpot) (choice : RiverChoice) (hn : spot.botHands ≠ []) :
    (reviewRiver spot choice).worthCall =
      ⟨spot.total .call, 2 * spot.botHands.length * bigBlind⟩ ∧
    (reviewRiver spot choice).worthFold.num = spot.total .fold := by
  have key := scoreCounts_callNum spot.botHands spot.myScore spot.prize spot.cost
  simp only at key
  have hlen : 0 < spot.botHands.length := List.length_pos_iff.mpr hn
  have hmax : max spot.botHands.length 1 = spot.botHands.length := by omega
  simp [reviewRiver, gradeRiver, key, hmax, RiverSpot.total, choiceTotal]

/-- **Big blinds lost.** What a choice lost is the better choice's total minus its own. Its
denominator is the same as the worths' (`review_worth`), so it is in big blinds too. -/
theorem review_lost (spot : RiverSpot) (choice : RiverChoice) :
    (reviewRiver spot choice).lost.num =
      max (spot.total .call) (spot.total .fold) - spot.total choice ∧
    (reviewRiver spot choice).lost.den = (reviewRiver spot choice).worthCall.den :=
  ⟨grade_lost _ _ _ _ _, rfl⟩

/-- **Best means nothing lost (T5).** The review labels a call or fold Best exactly when it
was worth at least as much as the other choice. -/
theorem review_best_iff (spot : RiverSpot) (choice : RiverChoice) :
    (reviewRiver spot choice).label = .best ↔ spot.total choice.other ≤ spot.total choice :=
  grade_best_iff _ _ _ _ _

/-- **Labels only get worse as the loss grows (T5).** For any two graded decisions, the one
that lost fewer big blinds never gets a worse label. -/
theorem review_label_monotone (s₁ s₂ : RiverSpot) (c₁ c₂ : RiverChoice)
    (hle : (reviewRiver s₁ c₁).lost.LE (reviewRiver s₂ c₂).lost) :
    (reviewRiver s₁ c₁).label.rank ≤ (reviewRiver s₂ c₂).label.rank := by
  have hden : ∀ s c, 0 < (reviewRiver s c).lost.den := by
    intro s c
    simp only [reviewRiver, gradeRiver, bigBlind]
    omega
  exact labelFor_monotone (hden _ _) (hden _ _) hle

/-- **Calling is Best exactly when the equity was enough.** When the bot can hold at least
one hand and calling costs something, calling is Best exactly when the equity the human had
is at least the equity needed. -/
theorem review_call_best_iff_equity (spot : RiverSpot) (hn : spot.botHands ≠ [])
    (hcost : 0 < spot.cost) :
    (reviewRiver spot .call).label = .best ↔
      (reviewRiver spot .call).equityNeeded.LE (reviewRiver spot .call).equityHad := by
  rw [review_best_iff]
  have key := scoreCounts_callNum spot.botHands spot.myScore spot.prize spot.cost
  have htot := scoreCounts_total spot.botHands spot.myScore
  simp only at key
  have hlen : 0 < spot.botHands.length := List.length_pos_iff.mpr hn
  simp only [RiverSpot.total, RiverChoice.other]
  rw [← key]
  simp only [choiceTotal, Frac.LE, reviewRiver, gradeRiver]
  generalize scoreCounts spot.myScore spot.botHands = c at htot ⊢
  simp only [Counts.total] at htot
  have hmax : max spot.botHands.length 1 = c.win + c.tie + c.loss := by omega
  have hmax2 : max (spot.prize + spot.cost) 1 = spot.prize + spot.cost := by omega
  rw [hmax, hmax2]
  push_cast
  constructor <;> intro h <;> grind

/-! ## T8: no hindsight -/

/-- **No hindsight (T8).** Two hands that look the same to the human (same chips, board and
human cards) get the same review of a call or fold, whatever cards the bot really holds. -/
theorem no_hindsight (h₁ h₂ : Hand) (bluffPct : Nat) (choice : RiverChoice)
    (hsame : SameForHuman h₁ h₂) :
    reviewRiver (riverSpotOf h₁ bluffPct) choice = reviewRiver (riverSpotOf h₂ bluffPct) choice := by
  obtain ⟨hchips, hboard, hmine⟩ := hsame
  have : riverSpotOf h₁ bluffPct = riverSpotOf h₂ bluffPct := by
    simp only [riverSpotOf]
    rw [hchips, hboard, ← hmine, hchips]
  rw [this]

/-- **The bot's real hand is in the review.** If the bot bets its two cards on the river with
no bet to face, and they are not the human's cards, then they are one of the hands the
review considers. So in a real game the review's list of hands is never empty. -/
theorem bot_hand_in_review (spot : RiverSpot) (botCards : List Card)
    (hbets : riverBets spot.bluffPct spot.board botCards = true)
    (hapart : ∀ c ∈ botCards, c ∉ spot.hole) :
    ∃ h ∈ spot.botHands, h.isHole botCards = true := by
  simp only [riverBets, riverRole] at hbets
  have hany : ((riverBettingSet spot.bluffPct spot.board).value ++
      (riverBettingSet spot.bluffPct spot.board).bluffs).any (·.isHole botCards) = true := by
    split at hbets
    · simp_all [List.any_append]
    · split at hbets
      · simp_all [List.any_append]
      · simp at hbets
  obtain ⟨h, hmem, hh⟩ := List.any_eq_true.mp hany
  refine ⟨h, ?_, hh⟩
  simp only [RiverSpot.botHands, List.mem_filter]
  refine ⟨hmem, ?_⟩
  simp only [RankedHand.isHole, Bool.and_eq_true, List.contains_iff_mem] at hh
  simp [RiverSpot.blocks, hapart _ hh.1, hapart _ hh.2]

/-- In every graded decision the bot can hold at least one hand, as `review_worth` and
`review_call_best_iff_equity` assume: the bot opened the river with a bet, so its real hand
is in its betting set (`bot_hand_in_review`). -/
theorem botHands_ne_nil (spot : RiverSpot) (botCards : List Card)
    (hbets : riverBets spot.bluffPct spot.board botCards = true)
    (hapart : ∀ c ∈ botCards, c ∉ spot.hole) : spot.botHands ≠ [] := by
  obtain ⟨h, hmem, _⟩ := bot_hand_in_review spot botCards hbets hapart
  exact List.ne_nil_of_mem hmem

/-! ## Checks on the statements

The kernel cannot work out a real betting set (1,081 hands, each scored and sorted), so the
concrete checks on real spots are `#guard`s, run by the compiled code. The checks that the
statements reject bad graders use small hand lists that the kernel can work out. -/

-- The hypotheses hold on a real spot: the bot can hold some hand, and calling costs chips.
#guard exRiverSpot.botHands != []
#guard 0 < exRiverSpot.cost
-- The bot bets two aces on this board, and they are not the human's cards.
#guard riverBets exRiverSpot.bluffPct exRiverSpot.board [card 14 .hearts, card 14 .diamonds]

/-- Two bot hands: one scores higher than the human's `[3]`, one lower. -/
def exHands : List RankedHand :=
  [⟨(card 14 .spades, card 14 .hearts), [5]⟩, ⟨(card 2 .spades, card 3 .hearts), [1]⟩]

-- Calling 50 to win 150 against them: lose 100 half-chips, win 300, so 200 in total.
example : choiceTotal exHands [3] 150 50 .call = 200 := by decide
-- So calling is Best and folding is not, and the worth of calling is 200 / 40 = 5 big blinds.
example : (gradeRiver exHands [3] 150 50 .call).label = .best := by decide
example : (gradeRiver exHands [3] 150 50 .fold).label = .blunder := by decide
example : (gradeRiver exHands [3] 150 50 .call).worthCall = ⟨200, 2 * 2 * bigBlind⟩ := by decide

/-- What "Best means nothing lost" asks of any grader. -/
def BestMeansNoLoss
    (grade : List RankedHand → List Nat → Nat → Nat → RiverChoice → ReviewLabel) : Prop :=
  ∀ hands mine prize cost choice, grade hands mine prize cost choice = .best ↔
    choiceTotal hands mine prize cost choice.other ≤ choiceTotal hands mine prize cost choice

example : BestMeansNoLoss fun hands mine prize cost choice =>
    (gradeRiver hands mine prize cost choice).label :=
  grade_best_iff

/-- A grader that calls every choice Best is rejected: folding above lost 200 half-chips. -/
example : ¬ BestMeansNoLoss fun _ _ _ _ _ => .best := by
  intro h
  have := (h exHands [3] 150 50 .fold).mp rfl
  revert this
  decide

/-- What "a bigger loss never gets a better label" asks of any labelling. -/
def LabelsMonotone (f : Frac → ReviewLabel) : Prop :=
  ∀ a b : Frac, 0 < a.den → 0 < b.den → a.LE b → (f a).rank ≤ (f b).rank

example : LabelsMonotone labelFor := fun _ _ ha hb hab => labelFor_monotone ha hb hab

/-- A labelling with the bands in the wrong order: a loss under half a big blind is a Blunder. -/
def badLabelFor (x : Frac) : ReviewLabel :=
  if x.num ≤ 0 then .best else if x.num * 2 < x.den then .blunder else .good

/-- It is rejected: losing a quarter of a big blind would get a worse label than losing one. -/
example : ¬ LabelsMonotone badLabelFor := by
  intro h
  have := h ⟨1, 4⟩ ⟨1, 1⟩ (by decide) (by decide) (by unfold Frac.LE; decide)
  revert this
  decide

/-- What "no hindsight" asks of any review: hands that look the same to the human get the
same review. -/
def NoHindsight {α : Type} (review : Hand → RiverChoice → α) : Prop :=
  ∀ h₁ h₂ choice, SameForHuman h₁ h₂ → review h₁ choice = review h₂ choice

example (bluffPct : Nat) : NoHindsight fun h choice => reviewRiver (riverSpotOf h bluffPct) choice :=
  fun h₁ h₂ choice hs => no_hindsight h₁ h₂ bluffPct choice hs

/-- A river hand: the human (player 0) holds K-T on 2c 7d Js Qh 9s and faces the bot's bet
of 50 into 100. The bot holds the other K-T. -/
def exRiverHand : Hand :=
  { chips := { stack := fun _ => 400, pot := 100, bet := fun p => if p = 0 then 0 else 50,
               lastRaise := 50, toAct := 0 },
    street := .river, button := 0,
    hole := fun p => if p = 0 then [card 13 .clubs, card 10 .diamonds]
      else [card 13 .spades, card 10 .hearts],
    board := exRiverSpot.board, deck := [], acted := fun _ => false, ended := none }

/-- The same hand, but the bot holds 4-3. -/
def exRiverHand' : Hand :=
  { exRiverHand with hole := setFor exRiverHand.hole 1 [card 4 .diamonds, card 3 .clubs] }

-- The hypothesis can hold: the two hands look the same to the human.
example : SameForHuman exRiverHand exRiverHand' := ⟨rfl, rfl, by decide⟩

-- The review is the same in both, and it is the review of `exRiverSpot`.
#guard riverSpotOf exRiverHand 33 == exRiverSpot
#guard (reviewRiver (riverSpotOf exRiverHand 33) .call).label ==
  (reviewRiver (riverSpotOf exRiverHand' 33) .call).label

/-- A review that looks at the bot's real cards is rejected. -/
example : ¬ NoHindsight fun h (_ : RiverChoice) => h.hole (other h.chips.toAct) := by
  intro h
  have := h exRiverHand exRiverHand' .call ⟨rfl, rfl, by decide⟩
  revert this
  decide

/-! ## Axioms: only `propext`, `Classical.choice` and `Quot.sound` are allowed -/

#print axioms review_worth
#print axioms review_lost
#print axioms review_best_iff
#print axioms review_label_monotone
#print axioms review_call_best_iff_equity
#print axioms no_hindsight
#print axioms bot_hand_in_review
#print axioms botHands_ne_nil
