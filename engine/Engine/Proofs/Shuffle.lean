import Engine.Proofs.ShuffleSpec
import Engine.Proofs.Deck

/-!
# How fair the shuffle is (T2, randomness)

The spec, in plain words, is in `Engine/Proofs/ShuffleSpec.lean`. These theorems say:

1. `shuffle_eq_pickWith`: the real shuffle is `pickWith`, fed by the generator's numbers.
2. `allValidPicks_length`, `mem_allValidPicks`: `n` cards have exactly `n!` valid pick lists,
   and `allValidPicks` lists each of them once (`allValidPicks_nodup`).
3. `every_order_possible`, `picks_one_to_one`: every order comes from a valid pick list, and for
   cards that are all different, different pick lists give different orders.
4. `each_order_once`: so among the `n!` valid pick lists, each order of the deck is made by
   exactly one. If the picks are fair, every order has the same chance: 1 in `n!`.
5. `shuffle_uses_64_bits`, `fewer_seeds_than_orders`: the shuffle only reads its seed modulo
   2^64, and 2^64 is less than 52!. So most orders of a 52-card deck never come out.
-/

/-! ## The real shuffle is the picking method -/

/-- The shuffle's picking loop is `pickWith` with the generator's numbers, for any fuel. -/
theorem shuffleAux_eq_pickWith {α : Type} :
    ∀ (fuel s : Nat) (l : List α), shuffleAux fuel s l = pickWith (seedPicks fuel s) l
  | 0, _, l => by simp [shuffleAux, seedPicks, pickWith]
  | _ + 1, _, [] => by simp [shuffleAux, seedPicks, pickWith]
  | fuel + 1, s, x :: xs => by
    simp only [shuffleAux, seedPicks, pickWith]
    rw [shuffleAux_eq_pickWith fuel]

/-- **The real shuffle is `pickWith`, fed by the generator.** Shuffling `l` from `seed` is
picking with the generator's numbers from `seed`, one per card. -/
theorem shuffle_eq_pickWith {α : Type} (seed : Nat) (l : List α) :
    shuffle seed l = pickWith (seedPicks l.length seed) l :=
  shuffleAux_eq_pickWith _ _ _

/-- **Only orders of the cards come out.** A pick list that makes `l'` from `l` makes an
order of the same cards. -/
theorem pickWith_perm {α : Type} : ∀ (picks : List Nat) (l : List α), (pickWith picks l).Perm l
  | [], l => by cases l <;> simp [pickWith]
  | _ :: _, [] => by simp [pickWith]
  | i :: is, x :: xs => by
    simp only [pickWith]
    exact (List.Perm.cons _ (pickWith_perm is _)).trans (pick_same_cards _ _ _)


/-! ## Counting the pick lists -/

/-- Adding up `k` once for each of `n` places gives `n * k`. -/
theorem sum_range_const (n k : Nat) : ((List.range n).map fun _ => k).sum = n * k := by
  induction n with
  | zero => simp
  | succ n ih => simp [List.range_succ, ih, Nat.succ_mul]

/-- **`n` cards have `n!` valid pick lists.** -/
theorem allValidPicks_length (n : Nat) : (allValidPicks n).length = factorial n := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [allValidPicks, List.length_flatMap, List.length_map, ih, factorial]
    exact sum_range_const _ _

/-- `allValidPicks n` holds exactly the valid pick lists for `n` cards. -/
theorem mem_allValidPicks (n : Nat) (picks : List Nat) :
    picks ∈ allValidPicks n ↔ ValidPicks n picks := by
  induction n generalizing picks with
  | zero => cases picks <;> simp [allValidPicks, ValidPicks]
  | succ n ih =>
    cases picks with
    | nil => simp [allValidPicks, ValidPicks]
    | cons i is => simp [allValidPicks, ValidPicks, ih]

/-- `allValidPicks n` lists no pick list twice. -/
theorem allValidPicks_nodup (n : Nat) : (allValidPicks n).Nodup := by
  induction n with
  | zero => simp [allValidPicks]
  | succ n ih =>
    simp only [allValidPicks]
    unfold List.Nodup
    rw [List.pairwise_flatMap]
    refine ⟨fun i _ => List.Pairwise.map _ (fun a b h e => h (by simpa using e)) ih, ?_⟩
    apply List.Pairwise.imp _ (List.nodup_range)
    intro a b hab x hx y hy hxy
    simp only [List.mem_map] at hx hy
    obtain ⟨_, _, rfl⟩ := hx
    obtain ⟨_, _, rfl⟩ := hy
    simp at hxy
    exact hab hxy.1


/-! ## Each order comes from exactly one pick list -/

/-- Taking a card out of `x :: xs` leaves `xs.length` cards. -/
theorem length_eraseIdx_cons {α : Type} (x : α) (xs : List α) (i : Nat) (hi : i < xs.length + 1) :
    ((x :: xs).eraseIdx i).length = xs.length := by
  rw [List.length_eraseIdx_of_lt (by simpa using hi)]
  simp

/-- `every_order_possible`, by induction on the number of cards. -/
theorem every_order_possible_aux {α : Type} (n : Nat) : ∀ (l l' : List α), l.length = n →
    l'.Perm l → ∃ picks, ValidPicks l.length picks ∧ pickWith picks l = l' := by
  induction n with
  | zero =>
    intro l l' hn hp
    have hl : l = [] := List.eq_nil_of_length_eq_zero hn
    subst hl
    have hl' : l' = [] := List.perm_nil.mp hp
    subst hl'
    exact ⟨[], trivial, rfl⟩
  | succ n ih =>
    intro l l' hn hp
    match l, l', hn, hp with
    | x :: xs, [], _, hp => exact absurd hp.length_eq (by simp)
    | x :: xs, y :: ys, hn, hp =>
      have hmem : y ∈ x :: xs := hp.subset (List.mem_cons_self ..)
      obtain ⟨i, hi, hyi⟩ := List.mem_iff_getElem.mp hmem
      have hi' : i < xs.length + 1 := by simpa using hi
      have hpick := pick_same_cards (x :: xs) i hi
      rw [hyi] at hpick
      have hperm : ys.Perm ((x :: xs).eraseIdx i) := List.Perm.cons_inv (hp.trans hpick.symm)
      have hlen := length_eraseIdx_cons x xs i hi'
      obtain ⟨ps, hv, hpw⟩ := ih _ ys (by simp at hn; omega) hperm
      rw [hlen] at hv
      refine ⟨i :: ps, ⟨hi', hv⟩, ?_⟩
      simp only [pickWith, Nat.mod_eq_of_lt hi', hpw]
      rw [← hyi]

/-- **Every order can come out.** Every order of the cards in `l` (every list `l'` with the
same cards) is what `pickWith` makes from some valid pick list. -/
theorem every_order_possible {α : Type} (l l' : List α) (hp : l'.Perm l) :
    ∃ picks, ValidPicks l.length picks ∧ pickWith picks l = l' :=
  every_order_possible_aux l.length l l' rfl hp

/-- `picks_one_to_one`, by induction on the number of cards. -/
theorem picks_one_to_one_aux {α : Type} (n : Nat) : ∀ (l : List α), l.length = n → l.Nodup →
    ∀ p q : List Nat, ValidPicks l.length p → ValidPicks l.length q →
      pickWith p l = pickWith q l → p = q := by
  induction n with
  | zero =>
    intro l hn _ p q hp hq _
    have hl : l = [] := List.eq_nil_of_length_eq_zero hn
    subst hl
    cases p <;> cases q <;> simp_all [ValidPicks]
  | succ n ih =>
    intro l hn hl p q hp hq h
    match l, p, q, hn, hl, hp, hq, h with
    | x :: xs, i :: is, j :: js, hn, hl, hp, hq, h =>
      obtain ⟨hi, his⟩ := hp
      obtain ⟨hj, hjs⟩ := hq
      simp only [pickWith, Nat.mod_eq_of_lt hi, Nat.mod_eq_of_lt hj, List.cons.injEq] at h
      obtain ⟨hhead, htail⟩ := h
      have hij : i = j := (List.Nodup.getElem_inj hl).mp hhead
      subst hij
      have hlen := length_eraseIdx_cons x xs i hi
      have := ih ((x :: xs).eraseIdx i) (by simp at hn; omega)
        (hl.sublist (List.eraseIdx_sublist _ _)) is js (by rw [hlen]; exact his)
        (by rw [hlen]; exact hjs) htail
      rw [this]
    | x :: xs, [], _, _, _, hp, _, _ => exact absurd hp id
    | x :: xs, _ :: _, [], _, _, _, hq, _ => exact absurd hq id

/-- **Different picks give different orders.** If the cards in `l` are all different, two
valid pick lists that make the same order are the same pick list. -/
theorem picks_one_to_one {α : Type} (l : List α) (hl : l.Nodup) (p q : List Nat)
    (hp : ValidPicks l.length p) (hq : ValidPicks l.length q)
    (h : pickWith p l = pickWith q l) : p = q :=
  picks_one_to_one_aux l.length l rfl hl p q hp hq h

/-- In a list with no repeats, if `a` is the only entry that passes a test, the entries that
pass are exactly one. -/
theorem filter_length_one {β : Type} (L : List β) (P : β → Bool) (hL : L.Nodup) (a : β)
    (ha : a ∈ L) (hPa : P a = true) (honly : ∀ b ∈ L, P b = true → b = a) :
    (L.filter P).length = 1 := by
  have hF : (L.filter P).Nodup := hL.filter P
  have haF : a ∈ L.filter P := List.mem_filter.mpr ⟨ha, hPa⟩
  have hall : ∀ b ∈ L.filter P, b = a := fun b hb =>
    honly b (List.mem_filter.mp hb).1 (List.mem_filter.mp hb).2
  generalize L.filter P = F at hF haF hall
  match F, hF with
  | [], _ => simp at haF
  | b :: rest, hF =>
    have hb := hall b (List.mem_cons_self ..)
    subst hb
    have hrest : rest = [] := List.eq_nil_iff_forall_not_mem.mpr fun c hc =>
      (List.nodup_cons.mp hF).1 (by rw [← hall c (List.mem_cons_of_mem _ hc)]; exact hc)
    simp [hrest]

/-- **Fair picks give a fair deck.** If the cards in `l` are all different, then for every
order `l'` of them, exactly one of the `n!` valid pick lists makes `l'`. So if every valid
pick list is equally likely, every order of the cards has the same chance, 1 in `n!`. -/
theorem each_order_once {α : Type} [DecidableEq α] (l l' : List α) (hl : l.Nodup)
    (hp : l'.Perm l) :
    ((allValidPicks l.length).filter fun picks => pickWith picks l == l').length = 1 := by
  obtain ⟨picks, hv, hpw⟩ := every_order_possible l l' hp
  apply filter_length_one _ _ (allValidPicks_nodup _) picks
    ((mem_allValidPicks _ _).mpr hv) (by simp [hpw])
  intro b hb hpb
  simp only [beq_iff_eq] at hpb
  exact picks_one_to_one l hl b picks ((mem_allValidPicks _ _).mp hb) hv (hpb.trans hpw.symm)


/-! ## What the generator limits -/

/-- **The shuffle reads its seed only modulo 2^64.** Two seeds that differ by a multiple of
2^64 give the same deck. -/
theorem shuffle_uses_64_bits {α : Type} (seed : Nat) (l : List α) :
    shuffle seed l = shuffle (seed % 2 ^ 64) l := by
  have h : nextSeed (seed % 2 ^ 64) = nextSeed seed := by
    simp only [nextSeed, Nat.mod_add_mod]
  cases l with
  | nil => simp [shuffle, shuffleAux]
  | cons x xs => simp only [shuffle, List.length_cons, shuffleAux, h]

/-- **There are far fewer seeds than deck orders.** 2^64 is less than 52!. With
`shuffle_uses_64_bits`, at most 2^64 of the 52! orders of a deck can ever come out of the
shuffle, so most orders never do. -/
theorem fewer_seeds_than_orders : 2 ^ 64 < factorial 52 := by
  decide

/-! ## Examples: every hypothesis met, and wrong answers rejected -/

-- Three different cards: the order c, a, b is made by exactly one of the 6 valid pick lists.
example : ((allValidPicks 3).filter fun picks => pickWith picks ['a', 'b', 'c'] == ['c', 'a', 'b']).length = 1 :=
  each_order_once ['a', 'b', 'c'] ['c', 'a', 'b'] (by decide) (by decide)
-- The same holds for every one of the 6 orders (checked one by one).
example : [['a', 'b', 'c'], ['a', 'c', 'b'], ['b', 'a', 'c'], ['b', 'c', 'a'], ['c', 'a', 'b'],
    ['c', 'b', 'a']].all (fun o =>
      ((allValidPicks 3).filter fun picks => pickWith picks ['a', 'b', 'c'] == o).length == 1) := by
  decide
-- A list that is not an order of the cards (a twice, c missing) is made by no pick list.
example : ((allValidPicks 3).filter fun picks => pickWith picks ['a', 'b', 'c'] == ['a', 'a', 'b']).length = 0 := by
  decide
example (picks : List Nat) : pickWith picks ['a', 'b', 'c'] ≠ ['a', 'a', 'b'] := fun h => by
  have := pickWith_perm picks ['a', 'b', 'c']
  rw [h] at this
  exact absurd this (by decide)
-- Why "all different" is needed: with a repeated card, two pick lists make the same order.
example : pickWith [0, 0] ['a', 'a'] = pickWith [1, 0] ['a', 'a'] := by decide

-- The real deck has no card twice, so the theorems apply to it: 52! pick lists, and each of
-- the 52! orders comes from exactly one of them.
example : fullDeck.Nodup := fullDeck_nodup
example : fullDeck.length = 52 := by decide
example (deck : List Card) (h : deck.Perm fullDeck) :
    ∃ picks, ValidPicks 52 picks ∧ pickWith picks fullDeck = deck :=
  every_order_possible fullDeck deck h

-- Compiled checks on the real shuffle: it is the picking method with the generator's numbers,
-- and seeds 2^64 apart give the same deck.
#guard shuffle 42 fullDeck == pickWith (seedPicks 52 42) fullDeck
#guard shuffle (42 + 2 ^ 64) fullDeck == shuffle 42 fullDeck
#guard shuffle 43 fullDeck != shuffle 42 fullDeck

#print axioms shuffle_eq_pickWith
#print axioms each_order_once
#print axioms fewer_seeds_than_orders
