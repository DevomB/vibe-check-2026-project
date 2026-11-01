import Engine.Proofs.BluffSpec
import Engine.Proofs.EquityExact

/-!
# T7 `bluff_frequency`: the river betting set has as many bluffs as the Bluff slider asks for

When the bot faces no bet on the river, it bets with the hands in its river betting set
(`riverBettingSet` in `Engine/River.lean`): 30% of the hands it could hold for value, plus
some bluffs. These theorems say:

- on every river board, the set has 324 value hands, and its number of bluffs is the whole
  number nearest to the number that makes bluffs exactly Bluff% of the set (halves up);
- a hand is never both a value hand and a bluff;
- the bot's river bet (`riverBets`) is true for exactly the hands in this set.

They say nothing about how often the bot is seen to bluff over many games: that depends on
which cards it is dealt.

The definition these theorems use is in `Engine/Proofs/BluffSpec.lean`.
-/

/-! ## Helper lemmas -/

/-- On a river board, the bot could hold 1,081 hands: every pair of the 47 cards left. -/
theorem length_riverCandidates {board : List Card} (h5 : board.length = 5) (hd : board.Nodup) :
    (riverCandidates board).length = 1081 := by
  have hu := length_unseenCards (hole := []) (board := board) (by simpa using hd)
  rw [List.nil_append, h5] at hu
  have hp := length_pairs (unseenCards [] board)
  rw [hu] at hp
  unfold riverCandidates
  omega

theorem length_rankRiverHands {board : List Card} (h5 : board.length = 5) (hd : board.Nodup) :
    (rankRiverHands board).length = 1081 := by
  simp [rankRiverHands, List.length_mergeSort, length_riverCandidates h5 hd]

theorem mem_rankRiverHands {board : List Card} {h : RankedHand} (hm : h ∈ rankRiverHands board) :
    h.cards ∈ riverCandidates board := by
  simp only [rankRiverHands, List.mem_mergeSort, List.mem_map] at hm
  obtain ⟨⟨a, b⟩, hab, rfl⟩ := hm
  exact hab

/-- The two cards of a candidate hand are different. -/
theorem cards_ne {board : List Card} {h : RankedHand} (hm : h ∈ rankRiverHands board) :
    h.cards.1 ≠ h.cards.2 := by
  have hs := mem_pairs.mp (mem_rankRiverHands hm)
  have := (unseenCards_nodup [] board).sublist hs
  simpa using this

/-- If a list has no repeats after `f` is applied to each entry, it has no repeats. -/
theorem nodup_of_map {α β : Type} (f : α → β) : ∀ {l : List α}, (l.map f).Nodup → l.Nodup
  | [], _ => List.nodup_nil
  | _ :: _, h => by
    rw [List.map_cons, List.nodup_cons] at h
    exact List.nodup_cons.mpr ⟨fun hx => h.1 (List.mem_map_of_mem hx), nodup_of_map f h.2⟩

theorem rankRiverHands_nodup (board : List Card) : (rankRiverHands board).Nodup := by
  -- The hands' cards are the candidates, reordered, and no candidate is listed twice.
  have hperm : ((rankRiverHands board).map (·.cards)).Perm (riverCandidates board) := by
    have := (List.mergeSort_perm
      ((riverCandidates board).map fun (a, b) =>
        ({ cards := (a, b), score := bestScore ([a, b] ++ board) } : RankedHand))
      (fun x y => !decide (x.score < y.score))).map (·.cards)
    simpa [rankRiverHands, Function.comp_def] using this
  exact nodup_of_map _ (hperm.nodup_iff.mpr (pairs_nodup (unseenCards_nodup [] board)))

/-- At any Bluff setting from 0 to 60, 324 value hands get at most 486 bluffs. -/
theorem bluffCount_le (b : Nat) (hb : b ≤ 60) : bluffCount 324 b ≤ 486 := by
  revert b; decide

/-- `bluffCount` rounds `values × b / (100 − b)` to the nearest whole number, halves up. -/
theorem bluffCount_nearest (values b : Nat) (hb : b < 100) :
    NearestWhole (bluffCount values b) (values * b) (100 - b) := by
  unfold NearestWhole bluffCount
  generalize hd : 100 - b = d
  have hd0 : 0 < d := by omega
  rw [Nat.mul_assoc 2 values b]
  generalize values * b = p
  -- q is the quotient: q × 2d ≤ 2p + d < q × 2d + 2d.
  have h1 := Nat.div_mul_le_self (2 * p + d) (2 * d)
  have h2 := Nat.lt_mul_div_succ (2 * p + d) (show 0 < 2 * d by omega)
  generalize (2 * p + d) / (2 * d) = q at h1 h2 ⊢
  have e1 : 2 * q * d = q * (2 * d) := by rw [Nat.mul_comm 2 q, Nat.mul_assoc]
  have e2 : 2 * d * (q + 1) = q * (2 * d) + 2 * d := by
    rw [Nat.mul_comm, Nat.add_mul, Nat.one_mul]
  rw [e1]
  rw [e2] at h2
  generalize q * (2 * d) = m at h1 h2 ⊢
  constructor <;> omega

/-! ## The theorems -/

/-- T7 `bluff_frequency`. On a river board (five different cards), at any Bluff setting `b`
from 0 to 60, the bot's river betting set has 324 value hands (30% of the 1,081 hands it could
hold, rounded down), and its number of bluffs is the whole number nearest to
324 × b / (100 − b), halves up.

That is the Bluff target rounded to a whole hand: with B bluffs and 324 value hands, bluffs
are exactly b% of the set, B / (324 + B) = b / 100, when B = 324 × b / (100 − b). -/
theorem bluff_frequency (bluffPct : Nat) (board : List Card) (h5 : board.length = 5)
    (hd : board.Nodup) (hb : bluffPct ≤ 60) :
    (riverBettingSet bluffPct board).value.length = 324 ∧
    NearestWhole (riverBettingSet bluffPct board).bluffs.length (324 * bluffPct)
      (100 - bluffPct) := by
  have hn := length_rankRiverHands h5 hd
  have hB := bluffCount_le bluffPct hb
  have hv : valueCount 1081 = 324 := by decide
  have hbl : (riverBettingSet bluffPct board).bluffs.length = bluffCount 324 bluffPct := by
    simp only [riverBettingSet, List.length_drop, hn, hv]
    omega
  refine ⟨?_, hbl ▸ bluffCount_nearest 324 bluffPct (by omega)⟩
  simp only [riverBettingSet, List.length_take, hn, hv]
  omega

/-- On a river board, at any Bluff setting from 0 to 60, no hand is both a value hand and a
bluff. -/
theorem value_and_bluffs_apart (bluffPct : Nat) (board : List Card) (h5 : board.length = 5)
    (hd : board.Nodup) (hb : bluffPct ≤ 60) :
    ∀ h ∈ (riverBettingSet bluffPct board).value, h ∉ (riverBettingSet bluffPct board).bluffs := by
  have hn := length_rankRiverHands h5 hd
  have hB := bluffCount_le bluffPct hb
  have hv : valueCount 1081 = 324 := by decide
  simp only [riverBettingSet, hn, hv]
  -- The value hands come from the front of the ranking, the bluffs from the back, and the
  -- two parts do not meet: 324 + 486 ≤ 1081.
  have hsplit := List.take_append_drop 324 (rankRiverHands board)
  have hnd := rankRiverHands_nodup board
  rw [← hsplit, List.nodup_append] at hnd
  have hsub : ((rankRiverHands board).drop (1081 - bluffCount 324 bluffPct)).Sublist
      ((rankRiverHands board).drop 324) := by
    have : 1081 - bluffCount 324 bluffPct = (1081 - bluffCount 324 bluffPct - 324) + 324 := by
      omega
    rw [this, Nat.add_comm, ← List.drop_drop]
    exact List.drop_sublist _ _
  intro h hval hbluff
  exact hnd.2.2 h hval h (hsub.subset hbluff) rfl

/-- A hand from the ranking is the bot's hole cards `a`, `b` exactly when its cards are
`a`, `b` in one order or the other. -/
theorem isHole_pair {h : RankedHand} {a b : Card} (hne : h.cards.1 ≠ h.cards.2) :
    h.isHole [a, b] = true ↔ h.cards = (a, b) ∨ h.cards = (b, a) := by
  obtain ⟨⟨x, y⟩, s⟩ := h
  simp only [RankedHand.isHole, List.contains_cons, List.contains_nil, Bool.or_false,
    Bool.and_eq_true, Bool.or_eq_true, beq_iff_eq, Prod.mk.injEq] at hne ⊢
  constructor
  · rintro ⟨hx | hx, hy | hy⟩ <;> subst hx hy <;> simp_all
  · rintro (⟨rfl, rfl⟩ | ⟨rfl, rfl⟩) <;> simp

/-- The bot bets on the river (when it faces no bet) with exactly the hands in its river betting
set: `riverBets` is true for the hole cards `a`, `b` exactly when they are one of the value
hands or one of the bluffs, in either order. -/
theorem bot_bets_its_set (bluffPct : Nat) (board : List Card) (a b : Card) :
    riverBets bluffPct board [a, b] = true ↔
      ∃ h ∈ (riverBettingSet bluffPct board).value ++ (riverBettingSet bluffPct board).bluffs,
        h.cards = (a, b) ∨ h.cards = (b, a) := by
  have hall : ∀ h ∈ (riverBettingSet bluffPct board).value ++
      (riverBettingSet bluffPct board).bluffs, h.cards.1 ≠ h.cards.2 := by
    intro h hm
    simp only [riverBettingSet, List.mem_append] at hm
    rcases hm with hm | hm
    · exact cards_ne (List.mem_of_mem_take hm)
    · exact cards_ne (List.mem_of_mem_drop hm)
  have key : ((riverBettingSet bluffPct board).value ++
      (riverBettingSet bluffPct board).bluffs).any (·.isHole [a, b]) = true ↔
      ∃ h ∈ (riverBettingSet bluffPct board).value ++ (riverBettingSet bluffPct board).bluffs,
        h.cards = (a, b) ∨ h.cards = (b, a) := by
    simp only [List.any_eq_true]
    exact ⟨fun ⟨h, hm, hh⟩ => ⟨h, hm, (isHole_pair (hall h hm)).mp hh⟩,
      fun ⟨h, hm, hh⟩ => ⟨h, hm, (isHole_pair (hall h hm)).mpr hh⟩⟩
  rw [← key, List.any_append]
  simp only [riverBets, riverRole]
  cases (riverBettingSet bluffPct board).value.any (·.isHole [a, b]) <;>
    cases (riverBettingSet bluffPct board).bluffs.any (·.isHole [a, b]) <;> decide

/-! ## Checks

The theorems' conditions can hold on a real board, and the rounding rule rejects a bluff count
that is one too many or one too few. -/

/-- A river board: 2c 7d Js Qh 9s. -/
def exBoard : List Card :=
  [card 2 .clubs, card 7 .diamonds, card 11 .spades, card 12 .hearts, card 9 .spades]

-- Every condition holds on this board at Bluff 33%: 324 value hands, and 160 bluffs, the
-- whole number nearest to 324 × 33 / 67 = 159.58...
example : (riverBettingSet 33 exBoard).value.length = 324 ∧
    NearestWhole (riverBettingSet 33 exBoard).bluffs.length (324 * 33) (100 - 33) :=
  bluff_frequency 33 exBoard rfl (by decide) (by decide)
example : NearestWhole 160 (324 * 33) (100 - 33) := by decide

-- At Bluff 33%, 159 or 161 bluffs would not be the nearest whole number.
example : ¬ NearestWhole 159 (324 * 33) (100 - 33) := by decide
example : ¬ NearestWhole 161 (324 * 33) (100 - 33) := by decide
-- At Bluff 0% there are no bluffs; at 60% there are 486, half again as many as value hands.
example : NearestWhole 0 (324 * 0) (100 - 0) ∧ ¬ NearestWhole 1 (324 * 0) (100 - 0) := by decide
example : NearestWhole 486 (324 * 60) (100 - 60) ∧ ¬ NearestWhole 485 (324 * 60) (100 - 60) := by
  decide

#print axioms bluff_frequency
#print axioms value_and_bluffs_apart
#print axioms bot_bets_its_set
