import Engine.Proofs.Deck
import Engine.Proofs.EndsSpec
import Engine.Proofs.BoardSpec

/-!
# The board has the right number of cards

For a hand dealt with `startHand` and played with any accepted moves:

- **During play** (`board_matches_street`): the board has as many cards as the street says
  (`Street.boardCards`): 0 before the flop, 3 on the flop, 4 on the turn, 5 on the river.
- **At a showdown** (`showdown_has_five_cards`): the board has all 5 cards. A hand never
  goes to a showdown early, for example after the flop.

## How the proof works

While a hand is played, the board size and the number of undealt cards are fixed by the
street (`BoardShape`): 0 and 48 before the flop (52 cards, 4 dealt to the players), then 3
and 44, 4 and 42, 5 and 40 (each street burns one card and turns up the rest). Every part
of the engine keeps this, and a showdown is only paid on the river.
-/

/-- Undealt cards left during each street: 52, minus 4 hole cards, minus each street's
burn card and board cards. (A proof helper; no main theorem mentions it.) -/
def Street.deckLeft : Street → Nat
  | .preflop => 48
  | .flop => 44
  | .turn => 42
  | .river => 40

/-- During play, the board and the undealt cards have the sizes the street says. -/
def BoardShape (h : Hand) : Prop :=
  h.board.length = h.street.boardCards ∧ h.deck.length = h.street.deckLeft

/-- A hand is on track: during play it has the right shape, and a showdown has 5 cards. -/
def BoardOk (h : Hand) : Prop :=
  (h.ended = none → BoardShape h) ∧
  (∀ r, h.ended = some (.showdown r) → h.board.length = 5)

theorem boardOk_of_shape {h : Hand} (hn : h.ended = none) (hs : BoardShape h) : BoardOk h :=
  ⟨fun _ => hs, fun r he => by simp [hn] at he⟩

/-! ## Each part of the engine keeps the shape -/

/-- A fold ends the hand without a showdown. -/
theorem payFold_boardOk (h : Hand) (w : Player) : BoardOk (h.payFold w) :=
  ⟨fun he => by simp [Hand.payFold] at he, fun r he => by simp [Hand.payFold] at he⟩

/-- A showdown on a board of 5 cards. -/
theorem payShowdown_boardOk (h : Hand) (h5 : h.board.length = 5) : BoardOk h.payShowdown :=
  ⟨fun he => by simp [Hand.payShowdown] at he, fun r _ => by simpa [Hand.payShowdown] using h5⟩

/-- Ending betting rounds keeps the hand on track, however many rounds are ended. -/
theorem finishStreet_boardOk (fuel : Nat) (h : Hand) (hn : h.ended = none)
    (hs : BoardShape h) : BoardOk (h.finishStreet fuel) := by
  induction fuel generalizing h with
  | zero => exact boardOk_of_shape hn hs
  | succ fuel ih =>
    obtain ⟨hb, hd⟩ := hs
    -- After dealing the next street, either someone gets the turn or the next round ends too.
    have next : ∀ (h₁ : Hand), h₁.ended = none → BoardShape h₁ →
        BoardOk (match h₁.nextToAct (other h₁.button) with
          | some p => { h₁ with chips := { h₁.chips with toAct := p } }
          | none => Hand.finishStreet fuel h₁) := by
      intro h₁ hn₁ hs₁
      split
      · exact boardOk_of_shape hn₁ hs₁
      · exact ih _ hn₁ hs₁
    cases hst : h.street with
    | preflop =>
      simp only [Street.boardCards, Street.deckLeft, hst] at hb hd
      simp only [Hand.finishStreet, hst]
      exact next _ (by simpa [Hand.dealBoard] using hn)
        ⟨by simp [Hand.dealBoard, Street.boardCards]; omega,
         by simp [Hand.dealBoard, Street.deckLeft]; omega⟩
    | flop =>
      simp only [Street.boardCards, Street.deckLeft, hst] at hb hd
      simp only [Hand.finishStreet, hst]
      exact next _ (by simpa [Hand.dealBoard] using hn)
        ⟨by simp [Hand.dealBoard, Street.boardCards]; omega,
         by simp [Hand.dealBoard, Street.deckLeft]; omega⟩
    | turn =>
      simp only [Street.boardCards, Street.deckLeft, hst] at hb hd
      simp only [Hand.finishStreet, hst]
      exact next _ (by simpa [Hand.dealBoard] using hn)
        ⟨by simp [Hand.dealBoard, Street.boardCards]; omega,
         by simp [Hand.dealBoard, Street.deckLeft]; omega⟩
    | river =>
      simp only [Street.boardCards, hst] at hb
      simp only [Hand.finishStreet, hst]
      exact payShowdown_boardOk _ hb

/-- Passing the turn keeps the hand on track. -/
theorem passTurn_boardOk (h : Hand) (first : Player) (hn : h.ended = none)
    (hs : BoardShape h) : BoardOk (h.passTurn first) := by
  unfold Hand.passTurn
  split
  · exact boardOk_of_shape hn hs
  · exact finishStreet_boardOk _ _ hn hs

/-- An accepted move keeps the hand on track. -/
theorem step_boardOk (h h' : Hand) (a : Action) (hok : BoardOk h)
    (hs : step h a = .ok h') : BoardOk h' := by
  unfold step at hs
  split at hs
  · cases hs
  next hn =>
  have hn : h.ended = none := by simpa using hn
  have hsh := hok.1 hn
  split at hs
  · cases hs
  split at hs
  · cases hs; exact payFold_boardOk _ _
  · cases hs; exact passTurn_boardOk _ _ hn hsh

/-- Dealing from a 52-card deck: no board yet, before the flop, 48 cards left. -/
theorem dealFrom_shape (stacks : Player → Nat) (button : Player) (d : List Card)
    (h52 : d.length = 52) : (dealFrom stacks button d).ended = none ∧
      BoardShape (dealFrom stacks button d) := by
  rcases d with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨e, rest⟩⟩⟩⟩
  all_goals try (simp at h52; done)
  simp at h52
  exact ⟨rfl, by simp [BoardShape, dealFrom, Street.boardCards, Street.deckLeft]; omega⟩

/-- A new hand starts on track. -/
theorem startHand_boardOk (stacks : Player → Nat) (button : Player) (seed : Nat) :
    BoardOk (startHand stacks button seed) := by
  have h52 : (shuffle seed fullDeck).length = 52 := by
    rw [(shuffle_same_cards seed fullDeck).length_eq]; rfl
  obtain ⟨hn, hs⟩ := dealFrom_shape stacks button _ h52
  unfold startHand
  rw [dealHand_eq_dealFrom]
  exact passTurn_boardOk _ _ hn hs

/-- Any run of accepted moves keeps the hand on track. -/
theorem runsTo_boardOk (as : List Action) (h h' : Hand) (hok : BoardOk h)
    (hrun : RunsTo h as h') : BoardOk h' := by
  induction as generalizing h with
  | nil => simp only [RunsTo, RunsWith] at hrun; subst hrun; exact hok
  | cons a as ih =>
    obtain ⟨h₁, hs, hrest⟩ := hrun
    exact ih h₁ (step_boardOk _ _ _ hok hs) hrest

/-! ## The main theorems -/

/-- **The board matches the street.** Deal a hand and play any accepted moves. While the
hand is not over, the board has exactly as many cards as the street says: 0 before the
flop, 3 on the flop, 4 on the turn, 5 on the river. -/
theorem board_matches_street (stacks : Player → Nat) (button : Player) (seed : Nat)
    (as : List Action) (h' : Hand) (hrun : RunsTo (startHand stacks button seed) as h')
    (hnot : h'.ended = none) : h'.board.length = h'.street.boardCards :=
  ((runsTo_boardOk as _ h' (startHand_boardOk stacks button seed) hrun).1 hnot).1

/-- **A showdown has all five board cards.** Deal a hand and play any accepted moves. If
the hand ends at a showdown, the board has 5 cards: the hand was never shown down early. -/
theorem showdown_has_five_cards (stacks : Player → Nat) (button : Player) (seed : Nat)
    (as : List Action) (h' : Hand) (hrun : RunsTo (startHand stacks button seed) as h')
    (r : Outcome) (hend : h'.ended = some (.showdown r)) : h'.board.length = 5 :=
  (runsTo_boardOk as _ h' (startHand_boardOk stacks button seed) hrun).2 r hend

/-! ## Checks -/

/-- A real hand, 500 chips each: the small blind calls and the big blind checks, so the flop
is dealt. -/
def flopHand : Except String Hand :=
  (step (startHand (fun _ => startingStack) 0 7) .call).bind (step · .check)

-- It is on the flop, still being played, with 3 cards on the board.
#guard match flopHand with
  | .ok h => h.street == .flop && h.ended.isNone && h.board.length == 3
  | .error _ => false

/-- `board_matches_street` applies to a fresh real deal: before the flop, no board cards. -/
example : (startHand (fun _ => startingStack) 0 7).board.length = Street.boardCards .preflop :=
  board_matches_street (fun _ => startingStack) 0 7 [] _ rfl rfl

/-- `showdown_has_five_cards` applies to a real deal that ends at a showdown (3 chips each,
so both blinds are all-in and the board is dealt out). -/
example : ∃ r, (startHand (fun _ => 3) 0 7).ended = some (.showdown r) := ⟨_, rfl⟩

example : (startHand (fun _ => 3) 0 7).board.length = 5 :=
  let ⟨r, hr⟩ : ∃ r, (startHand (fun _ => 3) 0 7).ended = some (.showdown r) := ⟨_, rfl⟩
  showdown_has_five_cards (fun _ => 3) 0 7 [] _ rfl r hr

/-- The statements reject a short board: a showdown after the flop (3 cards) is not 5, and
a flop with 4 cards does not match the street. -/
example : ¬ ((3 : Nat) = 5) := by decide
example : ¬ ((4 : Nat) = Street.boardCards .flop) := by decide

#print axioms board_matches_street
#print axioms showdown_has_five_cards
