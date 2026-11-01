import Engine.Proofs.EquitySpec

/-!
# T6 `enumeration_exact`: the exact counts look at every outcome exactly once

On the river the bot counts every hand the opponent could hold. On the turn it counts every
(river card, opponent hand) pair. These theorems say the lists it counts over are right:

- every entry is an outcome that can really happen (no card is used twice, and no card the
  bot can see is given to the opponent or dealt on the river);
- every outcome that can happen is in the list exactly once (a hand is two cards in either
  order, so `[a, b]` and `[b, a]` are the same hand and only one of them is listed);
- so there are 990 entries on the river and 45,540 on the turn;
- and the counts are just "how many of those outcomes the bot wins, ties and loses", using
  the spec's `showdown`.

The definitions these theorems use are in `Engine/Proofs/EquitySpec.lean`.
-/

/-! ## Helper lemmas -/

/-- Every card is in the new deck. -/
theorem mem_fullDeck (c : Card) : c ∈ fullDeck := by
  obtain ⟨r, s⟩ := c
  cases s <;> revert r <;> decide

theorem fullDeck_nodup : fullDeck.Nodup := by decide

theorem mem_unseenCards {hole board : List Card} {c : Card} :
    c ∈ unseenCards hole board ↔ c ∉ hole ++ board := by
  simp [unseenCards, mem_fullDeck]

theorem unseenCards_nodup (hole board : List Card) : (unseenCards hole board).Nodup :=
  fullDeck_nodup.sublist List.filter_sublist

theorem length_unseenCards {hole board : List Card} (h : (hole ++ board).Nodup) :
    (unseenCards hole board).length = 52 - (hole ++ board).length := by
  have split := (List.filter_append_perm (fun c => !(hole ++ board).contains c) fullDeck).length_eq
  -- The cards left out of `unseenCards` are exactly the seen ones.
  have seen : (fullDeck.filter fun c => !!(hole ++ board).contains c).Perm (hole ++ board) := by
    rw [List.perm_ext_iff_of_nodup (fullDeck_nodup.sublist List.filter_sublist) h]
    intro c; simp [mem_fullDeck]
  rw [List.length_append, seen.length_eq] at split
  have : fullDeck.length = 52 := by decide
  unfold unseenCards; omega

/-- A pair `(a, b)` is in `pairs l` exactly when `a` comes before `b` in `l`. -/
theorem mem_pairs {α : Type} {l : List α} {a b : α} : (a, b) ∈ pairs l ↔ [a, b].Sublist l := by
  induction l with
  | nil => simp [pairs]
  | cons x xs ih =>
    simp only [pairs, List.mem_append, List.mem_map, Prod.mk.injEq, ih, List.sublist_cons_iff]
    constructor
    · rintro (⟨y, hy, rfl, rfl⟩ | h)
      · exact .inr ⟨[y], rfl, List.singleton_sublist.mpr hy⟩
      · exact .inl h
    · rintro (h | ⟨r, hr, hs⟩)
      · exact .inr h
      · simp only [List.cons.injEq] at hr
        obtain ⟨rfl, rfl⟩ := hr
        exact .inl ⟨b, List.singleton_sublist.mp hs, rfl, rfl⟩

theorem pairs_nodup {α : Type} {l : List α} (h : l.Nodup) : (pairs l).Nodup := by
  induction l with
  | nil => simp [pairs]
  | cons x xs ih =>
    rw [List.nodup_cons] at h
    simp only [pairs, List.Nodup, List.pairwise_append, List.pairwise_map]
    refine ⟨h.2.imp (fun hne heq => hne (Prod.mk.inj heq).2), ih h.2, ?_⟩
    intro p hp q hq heq
    obtain ⟨y, _, rfl⟩ := List.mem_map.mp hp
    obtain ⟨a, b⟩ := q
    have : x ∈ xs := (mem_pairs.mp hq).subset (by simp [(Prod.mk.inj heq).1])
    exact h.1 this

/-- In a list with no repeats, two entries cannot come in both orders. -/
theorem not_both_orders {α : Type} {l : List α} {a b : α} (h : l.Nodup)
    (hab : [a, b].Sublist l) : ¬ [b, a].Sublist l := by
  induction l with
  | nil => simp at hab
  | cons x xs ih =>
    rw [List.nodup_cons] at h
    intro hba
    rw [List.sublist_cons_iff] at hab hba
    rcases hab with hab | ⟨r, hr, hrs⟩ <;> rcases hba with hba | ⟨r', hr', hrs'⟩
    · exact ih h.2 hab hba
    · simp only [List.cons.injEq] at hr'
      obtain ⟨rfl, rfl⟩ := hr'
      exact h.1 (hab.subset (by simp))
    · simp only [List.cons.injEq] at hr
      obtain ⟨rfl, rfl⟩ := hr
      exact h.1 (hba.subset (by simp))
    · simp only [List.cons.injEq] at hr hr'
      obtain ⟨rfl, rfl⟩ := hr
      obtain ⟨rfl, -⟩ := hr'
      exact h.1 (hrs.subset (by simp))

/-- Two different entries of a list come in one order or the other. -/
theorem one_order {α : Type} {l : List α} {a b : α} (ha : a ∈ l) (hb : b ∈ l) (hne : a ≠ b) :
    [a, b].Sublist l ∨ [b, a].Sublist l := by
  induction l with
  | nil => simp at ha
  | cons x xs ih =>
    rcases List.mem_cons.mp ha with rfl | ha' <;> rcases List.mem_cons.mp hb with rfl | hb'
    · exact absurd rfl hne
    · exact .inl ((List.singleton_sublist.mpr hb').cons_cons _)
    · exact .inr ((List.singleton_sublist.mpr ha').cons_cons _)
    · rcases ih ha' hb' with h | h
      · exact .inl (h.cons _)
      · exact .inr (h.cons _)

theorem length_pairs {α : Type} (l : List α) :
    2 * (pairs l).length = l.length * (l.length - 1) := by
  induction l with
  | nil => simp [pairs]
  | cons x xs ih =>
    simp only [pairs, List.length_append, List.length_map, List.length_cons, Nat.add_sub_cancel]
    rw [Nat.mul_add, ih]
    cases xs.length with
    | zero => rfl
    | succ n =>
      simp only [Nat.add_sub_cancel, Nat.add_mul, Nat.mul_add, Nat.one_mul, Nat.mul_one]
      omega

/-- In a list with no repeats, two values of which exactly one is in the list appear once
in total. -/
theorem count_add_count_eq_one {α : Type} [BEq α] [LawfulBEq α] {l : List α} {x y : α}
    (h : l.Nodup) (hx : x ∈ l ∨ y ∈ l) (hxy : ¬ (x ∈ l ∧ y ∈ l)) :
    l.count x + l.count y = 1 := by
  rw [h.count, h.count]
  by_cases hxl : x ∈ l <;> by_cases hyl : y ∈ l <;> simp_all

/-! ## Counting results -/

/-- Adding up results one at a time gives `countResults`. -/
theorem foldl_add {β : Type} (f : β → Outcome) (l : List β) (c : Counts) :
    l.foldl (fun c x => c.add (f x)) c = c.plus (countResults (l.map f)) := by
  induction l generalizing c with
  | nil => simp [countResults, Counts.plus]
  | cons x xs ih =>
    rw [List.foldl_cons, ih]
    cases h : f x <;>
      simp [Counts.add, Counts.plus, countResults, h] <;> omega

/-- `foldl_add` for a step function that is `c.add (f x)` but written another way. -/
theorem foldl_add' {β : Type} (g : Counts → β → Counts) (f : β → Outcome)
    (hg : ∀ c x, g c x = c.add (f x)) (l : List β) (c : Counts) :
    l.foldl g c = c.plus (countResults (l.map f)) := by
  have : g = fun c x => c.add (f x) := funext fun c => funext fun x => hg c x
  subst this
  exact foldl_add f l c

theorem countResults_append (a b : List Outcome) :
    countResults (a ++ b) = (countResults a).plus (countResults b) := by
  simp [countResults, Counts.plus]

theorem Counts.zero_plus (c : Counts) : Counts.zero.plus c = c := by
  simp [Counts.zero, Counts.plus]

/-- Adding up the counts of several lists gives the counts of all of them together. -/
theorem foldl_plus {β : Type} (F : β → List Outcome) (l : List β) (c : Counts) :
    l.foldl (fun c x => c.plus (countResults (F x))) c = c.plus (countResults (l.flatMap F)) := by
  induction l generalizing c with
  | nil => simp [countResults, Counts.plus]
  | cons x xs ih =>
    rw [List.foldl_cons, ih, List.flatMap_cons, countResults_append]
    simp [Counts.plus, Nat.add_assoc]

/-! ## River -/

theorem mem_riverOpponentHands {hole board : List Card} {a b : Card} :
    [a, b] ∈ riverOpponentHands hole board ↔ [a, b].Sublist (unseenCards hole board) := by
  simp only [riverOpponentHands, List.mem_map, Prod.exists]
  constructor
  · rintro ⟨x, y, hxy, heq⟩
    simp only [List.cons.injEq, and_true] at heq
    obtain ⟨rfl, rfl⟩ := heq
    exact mem_pairs.mp hxy
  · intro h
    exact ⟨a, b, mem_pairs.mpr h, rfl⟩

theorem riverOpponentHands_nodup (hole board : List Card) :
    (riverOpponentHands hole board).Nodup := by
  unfold riverOpponentHands
  simp only [List.Nodup, List.pairwise_map]
  refine (pairs_nodup (unseenCards_nodup hole board)).imp ?_
  rintro ⟨a, b⟩ ⟨c, d⟩ hne heq
  simp only [List.cons.injEq, and_true] at heq
  obtain ⟨rfl, rfl⟩ := heq
  exact hne rfl

/-- **River, T6.** Every hand in the river list is one the opponent can hold, and every hand
the opponent can hold is in the list exactly once. -/
theorem river_enumeration_exact (hole board : List Card) :
    (∀ h ∈ riverOpponentHands hole board, ∃ a b, h = [a, b] ∧ OpponentCanHold hole board a b) ∧
    (∀ a b, OpponentCanHold hole board a b →
      timesListed (riverOpponentHands hole board) a b = 1) := by
  constructor
  · intro h hh
    obtain ⟨⟨a, b⟩, hab, rfl⟩ := List.mem_map.mp hh
    have sub := mem_pairs.mp hab
    have hne : a ≠ b := by
      have := (unseenCards_nodup hole board).sublist sub
      simpa using this
    exact ⟨a, b, rfl, hne, mem_unseenCards.mp (sub.subset (by simp)),
      mem_unseenCards.mp (sub.subset (by simp))⟩
  · rintro a b ⟨hne, ha, hb⟩
    apply count_add_count_eq_one (riverOpponentHands_nodup hole board)
    · rw [mem_riverOpponentHands, mem_riverOpponentHands]
      exact one_order (mem_unseenCards.mpr ha) (mem_unseenCards.mpr hb) hne
    · rw [mem_riverOpponentHands, mem_riverOpponentHands]
      exact fun ⟨h1, h2⟩ => not_both_orders (unseenCards_nodup hole board) h1 h2

/-- With two hole cards and five board cards, all different, the opponent can hold 990 hands. -/
theorem riverOpponentHands_length {hole board : List Card} (h2 : hole.length = 2)
    (h5 : board.length = 5) (hd : (hole ++ board).Nodup) :
    (riverOpponentHands hole board).length = 990 := by
  have hu := length_unseenCards hd
  rw [List.length_append, h2, h5] at hu
  have hp := length_pairs (unseenCards hole board)
  rw [hu] at hp
  simp only [riverOpponentHands, List.length_map]
  omega

/-- The river counts are: how many of the opponent's hands the bot beats at showdown, ties
with, and loses to, using the spec's `showdown`. -/
theorem riverCounts_spec (hole board : List Card) :
    riverCounts hole board =
      countResults ((riverOpponentHands hole board).map fun opp => showdown hole opp board) := by
  simp only [riverCounts, Counts.add_showdown]
  rw [foldl_add, Counts.zero_plus]

/-- On the river, `countsFor` (what the bot uses) is `riverCounts`. -/
theorem countsFor_river {seed : Nat} {hole board : List Card} (h : board.length = 5) :
    countsFor seed hole board = riverCounts hole board := by
  simp [countsFor, h]

/-! ## Turn -/

theorem mem_turnOutcomes {hole board : List Card} {r a b : Card} :
    (r, [a, b]) ∈ turnOutcomes hole board ↔
      r ∈ unseenCards hole board ∧ [a, b].Sublist ((unseenCards hole board).erase r) := by
  simp only [turnOutcomes, List.mem_flatMap, List.mem_map, Prod.exists, Prod.mk.injEq]
  constructor
  · rintro ⟨r', hr', x, y, hxy, rfl, heq⟩
    simp only [List.cons.injEq, and_true] at heq
    obtain ⟨rfl, rfl⟩ := heq
    exact ⟨hr', mem_pairs.mp hxy⟩
  · rintro ⟨hr, h⟩
    exact ⟨r, hr, a, b, mem_pairs.mpr h, rfl, rfl⟩

theorem turnOutcomes_nodup (hole board : List Card) : (turnOutcomes hole board).Nodup := by
  have hu := unseenCards_nodup hole board
  unfold turnOutcomes
  simp only [List.Nodup, List.pairwise_flatMap, List.pairwise_map]
  constructor
  · intro r _
    refine (pairs_nodup (hu.erase r)).imp ?_
    rintro ⟨a, b⟩ ⟨c, d⟩ hne heq
    simp only [Prod.mk.injEq, List.cons.injEq, and_true, true_and] at heq
    obtain ⟨rfl, rfl⟩ := heq
    exact hne rfl
  · refine hu.imp ?_
    intro r₁ r₂ hne x hx y hy heq
    obtain ⟨_, _, rfl⟩ := List.mem_map.mp hx
    obtain ⟨_, _, rfl⟩ := List.mem_map.mp hy
    exact hne (Prod.mk.inj heq).1

/-- **Turn, T6.** Every entry of the turn list is an outcome that can happen, and every
outcome that can happen is in the list exactly once. -/
theorem turn_enumeration_exact (hole board : List Card) :
    (∀ o ∈ turnOutcomes hole board,
      ∃ r a b, o = (r, [a, b]) ∧ TurnOutcomePossible hole board r a b) ∧
    (∀ r a b, TurnOutcomePossible hole board r a b →
      timesListedTurn (turnOutcomes hole board) r a b = 1) := by
  have hu := unseenCards_nodup hole board
  constructor
  · intro o ho
    obtain ⟨r, hr, ho⟩ := List.mem_flatMap.mp ho
    obtain ⟨⟨a, b⟩, hab, rfl⟩ := List.mem_map.mp ho
    have sub := mem_pairs.mp hab
    have hne : a ≠ b := by
      have := (hu.erase r).sublist sub
      simpa using this
    have ha := hu.mem_erase_iff.mp (sub.subset (by simp : a ∈ [a, b]))
    have hb := hu.mem_erase_iff.mp (sub.subset (by simp : b ∈ [a, b]))
    exact ⟨r, a, b, rfl, ⟨hne, mem_unseenCards.mp ha.2, mem_unseenCards.mp hb.2⟩,
      fun h => ha.1 h.symm, fun h => hb.1 h.symm, mem_unseenCards.mp hr⟩
  · rintro r a b ⟨⟨hne, ha, hb⟩, hra, hrb, hr⟩
    have ha' : a ∈ (unseenCards hole board).erase r :=
      hu.mem_erase_iff.mpr ⟨fun h => hra h.symm, mem_unseenCards.mpr ha⟩
    have hb' : b ∈ (unseenCards hole board).erase r :=
      hu.mem_erase_iff.mpr ⟨fun h => hrb h.symm, mem_unseenCards.mpr hb⟩
    apply count_add_count_eq_one (turnOutcomes_nodup hole board)
    · rw [mem_turnOutcomes, mem_turnOutcomes]
      rcases one_order ha' hb' hne with h | h
      · exact .inl ⟨mem_unseenCards.mpr hr, h⟩
      · exact .inr ⟨mem_unseenCards.mpr hr, h⟩
    · rw [mem_turnOutcomes, mem_turnOutcomes]
      exact fun ⟨⟨_, h1⟩, ⟨_, h2⟩⟩ => not_both_orders (hu.erase r) h1 h2

/-- A sum of `k` over a list is the length of the list times `k`. -/
theorem sum_map_eq_mul {β : Type} (f : β → Nat) (k : Nat) :
    ∀ l : List β, (∀ x ∈ l, f x = k) → (l.map f).sum = l.length * k
  | [], _ => by simp
  | x :: xs, h => by
    simp only [List.map_cons, List.sum_cons, List.length_cons, Nat.add_mul, Nat.one_mul]
    rw [h x (by simp), sum_map_eq_mul f k xs (fun y hy => h y (by simp [hy]))]
    omega

/-- With two hole cards and four board cards, all different, there are 45,540 turn outcomes:
46 river cards, each with 990 opponent hands. -/
theorem turnOutcomes_length {hole board : List Card} (h2 : hole.length = 2)
    (h4 : board.length = 4) (hd : (hole ++ board).Nodup) :
    (turnOutcomes hole board).length = 45540 := by
  have hu := length_unseenCards hd
  rw [List.length_append, h2, h4] at hu
  unfold turnOutcomes
  rw [List.length_flatMap, sum_map_eq_mul _ 990, hu]
  intro r hr
  have he := List.length_erase_of_mem hr
  rw [hu] at he
  have hp := length_pairs ((unseenCards hole board).erase r)
  rw [he] at hp
  simp only [List.length_map]
  omega

/-- The turn counts are: over every (river card, opponent hand) outcome, how many the bot
wins, ties and loses at showdown with that river card on the board. -/
theorem turnCounts_spec (hole board : List Card) :
    turnCounts hole board =
      countResults ((turnOutcomes hole board).map fun (r, opp) => showdown hole opp (board ++ [r])) := by
  have card (r : Card) : riverCardCounts hole board (unseenCards hole board) r =
      countResults ((pairs ((unseenCards hole board).erase r)).map
        fun (a, b) => showdown hole [a, b] (board ++ [r])) := by
    simp only [riverCardCounts]
    rw [foldl_add' _ (fun x => showdown hole [x.1, x.2] (board ++ [r]))
      (by rintro c ⟨a, b⟩; exact Counts.add_showdown c hole [a, b] (board ++ [r])),
      Counts.zero_plus]
  unfold turnCounts
  rw [List.foldl_map]
  simp only [Task.spawn, card]
  rw [foldl_plus, Counts.zero_plus, turnOutcomes, List.map_flatMap]
  simp only [List.map_map]
  rfl

/-- On the turn, `countsFor` (what the bot uses) is `turnCounts`. -/
theorem countsFor_turn {seed : Nat} {hole board : List Card} (h : board.length = 4) :
    countsFor seed hole board = turnCounts hole board := by
  simp [countsFor, h]

/-! ## T6 -/

/-- **T6 `enumeration_exact`.** The exact counts on the river and the turn each look at every
possible outcome exactly once, and count it by the spec's `showdown`. -/
theorem enumeration_exact (hole board : List Card) :
    -- river: the list is right, and the counts count it
    ((∀ h ∈ riverOpponentHands hole board, ∃ a b, h = [a, b] ∧ OpponentCanHold hole board a b) ∧
     (∀ a b, OpponentCanHold hole board a b → timesListed (riverOpponentHands hole board) a b = 1) ∧
     riverCounts hole board =
      countResults ((riverOpponentHands hole board).map fun opp => showdown hole opp board)) ∧
    -- turn: the list is right, and the counts count it
    ((∀ o ∈ turnOutcomes hole board,
       ∃ r a b, o = (r, [a, b]) ∧ TurnOutcomePossible hole board r a b) ∧
     (∀ r a b, TurnOutcomePossible hole board r a b →
       timesListedTurn (turnOutcomes hole board) r a b = 1) ∧
     turnCounts hole board =
      countResults ((turnOutcomes hole board).map fun (r, opp) => showdown hole opp (board ++ [r]))) :=
  ⟨⟨(river_enumeration_exact hole board).1, (river_enumeration_exact hole board).2,
     riverCounts_spec hole board⟩,
   ⟨(turn_enumeration_exact hole board).1, (turn_enumeration_exact hole board).2,
     turnCounts_spec hole board⟩⟩

/-! ## Checks

The theorems' conditions can hold on a real deal, the "exactly once" rule rejects lists that
miss a hand or list one twice, and the axioms are only Lean's standard ones. -/

/-- A real river spot: ace-king on Q J T 5 2. -/
def exHole : List Card := [card 14 .spades, card 13 .diamonds]
def exRiver : List Card := [card 12 .hearts, card 11 .clubs, card 10 .clubs, card 5 .spades, card 2 .diamonds]
def exTurn : List Card := [card 12 .hearts, card 11 .clubs, card 10 .clubs, card 5 .spades]

-- Every condition holds on this deal: 990 hands on the river, 45,540 outcomes on the turn.
example : (riverOpponentHands exHole exRiver).length = 990 :=
  riverOpponentHands_length rfl rfl (by decide)
example : (turnOutcomes exHole exTurn).length = 45540 :=
  turnOutcomes_length rfl rfl (by decide)

-- The opponent can hold 3c 4c here, and it is listed exactly once.
example : OpponentCanHold exHole exRiver (card 3 .clubs) (card 4 .clubs) := by decide
example : timesListed (riverOpponentHands exHole exRiver) (card 3 .clubs) (card 4 .clubs) = 1 :=
  (river_enumeration_exact exHole exRiver).2 _ _ (by decide)

-- On the turn, river 2d with the opponent holding 3c 4c can happen, and is listed exactly once.
example : TurnOutcomePossible exHole exTurn (card 2 .diamonds) (card 3 .clubs) (card 4 .clubs) := by
  decide
example : timesListedTurn (turnOutcomes exHole exTurn) (card 2 .diamonds) (card 3 .clubs)
    (card 4 .clubs) = 1 :=
  (turn_enumeration_exact exHole exTurn).2 _ _ _ (by decide)

-- The bot's own hand is not a hand the opponent can hold.
example : ¬ OpponentCanHold exHole exRiver (card 14 .spades) (card 3 .clubs) := by decide

/-- A list that has 3c 4c in both orders counts that hand twice, so "exactly once" rejects it. -/
example : ¬ ∀ a b, OpponentCanHold exHole exRiver a b →
    timesListed [[card 3 .clubs, card 4 .clubs], [card 4 .clubs, card 3 .clubs]] a b = 1 := by
  intro h
  have := h (card 3 .clubs) (card 4 .clubs) (by decide)
  revert this; decide

/-- A list that leaves 3c 4c out counts it zero times, so "exactly once" rejects it too. -/
example : ¬ ∀ a b, OpponentCanHold exHole exRiver a b →
    timesListed [[card 3 .clubs, card 5 .clubs]] a b = 1 := by
  intro h
  have := h (card 3 .clubs) (card 4 .clubs) (by decide)
  revert this; decide

/-- A list with a hand the opponent cannot hold (it uses the bot's ace of spades) fails the
first part. -/
example : ¬ ∀ h ∈ [[card 14 .spades, card 3 .clubs]],
    ∃ a b, h = [a, b] ∧ OpponentCanHold exHole exRiver a b := by
  intro h
  obtain ⟨a, b, hab, hcan⟩ := h _ (List.mem_singleton_self _)
  simp only [List.cons.injEq, and_true] at hab
  obtain ⟨rfl, rfl⟩ := hab
  exact absurd hcan (by decide)

#print axioms enumeration_exact
#print axioms riverOpponentHands_length
#print axioms turnOutcomes_length
#print axioms countsFor_river
#print axioms countsFor_turn
