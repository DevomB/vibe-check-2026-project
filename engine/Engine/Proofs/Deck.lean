import Engine.Proofs.Chips

/-!
# T2: no card is dealt twice

The shuffle only puts the 52 cards in a new order. After that, dealing only moves cards
from the deck to the players or the table, or throws a card away (the burn card). So the
cards on the table are always different from each other, and all come from the 52-card deck.
-/

/-! ## The shuffle -/

/-- Taking out the card at place `i` and putting it in front gives the same cards. -/
theorem pick_same_cards {α : Type} : ∀ (l : List α) (i : Nat) (h : i < l.length),
    (l[i] :: l.eraseIdx i).Perm l
  | [], _, h => by simp at h
  | x :: xs, 0, _ => by simp
  | x :: xs, j + 1, h => by
    simp only [List.getElem_cons_succ, List.eraseIdx_cons_succ]
    have hj : j < xs.length := by simpa using h
    exact (List.Perm.swap x xs[j] _).trans (.cons x (pick_same_cards xs j hj))

/-- Each pick of the shuffle keeps the same cards, so the whole shuffle does too. -/
theorem shuffleAux_same_cards {α : Type} :
    ∀ (fuel s : Nat) (l : List α), (shuffleAux fuel s l).Perm l
  | 0, _, l => by simp [shuffleAux]
  | _ + 1, _, [] => by simp [shuffleAux]
  | fuel + 1, s, x :: xs => by
    simp only [shuffleAux]
    exact (List.Perm.cons _ (shuffleAux_same_cards fuel _ _)).trans (pick_same_cards _ _ _)

/-- The shuffle only changes the order of the cards: nothing is added, lost or copied. -/
theorem shuffle_same_cards {α : Type} (seed : Nat) (l : List α) : (shuffle seed l).Perm l :=
  shuffleAux_same_cards _ _ _

/-- Every shuffled deck is fair: it has the 52 cards of a new deck, in some order. -/
theorem shuffle_fair (seed : Nat) : FairDeck (shuffle seed fullDeck) := shuffle_same_cards _ _

/-- A new deck has no card twice. Lean checks all 52 cards. -/
theorem fullDeck_nodup : fullDeck.Nodup := by decide

/-! ## The cards in a hand -/

/-- Every card a hand holds: the hidden cards, the shared cards, then the cards still in
the deck. -/
def Hand.allCards (h : Hand) : List Card := h.dealtCards ++ h.deck

/-- A list of cards is good if no card is in it twice and every card is from the 52-card deck. -/
def GoodCards (l : List Card) : Prop := l.Nodup ∧ ∀ c ∈ l, c ∈ fullDeck

/-- Taking cards out of a good list leaves a good list. -/
theorem GoodCards.of_sublist {l l' : List Card} (h : GoodCards l) (s : l'.Sublist l) :
    GoodCards l' :=
  ⟨h.1.sublist s, fun c hc => h.2 c (s.subset hc)⟩

/-- Putting the cards of a good list in another order leaves a good list. -/
theorem GoodCards.of_perm {l l' : List Card} (h : GoodCards l) (p : l'.Perm l) :
    GoodCards l' :=
  ⟨p.nodup_iff.2 h.1, fun c hc => h.2 c (p.subset hc)⟩

/-- Dealing the board (burn one card, then turn `n` cards up) only drops the burn card. -/
theorem dealBoard_cards (h : Hand) (n : Nat) :
    (h.dealBoard n).allCards.Sublist h.allCards := by
  have e : (h.dealBoard n).allCards = (h.hole 0 ++ h.hole 1 ++ h.board) ++ h.deck.drop 1 := by
    simp only [Hand.allCards, Hand.dealtCards, Hand.dealBoard, List.append_assoc,
      List.take_append_drop]
  rw [e]
  exact (List.drop_sublist 1 h.deck).append_left _

/-- Paying a showdown does not touch the cards. -/
theorem payShowdown_cards (h : Hand) : h.payShowdown.allCards = h.allCards := rfl

/-- Paying a fold does not touch the cards. -/
theorem payFold_cards (h : Hand) (w : Player) : (h.payFold w).allCards = h.allCards := rfl

/-- Ending betting rounds only deals the board or pays the pot. -/
theorem finishStreet_cards : ∀ (fuel : Nat) (h : Hand),
    (h.finishStreet fuel).allCards.Sublist h.allCards
  | 0, h => by simp [Hand.finishStreet]
  | fuel + 1, h => by
    simp only [Hand.finishStreet]
    split
    · exact (List.Sublist.refl _)
    · rename_i street n _
      have d := dealBoard_cards { h with chips := collectBets (returnUncalled h.chips),
                                         acted := fun _ => false } n
      split
      · exact d
      · exact (finishStreet_cards fuel _).trans d

/-- Passing the turn only changes whose turn it is, or ends the betting round. -/
theorem passTurn_cards (h : Hand) (first : Player) :
    (h.passTurn first).allCards.Sublist h.allCards := by
  unfold Hand.passTurn
  split
  · exact List.Sublist.refl _
  · exact finishStreet_cards 4 h

/-- An accepted move only moves chips, or deals the board, or pays the pot. -/
theorem step_cards (h h' : Hand) (a : Action) (hs : step h a = .ok h') :
    h'.allCards.Sublist h.allCards := by
  unfold step at hs
  split at hs
  · cases hs
  split at hs
  · cases hs
  split at hs
  · cases hs; rw [payFold_cards]; exact List.Sublist.refl _
  · cases hs; exact passTurn_cards _ _

/-- Dealing from any deck only hands its first four cards to the players: the hand holds
the same cards as the deck, in some order. (`dealFrom` is `dealHand` with the deck as an
input; see `Engine.Proofs.Chips`.) -/
theorem dealFrom_cards (stacks : Player → Nat) (button : Player) (d : List Card) :
    (dealFrom stacks button d).allCards.Perm d := by
  rcases d with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨e, rest⟩⟩⟩⟩
  all_goals try (simp [dealFrom, Hand.allCards, Hand.dealtCards]; done)
  rcases button with ⟨_ | _ | _, hb⟩
  · -- The button is player 0: player 1 gets the 1st and 3rd cards.
    simp only [dealFrom, Hand.allCards, Hand.dealtCards, other]
    simp
    exact ((List.Perm.swap a e _).cons b).trans
      ((List.Perm.swap a b _).trans (((List.Perm.swap c e _).cons b).cons a))
  · -- The button is player 1: player 0 gets the 1st and 3rd cards.
    simp only [dealFrom, Hand.allCards, Hand.dealtCards, other]
    simp
    exact List.Perm.swap b c _
  · omega

/-- A new deal holds exactly the cards of the shuffled deck, in some order. -/
theorem dealHand_cards (stacks : Player → Nat) (button : Player) (seed : Nat) :
    (dealHand stacks button seed).allCards.Perm (shuffle seed fullDeck) := by
  rw [dealHand_eq_dealFrom]
  exact dealFrom_cards _ _ _

/-- A newly dealt hand has good cards. -/
theorem startHand_good (stacks : Player → Nat) (button : Player) (seed : Nat) :
    GoodCards (startHand stacks button seed).allCards := by
  have deck : GoodCards (shuffle seed fullDeck) :=
    GoodCards.of_perm ⟨fullDeck_nodup, fun _ h => h⟩ (shuffle_fair seed)
  exact (deck.of_perm (dealHand_cards stacks button seed)).of_sublist (passTurn_cards _ _)

/-- Every hand the engine can reach has good cards. -/
theorem reachable_good (h : Hand) (hr : h.Reachable) : GoodCards h.allCards := by
  induction hr with
  | deal stacks button seed => exact startHand_good stacks button seed
  | move a _ hs ih => exact ih.of_sublist (step_cards _ _ a hs)

/-- The hand of every game the engine can reach is a hand the engine can reach. -/
theorem Game.Reachable.hand {g : Game} (hg : g.Reachable) : g.hand.Reachable := by
  induction hg with
  | start seed => exact .deal (fun _ => startingStack) 0 (handSeed seed 1)
  | act a _ hs ih => exact .move a ih (act_hand hs)
  | nextHand _ hs _ => rw [(nextHand_hand hs).2]; exact .deal _ _ _

/-- In every game the engine can reach, the cards on the table (both players' hidden cards
and the shared cards) are all different, and all come from the 52-card deck. -/
theorem no_card_dealt_twice (g : Game) (hg : g.Reachable) :
    g.hand.dealtCards.Nodup ∧ ∀ c ∈ g.hand.dealtCards, c ∈ fullDeck := by
  have good := reachable_good _ hg.hand
  exact (good.of_sublist (List.sublist_append_left _ _))

/-! ## Checks

The conditions of the main theorem can hold: a new game, and the game after a real move,
are reachable, and their dealt cards are all different. -/

/-- A new game satisfies the condition, so the theorem applies to it. -/
example : (newGame 7).hand.dealtCards.Nodup := (no_card_dealt_twice _ (.start 7)).1

-- After a real move, the dealt cards are still all different (checked by running it).
#guard match (newGame 7).act .call with
  | .ok g => decide g.hand.dealtCards.Nodup && g.hand.dealtCards.length == 4
  | .error _ => false

/-! The theorems reject bad outcomes. -/

/-- A table with the ace of hearts twice fails the "all different" test. -/
example : ¬ ([card 14 .hearts, card 2 .clubs, card 14 .hearts] : List Card).Nodup := by decide

/-- A 52-card deck with the ace of hearts twice (and the two of clubs missing) is not fair. -/
example : ¬ FairDeck (card 14 .hearts :: fullDeck.drop 1) := by
  intro h
  have : (card 14 .hearts :: fullDeck.drop 1).Nodup := h.nodup_iff.2 fullDeck_nodup
  revert this
  decide

#print axioms shuffle_same_cards
#print axioms shuffle_fair
#print axioms no_card_dealt_twice
