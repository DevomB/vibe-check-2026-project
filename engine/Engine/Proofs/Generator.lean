import Engine.Proofs.GeneratorSpec

/-!
# How evenly the shuffle's generator spreads its numbers (randomness, part 2)

The spec, in plain words, is in `Engine/Proofs/GeneratorSpec.lean`. These theorems say:

1. `seedPicks_eq`: the numbers the shuffle uses (`seedPicks`) are the generator's numbers
   `genOutput seed 0`, `genOutput seed 1`, and so on.
2. `genState_injective`, `genState_onto`: the step visits all 2^64 states, each once, before it
   repeats (it adds an odd number).
3. `mixSeed_injective`, `mixSeed_onto`: the scrambling (`mixSeed`) loses nothing: different
   states give different numbers, and every number below 2^64 comes from some state.
4. `every_number_once`: so among the first 2^64 numbers from any seed, every number below 2^64
   comes out exactly once.

How: the scramble is three xor-shifts and two multiplications by odd numbers, on 64 bits. Each
of those can be undone, so the proof writes down the exact inverse (`unmixBV`) and checks both
directions. The proof device (`xs`, `mixBV`, `unmixBV`) is not part of the statements.

Not proved: that consecutive numbers are unrelated, or that the numbers cannot be predicted.
Those are statistical properties of a fixed rule, which tests check and proofs cannot.
-/

/-! ## The scramble can be undone (proof device, on 64-bit numbers) -/

/-- One xor-shift step on 64 bits: `x` xor (`x` shifted right by `k`). -/
def xs (k : Nat) (x : BitVec 64) : BitVec 64 := x ^^^ (x >>> k)
/-- Its inverse when `3k ≥ 64`. -/
def unxs (k : Nat) (y : BitVec 64) : BitVec 64 := y ^^^ (y >>> k) ^^^ (y >>> (2 * k))

/-- `a` xor `a` cancels. -/
theorem xor_cancel_left (a b : BitVec 64) : a ^^^ (a ^^^ b) = b := by
  rw [← BitVec.xor_assoc, BitVec.xor_self, BitVec.zero_xor]

/-- Xor can swap its first two terms. -/
theorem xor_left_comm (a b c : BitVec 64) : a ^^^ (b ^^^ c) = b ^^^ (a ^^^ c) := by
  rw [← BitVec.xor_assoc, BitVec.xor_comm a b, BitVec.xor_assoc]

/-- Undoing an xor-shift step (when `3k ≥ 64`) gives back the number. -/
theorem unxs_xs (k : Nat) (hk : 64 ≤ 3 * k) (x : BitVec 64) : unxs k (xs k x) = x := by
  simp only [unxs, xs, BitVec.ushiftRight_xor_distrib, ← BitVec.shiftRight_add]
  have h3 : x >>> (k + 2 * k) = 0#64 := BitVec.ushiftRight_eq_zero (by omega)
  have h2 : k + k = 2 * k := by omega
  rw [h2, h3]
  generalize x >>> k = a
  generalize x >>> (2 * k) = b
  simp only [BitVec.xor_assoc, BitVec.xor_zero, BitVec.xor_self, xor_cancel_left]

/-- And the other way round. -/
theorem xs_unxs (k : Nat) (hk : 64 ≤ 3 * k) (y : BitVec 64) : xs k (unxs k y) = y := by
  simp only [unxs, xs, BitVec.ushiftRight_xor_distrib, ← BitVec.shiftRight_add]
  have h3 : y >>> (2 * k + k) = 0#64 := BitVec.ushiftRight_eq_zero (by omega)
  have h2 : k + k = 2 * k := by omega
  rw [h2, h3]
  generalize y >>> k = a
  generalize y >>> (2 * k) = b
  simp only [BitVec.xor_assoc, BitVec.xor_zero, BitVec.xor_self]

/-- Multiplying by `c` and then by its inverse `d` gives back the number. -/
theorem mul_inv (x c d : BitVec 64) (h : c * d = 1#64) : x * c * d = x := by
  rw [BitVec.mul_assoc, h, BitVec.mul_one]

/-- The inverses of SplitMix64's two multipliers, modulo 2^64 (checked by computing). -/
theorem inv1 : (0xBF58476D1CE4E5B9#64 : BitVec 64) * 0x96DE1B173F119089#64 = 1#64 := by
  apply BitVec.eq_of_toNat_eq; rw [BitVec.toNat_mul]; rfl
theorem inv1' : (0x96DE1B173F119089#64 : BitVec 64) * 0xBF58476D1CE4E5B9#64 = 1#64 := by
  apply BitVec.eq_of_toNat_eq; rw [BitVec.toNat_mul]; rfl
theorem inv2' : (0x319642B2D24D8EC3#64 : BitVec 64) * 0x94D049BB133111EB#64 = 1#64 := by
  apply BitVec.eq_of_toNat_eq; rw [BitVec.toNat_mul]; rfl
theorem inv2 : (0x94D049BB133111EB#64 : BitVec 64) * 0x319642B2D24D8EC3#64 = 1#64 := by
  apply BitVec.eq_of_toNat_eq; rw [BitVec.toNat_mul]; rfl

/-- `mixSeed` on 64-bit numbers. -/
def mixBV (x : BitVec 64) : BitVec 64 :=
  xs 31 (xs 27 (xs 30 x * 0xBF58476D1CE4E5B9#64) * 0x94D049BB133111EB#64)

/-- The inverse of `mixBV`: undo each step, last first. -/
def unmixBV (y : BitVec 64) : BitVec 64 :=
  unxs 30 (unxs 27 (unxs 31 y * 0x319642B2D24D8EC3#64) * 0x96DE1B173F119089#64)

/-- Undoing the scramble gives back the state. -/
theorem unmixBV_mixBV (x : BitVec 64) : unmixBV (mixBV x) = x := by
  simp only [unmixBV, mixBV]
  rw [unxs_xs 31 (by omega), mul_inv _ _ _ inv2, unxs_xs 27 (by omega),
    mul_inv _ _ _ inv1, unxs_xs 30 (by omega)]

/-- Scrambling an unscrambled number gives back the number. -/
theorem mixBV_unmixBV (y : BitVec 64) : mixBV (unmixBV y) = y := by
  simp only [unmixBV, mixBV]
  rw [xs_unxs 30 (by omega), mul_inv _ _ _ inv1', xs_unxs 27 (by omega),
    mul_inv _ _ _ inv2', xs_unxs 31 (by omega)]

/-- An xor-shift step, as whole numbers. -/
theorem toNat_xs (k : Nat) (x : BitVec 64) : (xs k x).toNat = x.toNat ^^^ (x.toNat >>> k) := by
  rw [xs, BitVec.toNat_xor, BitVec.toNat_ushiftRight]

/-- Multiplying by a 64-bit constant, as whole numbers. -/
theorem toNat_mul_const (x : BitVec 64) (c : Nat) (hc : c < 2 ^ 64) :
    (x * BitVec.ofNat 64 c).toNat = x.toNat * c % 2 ^ 64 := by
  rw [BitVec.toNat_mul, BitVec.toNat_ofNat, Nat.mod_eq_of_lt hc]

/-- The engine's `mixSeed`, on a number below 2^64, is `mixBV`. -/
theorem mixSeed_eq_mixBV (s : Nat) (hs : s < 2 ^ 64) :
    mixSeed s = (mixBV (BitVec.ofNat 64 s)).toNat := by
  rw [mixBV, toNat_xs, toNat_mul_const _ _ (by decide), toNat_xs, toNat_mul_const _ _ (by decide),
    toNat_xs, BitVec.toNat_ofNat, Nat.mod_eq_of_lt hs]
  rfl

/-- A 64-bit number read back from its whole-number value is itself. -/
theorem ofNat_toNat64 (x : BitVec 64) : BitVec.ofNat 64 x.toNat = x := by
  apply BitVec.eq_of_toNat_eq
  rw [BitVec.toNat_ofNat, Nat.mod_eq_of_lt x.isLt]

/-- **The scrambling loses nothing.** Two states below 2^64 with the same scrambled number
are the same state. -/
theorem mixSeed_injective (s t : Nat) (hs : s < 2 ^ 64) (ht : t < 2 ^ 64)
    (h : mixSeed s = mixSeed t) : s = t := by
  rw [mixSeed_eq_mixBV s hs, mixSeed_eq_mixBV t ht] at h
  have h1 := congrArg unmixBV (BitVec.eq_of_toNat_eq h)
  rw [unmixBV_mixBV, unmixBV_mixBV] at h1
  have h2 := congrArg BitVec.toNat h1
  rw [BitVec.toNat_ofNat, BitVec.toNat_ofNat, Nat.mod_eq_of_lt hs, Nat.mod_eq_of_lt ht] at h2
  exact h2

/-- **Every 64-bit number is the scramble of some state.** -/
theorem mixSeed_onto (y : Nat) (hy : y < 2 ^ 64) : ∃ s, s < 2 ^ 64 ∧ mixSeed s = y := by
  refine ⟨(unmixBV (BitVec.ofNat 64 y)).toNat, BitVec.isLt _, ?_⟩
  rw [mixSeed_eq_mixBV _ (BitVec.isLt _), ofNat_toNat64, mixBV_unmixBV, BitVec.toNat_ofNat,
    Nat.mod_eq_of_lt hy]

/-- The step number as a 64-bit number, and its inverse. -/
theorem stepInv : BitVec.ofNat 64 genStep * 0xF1DE83E19937733D#64 = 1#64 := by
  apply BitVec.eq_of_toNat_eq; rw [BitVec.toNat_mul]; rfl
theorem stepInv' : (0xF1DE83E19937733D#64 : BitVec 64) * BitVec.ofNat 64 genStep = 1#64 := by
  apply BitVec.eq_of_toNat_eq; rw [BitVec.toNat_mul]; rfl

/-- `genState` as 64-bit arithmetic. -/
theorem genState_eq (s k : Nat) :
    genState s k = (BitVec.ofNat 64 s + BitVec.ofNat 64 k * BitVec.ofNat 64 genStep).toNat := by
  rw [BitVec.toNat_add, BitVec.toNat_mul, BitVec.toNat_ofNat, BitVec.toNat_ofNat,
    BitVec.toNat_ofNat, genState]
  conv => lhs; rw [Nat.add_mod, Nat.mul_mod]

/-- **The step visits a different state each time, for 2^64 steps.** -/
theorem genState_injective (s a b : Nat) (h : genState s a = genState s b) :
    a % 2 ^ 64 = b % 2 ^ 64 := by
  rw [genState_eq, genState_eq] at h
  have h1 := (BitVec.add_right_inj _).mp (BitVec.eq_of_toNat_eq h)
  have h2 := congrArg (· * 0xF1DE83E19937733D#64) h1
  simp only [mul_inv _ _ _ stepInv] at h2
  have h3 := congrArg BitVec.toNat h2
  rw [BitVec.toNat_ofNat, BitVec.toNat_ofNat] at h3
  exact h3

/-- **The step reaches every state.** From any seed, every state below 2^64 is reached within
2^64 steps. -/
theorem genState_onto (s t : Nat) (ht : t < 2 ^ 64) : ∃ a, a < 2 ^ 64 ∧ genState s a = t := by
  refine ⟨((BitVec.ofNat 64 t - BitVec.ofNat 64 s) * 0xF1DE83E19937733D#64).toNat,
    BitVec.isLt _, ?_⟩
  rw [genState_eq, ofNat_toNat64, mul_inv _ _ _ stepInv', BitVec.add_comm, BitVec.sub_add_cancel,
    BitVec.toNat_ofNat, Nat.mod_eq_of_lt ht]

/-- The state only depends on the number of steps modulo 2^64. -/
theorem genState_mod (s a : Nat) : genState s a = genState s (a % 2 ^ 64) := by
  have h : BitVec.ofNat 64 (a % 2 ^ 64) = BitVec.ofNat 64 a := by
    apply BitVec.eq_of_toNat_eq
    rw [BitVec.toNat_ofNat, BitVec.toNat_ofNat, Nat.mod_mod]
  rw [genState_eq, genState_eq, h]

/-- **Every number once per cycle.** Among the first 2^64 numbers the generator gives from any
seed, every number below 2^64 comes out exactly once. -/
theorem every_number_once (seed y : Nat) (hy : y < 2 ^ 64) :
    (∃ k, k < 2 ^ 64 ∧ genOutput seed k = y) ∧
      ∀ k k', k < 2 ^ 64 → k' < 2 ^ 64 → genOutput seed k = y → genOutput seed k' = y →
        k = k' := by
  constructor
  · obtain ⟨t, ht, hmix⟩ := mixSeed_onto y hy
    obtain ⟨a, ha, hst⟩ := genState_onto seed t ht
    refine ⟨(a + 2 ^ 64 - 1) % 2 ^ 64, Nat.mod_lt _ (by decide), ?_⟩
    rw [genOutput, genState_mod, show ((a + 2 ^ 64 - 1) % 2 ^ 64 + 1) % 2 ^ 64 = a by omega, hst,
      hmix]
  · intro k k' hk hk' h1 h2
    have hs := mixSeed_injective _ _ (Nat.mod_lt _ (by decide)) (Nat.mod_lt _ (by decide))
      (h1.trans h2.symm)
    have := genState_injective seed _ _ hs
    omega

/-- One step from state number `a` is state number `a + 1`. -/
theorem nextSeed_genState (s a : Nat) : nextSeed (genState s a) = genState s (a + 1) := by
  show (genState s a + genStep) % 2 ^ 64 = genState s (a + 1)
  rw [genState, genState, Nat.mod_add_mod, Nat.add_mul, Nat.one_mul, Nat.add_assoc]

attribute [local irreducible] mixSeed in
/-- `seedPicks` from a state `x` one step before state `a + 1`: the scrambles of states
`a + 1`, `a + 2`, and so on. -/
theorem seedPicks_from (s : Nat) : ∀ (n a x : Nat), nextSeed x = genState s (a + 1) →
    seedPicks n x = (List.range n).map fun j => mixSeed (genState s (a + 1 + j))
  | 0, _, _, _ => rfl
  | n + 1, a, x, hx => by
    rw [seedPicks, hx, seedPicks_from s n (a + 1) _ (nextSeed_genState s (a + 1))]
    have hf : (fun j => mixSeed (genState s (a + 1 + 1 + j))) =
        ((fun j => mixSeed (genState s (a + 1 + j))) ∘ Nat.succ) := by
      funext j
      rw [Function.comp_apply, show a + 1 + 1 + j = a + 1 + Nat.succ j by omega]
    rw [hf, List.range_succ_eq_map, List.map_cons, List.map_map, Nat.add_zero]

/-- **The shuffle's numbers are the generator's numbers.** `seedPicks`, which the shuffle uses
(`shuffle_eq_pickWith`), gives `genOutput seed 0`, `genOutput seed 1`, and so on. -/
theorem seedPicks_eq (n seed : Nat) : seedPicks n seed = (List.range n).map (genOutput seed) := by
  have h : nextSeed seed = genState seed (0 + 1) := by
    rw [genState, Nat.zero_add, Nat.one_mul]
    rfl
  rw [seedPicks_from seed n 0 seed h]
  have hf : (fun j => mixSeed (genState seed (0 + 1 + j))) = genOutput seed := by
    funext j
    rw [genOutput, show 0 + 1 + j = j + 1 by omega]
  rw [hf]

/-! ## Examples: every hypothesis met, and wrong answers rejected -/

-- The main theorem applies to a real seed and a real number: seed 42, the number 7.
example : (∃ k, k < 2 ^ 64 ∧ genOutput 42 k = 7) := (every_number_once 42 7 (by decide)).1

-- Why the step must be odd: stepping by the even number 2^63 returns to the start after only
-- two steps, so it would visit just 2 of the 2^64 states.
example : (0 + 2 * 2 ^ 63) % 2 ^ 64 = 0 := by decide

-- Compiled checks: the shuffle's numbers are the generator's numbers, the scramble is undone
-- by `unmixBV`, and the engine's `mixSeed` matches the 64-bit version.
#guard seedPicks 3 42 == [genOutput 42 0, genOutput 42 1, genOutput 42 2]
#guard unmixBV (mixBV 123456789#64) == 123456789#64
#guard mixSeed 123456789 == (mixBV 123456789#64).toNat

#print axioms seedPicks_eq
#print axioms every_number_once
#print axioms mixSeed_injective
