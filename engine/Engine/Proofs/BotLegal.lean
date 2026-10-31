import Engine.Proofs.BotSpec

/-!
# T3, bot half: the slider bot only makes legal moves

The bot picks one of four kinds of move: fold, call (only when it owes chips), check (only
when it owes nothing), or a raise cut down to the legal raise sizes. Each kind is legal
whenever the player to act may act at all.
-/

/-- Every raise size kept inside `State.raiseBounds` is legal. -/
theorem clampTo_raiseBounds_legal (s : State) (lo hi t : Nat)
    (hb : s.raiseBounds = some (lo, hi)) : Legal s (.raiseTo (clampTo t lo hi)) := by
  unfold State.raiseBounds at hb
  split at hb
  · next hl =>
    cases hb
    obtain ⟨hm, ho, hgt, -, -⟩ := hl
    refine ⟨hm, ho, ?_, ?_, ?_⟩ <;>
      simp only [clampTo, State.allIn, State.minRaise, bigBlind] at * <;> omega
  · cases hb

/-- The four kinds of move the bot can pick from a view. -/
theorem decideView_cases (v : View) (c : Counts) :
    (decideView v c).action = .fold ∨
    ((decideView v c).action = .call ∧ 0 < v.toCall) ∨
    ((decideView v c).action = .check ∧ v.toCall = 0) ∨
    ∃ t lo hi, v.raise = some (lo, hi) ∧ (decideView v c).action = .raiseTo (clampTo t lo hi) := by
  unfold decideView decideView.callOrFold decideView.checkMove riverOpening
  by_cases hc : 0 < v.toCall
  · simp only [hc, ↓reduceIte]
    split
    · next lo hi hr =>
      split
      · exact .inr (.inr (.inr ⟨_, lo, hi, hr, rfl⟩))
      · split
        · exact .inr (.inl ⟨rfl, trivial⟩)
        · exact .inl rfl
    · split
      · exact .inr (.inl ⟨rfl, trivial⟩)
      · exact .inl rfl
  · have h0 : v.toCall = 0 := by omega
    simp only [hc, ↓reduceIte]
    split
    · split
      · split
        · next lo hi hr => exact .inr (.inr (.inr ⟨_, lo, hi, hr, rfl⟩))
        · exact .inr (.inr (.inl ⟨rfl, h0⟩))
      · exact .inr (.inr (.inl ⟨rfl, h0⟩))
    · split
      · next lo hi hr =>
        split
        · exact .inr (.inr (.inr ⟨_, lo, hi, hr, rfl⟩))
        · exact .inr (.inr (.inl ⟨rfl, h0⟩))
      · exact .inr (.inr (.inl ⟨rfl, h0⟩))

/-- For given counts, the bot's move is legal whenever the player to act may act. -/
theorem decideWithCounts_legal (sl : Sliders) (c : Counts) (hole board : List Card) :
    AlwaysLegal fun s => (decideWithCounts sl c hole board s).action := by
  intro s hm
  rcases decideView_cases (viewOf sl hole board s) c with h | ⟨h, hc⟩ | ⟨h, hc⟩ | ⟨t, lo, hi, hb, h⟩ <;>
    simp only [decideWithCounts, h]
  · exact ⟨hm, trivial⟩
  · exact ⟨hm, hc⟩
  · exact ⟨hm, hc⟩
  · exact clampTo_raiseBounds_legal s lo hi t hb

/-- **T3, bot half: the slider bot only makes legal moves.** For every slider setting,
seed, hole cards and board: whenever the player to act may act at all, the bot's move is
legal. -/
theorem botDecide_legal (sl : Sliders) (seed : Nat) (hole board : List Card) :
    AlwaysLegal fun s => (botDecide sl seed hole board s).action :=
  decideWithCounts_legal sl (countsFor seed hole board) hole board

/-! ## Checks -/

/-- The theorem's condition can hold: at the start of a hand the small blind may act, and
the bot's move there is legal. -/
example : Legal exStart (botDecide ⟨50, 20⟩ 7 [] [] exStart).action :=
  botDecide_legal ⟨50, 20⟩ 7 [] [] exStart (by decide)

#print axioms botDecide_legal
