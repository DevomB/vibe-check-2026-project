import Engine.Proofs.BotSpec
import Engine.Proofs.BluffFrequency
import Engine.Proofs.Review
import Engine.Proofs.Reachable

/-!
# T7, the link to the bot: the slider bot bets exactly its river betting set

T7 (`bluff_frequency`, `Engine/Proofs/BluffFrequency.lean`) counts the bluffs in the river
betting set `riverBettingSet`. MVP §8 asks that this be "the same set as the actual bot".
`bot_bets_its_set` says the helper `riverRole` reads that set. Here the bot itself,
`botDecide` (`Engine/Slider.lean`), is shown to follow it:

1. `botDecide_river_follows_set`: on the river, with nothing to call and a bet allowed, the
   bot bets exactly when its two cards are a value hand or a designated bluff of the set,
   and checks exactly when they are not.
2. `review_hands_ne_nil`: when the human faces the bot's opening river bet, the list of hands
   the review considers is not empty, because the bot's own hand is in it.
-/

/-! ## Helpers -/

/-- If any raise is legal, the bot's raise bounds are set: going all-in is legal too. -/
theorem raiseBounds_some_of_legal {s : State} {n : Nat} (h : Legal s (.raiseTo n)) :
    ∃ lo hi, s.raiseBounds = some (lo, hi) := by
  have hall : Legal s (.raiseTo s.allIn) := by
    obtain ⟨⟨hm1, hm2⟩, ho, hgt, hle, -⟩ := h
    refine ⟨⟨hm1, hm2⟩, ho, ?_, ?_, ?_⟩ <;> simp only [State.allIn] <;> omega
  simp only [State.raiseBounds, hall, ↓reduceIte]
  exact ⟨_, _, rfl⟩

/-- With nothing to call on the river, the bot's move is `riverOpening`'s. -/
theorem botDecide_river (sl : Sliders) (seed : Nat) (hole board : List Card) (s : State)
    (h5 : board.length = 5) (h0 : s.toCall = 0) :
    botDecide sl seed hole board s = riverOpening (viewOf sl hole board s) := by
  have hv : ¬ (viewOf sl hole board s).toCall > 0 := by
    show ¬ s.toCall > 0
    omega
  have hb : (viewOf sl hole board s).board.length = 5 := h5
  simp only [botDecide, decideWithCounts, decideView, hv, hb, ↓reduceIte]

/-- If the bot's river move, with nothing to call, was a bet, its cards are in the betting
set: `riverBets` is true. -/
theorem riverBets_of_botDecide {sl : Sliders} {seed n : Nat} {hole board : List Card}
    {s : State} (h5 : board.length = 5) (h0 : s.toCall = 0)
    (hbet : (botDecide sl seed hole board s).action = .raiseTo n) :
    riverBets sl.bluffPct board hole = true := by
  rw [botDecide_river sl seed hole board s h5 h0] at hbet
  simp only [riverOpening, riverBetOrCheck, viewOf] at hbet
  unfold riverBets
  cases hrole : riverRole sl.bluffPct board hole
  · decide
  · decide
  · simp [hrole] at hbet

/-- When no card was dealt twice, the cards of the player who is not to act are not the
cards of the player to act. -/
theorem hole_apart_of_nodup {h : Hand} (hnd : h.dealtCards.Nodup) :
    ∀ c ∈ h.hole (other h.chips.toAct), c ∉ h.hole h.chips.toAct := by
  simp only [Hand.dealtCards, List.nodup_append] at hnd
  obtain ⟨⟨-, -, hdisj⟩, -, -⟩ := hnd
  have hp : ∀ p : Player, p = 0 ∨ p = 1 := by decide
  have h01 : other 0 = 1 := by decide
  have h10 : other 1 = 0 := by decide
  intro c hc hc'
  rcases hp h.chips.toAct with hp | hp <;> rw [hp] at hc hc'
  · rw [h01] at hc
    exact hdisj c hc' c hc rfl
  · rw [h10] at hc
    exact hdisj c hc c hc' rfl

/-! ## The theorems -/

/-- **The bot bets exactly its river betting set.** On the river (five board cards), with
nothing to call and some bet legal, the slider bot bets (its move is a `raiseTo`) exactly
when its two cards `a`, `b` are a value hand or a designated bluff of `riverBettingSet` at
its Bluff setting, in either order; and it checks exactly when they are not. The seed and
the Risk setting play no part. -/
theorem botDecide_river_follows_set (sl : Sliders) (seed : Nat) (a b : Card)
    (board : List Card) (s : State) (h5 : board.length = 5) (h0 : s.toCall = 0)
    (hbet : ∃ n, Legal s (.raiseTo n)) :
    ((∃ n, (botDecide sl seed [a, b] board s).action = .raiseTo n) ↔
      ∃ h ∈ (riverBettingSet sl.bluffPct board).value ++ (riverBettingSet sl.bluffPct board).bluffs,
        h.cards = (a, b) ∨ h.cards = (b, a)) ∧
    ((botDecide sl seed [a, b] board s).action = .check ↔
      ¬ ∃ h ∈ (riverBettingSet sl.bluffPct board).value ++ (riverBettingSet sl.bluffPct board).bluffs,
        h.cards = (a, b) ∨ h.cards = (b, a)) := by
  obtain ⟨n, hn⟩ := hbet
  obtain ⟨lo, hi, hb⟩ := raiseBounds_some_of_legal hn
  rw [← bot_bets_its_set, botDecide_river sl seed [a, b] board s h5 h0]
  simp only [riverOpening, riverBetOrCheck, viewOf, hb]
  cases riverRole sl.bluffPct board [a, b] <;> simp

/-- **The review always has the bot's hand to consider.** The human, to act in `h`, faces
the bot's opening river bet: the bot's move, with its own cards on this board and nothing to
call, was a bet. If no card was dealt twice, the review's list of hands the bot can hold is
not empty, because the bot's real hand is in it. -/
theorem review_hands_ne_nil (h : Hand) (sl : Sliders) (seed n : Nat) (s : State)
    (h5 : h.board.length = 5) (h0 : s.toCall = 0)
    (hbet : (botDecide sl seed (h.hole (other h.chips.toAct)) h.board s).action = .raiseTo n)
    (hnd : h.dealtCards.Nodup) :
    (riverSpotOf h sl.bluffPct).botHands ≠ [] :=
  botHands_ne_nil (riverSpotOf h sl.bluffPct) (h.hole (other h.chips.toAct))
    (riverBets_of_botDecide h5 h0 hbet) (hole_apart_of_nodup hnd)

/-! ## Checks on the statements -/

/-- A river state with nothing to call: 200 in the pot from earlier streets, no bets yet on
this street, the bot (player 1) to act, 400 chips each. -/
def exRiverOpenState : State :=
  { stack := fun _ => 400, pot := 200, bet := fun _ => 0, lastRaise := bigBlind, toAct := 1 }

-- The hypotheses hold on a real spot: five board cards, nothing to call, a bet is legal.
example : exBoard.length = 5 := rfl
example : exRiverOpenState.toCall = 0 := by decide
example : Legal exRiverOpenState (.raiseTo 400) := by decide

/-- So the theorem applies: with the red aces on 2c 7d Js Qh 9s at Bluff 33%, the bot bets
exactly when a hand with those two cards is in its betting set. -/
example : (∃ n, (botDecide ⟨50, 33⟩ 7 [card 14 .hearts, card 14 .diamonds] exBoard
      exRiverOpenState).action = .raiseTo n) ↔
    ∃ h ∈ (riverBettingSet 33 exBoard).value ++ (riverBettingSet 33 exBoard).bluffs,
      h.cards = (card 14 .hearts, card 14 .diamonds) ∨
        h.cards = (card 14 .diamonds, card 14 .hearts) :=
  (botDecide_river_follows_set ⟨50, 33⟩ 7 _ _ exBoard exRiverOpenState rfl (by decide)
    ⟨400, by decide⟩).1

-- The kernel cannot work out a real betting set (1,081 hands scored and sorted), so the
-- compiled code checks the concrete outcomes: the aces are a value hand and the bot bets the
-- pot; a pair of threes is in neither set and the bot checks.
#guard (botDecide ⟨50, 33⟩ 7 [card 14 .hearts, card 14 .diamonds] exBoard
  exRiverOpenState).action.text == "raise 200"
#guard (botDecide ⟨50, 33⟩ 7 [card 3 .hearts, card 3 .diamonds] exBoard
  exRiverOpenState).action.text == "check"

/-- What "bets exactly its river betting set" asks of any bot's move, given the bot's two
cards, the board and the chips. -/
def BetsItsSet (bluffPct : Nat) (bot : List Card → List Card → State → Action) : Prop :=
  ∀ (a b : Card) (board : List Card) (s : State), board.length = 5 → s.toCall = 0 →
    (∃ n, Legal s (.raiseTo n)) →
    ((∃ n, bot [a, b] board s = .raiseTo n) ↔
      ∃ h ∈ (riverBettingSet bluffPct board).value ++ (riverBettingSet bluffPct board).bluffs,
        h.cards = (a, b) ∨ h.cards = (b, a))

example (sl : Sliders) (seed : Nat) :
    BetsItsSet sl.bluffPct fun hole board s => (botDecide sl seed hole board s).action :=
  fun a b board s h5 h0 hbet => (botDecide_river_follows_set sl seed a b board s h5 h0 hbet).1

/-- A bot that always checks is rejected: the betting set on `exBoard` has 324 value hands,
so there is a hand it should bet. -/
example : ¬ BetsItsSet 33 fun _ _ _ => .check := by
  intro hbot
  have hlen := (bluff_frequency 33 exBoard rfl (by decide) (by decide)).1
  obtain ⟨v, hv⟩ := List.exists_mem_of_length_pos
    (l := (riverBettingSet 33 exBoard).value) (by omega)
  obtain ⟨n, hn⟩ := (hbot v.cards.1 v.cards.2 exBoard exRiverOpenState rfl (by decide)
    ⟨400, by decide⟩).mpr ⟨v, List.mem_append_left _ hv, Or.inl rfl⟩
  cases hn

/-- The state the bot bet from in `exRiverHand` (`Engine/Proofs/Review.lean`): 100 in the
pot, no bets yet, the bot to act with 450 chips. -/
def exRiverBetState : State :=
  { stack := fun _ => 450, pot := 100, bet := fun _ => 0, lastRaise := bigBlind, toAct := 1 }

-- The corollary's hypotheses hold on `exRiverHand`: five board cards, nothing to call when
-- the bot acted, and no card dealt twice.
example : exRiverHand.board.length = 5 := rfl
example : exRiverBetState.toCall = 0 := by decide
example : exRiverHand.dealtCards.Nodup := by decide
-- The compiled code checks that the bot bets its K-T there (the kernel cannot).
#guard (botDecide ⟨50, 33⟩ 7 (exRiverHand.hole (other exRiverHand.chips.toAct))
  exRiverHand.board exRiverBetState).action.text == "raise 100"

/-- With that bet as a hypothesis, the review's hand list for `exRiverHand` is not empty. -/
example (hbet : (botDecide ⟨50, 33⟩ 7 (exRiverHand.hole (other exRiverHand.chips.toAct))
      exRiverHand.board exRiverBetState).action = .raiseTo 100) :
    (riverSpotOf exRiverHand 33).botHands ≠ [] :=
  review_hands_ne_nil exRiverHand ⟨50, 33⟩ 7 100 exRiverBetState rfl (by decide) hbet (by decide)

/-! ## Axioms: only `propext`, `Classical.choice` and `Quot.sound` are allowed -/

#print axioms botDecide_river_follows_set
#print axioms review_hands_ne_nil
