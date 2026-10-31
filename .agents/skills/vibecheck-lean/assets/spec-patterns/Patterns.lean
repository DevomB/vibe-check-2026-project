/-!
# Spec patterns

One small, compiled example per question in the spec interview
(`references/spec-elicitation.md`). Copy the shape, not the example.
Check: `lean Patterns.lean` compiles with no errors and no `sorry`.
-/

/-! ## The running example: a bounded inventory -/

structure Stock where
  stock : Nat
  cap : Nat
  ok : stock ≤ cap

inductive Op where
  | add (n : Nat)
  | take (n : Nat)

/-- Adds as much as fits; takes only if there is enough. Returns whether the op fully succeeded. -/
def Stock.apply (s : Stock) : Op → Stock × Bool
  | .add n => if h : s.stock + n ≤ s.cap then (⟨s.stock + n, s.cap, h⟩, true) else (s, false)
  | .take n => if h : n ≤ s.stock then (⟨s.stock - n, s.cap, by have := s.ok; omega⟩, true) else (s, false)

def Stock.run (s : Stock) (ops : List Op) : Stock := ops.foldl (fun s o => (s.apply o).1) s

/-! ## Never: a bad thing cannot happen -/

/-- Taking never makes stock negative or larger. (Nat can't go negative; the real claim is "no wraparound".) -/
theorem take_never_grows (s : Stock) (n : Nat) : ((s.apply (.take n)).1).stock ≤ s.stock := by
  simp only [Stock.apply]; split <;> simp

/-! ## Always possible: the liveness partner of every "never" -/

/-- If there is room, an add succeeds. Without this, "refuse everything" would satisfy every safety property. -/
theorem add_succeeds_if_room (s : Stock) (n : Nat) (h : s.stock + n ≤ s.cap) :
    (s.apply (.add n)).2 = true := by
  simp [Stock.apply, h]

/-! ## Bounds and invariants over every reachable state -/

/-- Stock stays within capacity after any sequence of operations. (Here the type enforces it;
    when it doesn't, prove `inv init` and `inv s → inv (step s e)`, then induct over the list.) -/
theorem run_within_cap (s : Stock) (ops : List Op) : (s.run ops).stock ≤ (s.run ops).cap :=
  (s.run ops).ok

/-- Capacity never changes, by induction over the operation list. -/
theorem run_keeps_cap (s : Stock) (ops : List Op) : (s.run ops).cap = s.cap := by
  induction ops generalizing s with
  | nil => rfl
  | cons o os ih =>
    simp only [Stock.run, List.foldl] at *
    rw [ih]
    cases o <;> simp only [Stock.apply] <;> split <;> rfl

/-! ## Roundtrip: decode undoes encode -/

def encodeOp : Op → Int
  | .add n => n + 1
  | .take n => -(n + 1)

def decodeOp (i : Int) : Option Op :=
  if 0 < i then some (.add (i - 1).toNat) else if i < 0 then some (.take (-i - 1).toNat) else none

theorem decode_encode (o : Op) : decodeOp (encodeOp o) = some o := by
  cases o <;> simp [encodeOp, decodeOp] <;> omega

/-! ## Equivalence: the fast version equals the reference -/

def totalAddedRef : List Op → Nat
  | [] => 0
  | .add n :: os => n + totalAddedRef os
  | .take _ :: os => totalAddedRef os

def totalAddedFast (ops : List Op) : Nat :=
  ops.foldl (fun acc o => match o with | .add n => acc + n | .take _ => acc) 0

theorem totalAdded_eq (ops : List Op) : totalAddedFast ops = totalAddedRef ops := by
  suffices ∀ acc, ops.foldl (fun acc o => match o with | .add n => acc + n | .take _ => acc) acc
      = acc + totalAddedRef ops by simpa [totalAddedFast] using this 0
  induction ops with
  | nil => simp [totalAddedRef]
  | cons o os ih => intro acc; cases o <;> simp [totalAddedRef, ih] <;> omega

/-! ## Idempotence and order independence -/

/-- Drop empty entries. -/
def normalize (xs : List Nat) : List Nat := xs.filter (· != 0)

theorem normalize_idem (xs : List Nat) : normalize (normalize xs) = normalize xs := by
  simp [normalize, List.filter_filter]

/-! ## Monotonicity: something only grows -/

def appendLog (log : List String) (e : String) : List String := log ++ [e]

theorem log_grows (log : List String) (e : String) : log.length < (appendLog log e).length := by
  simp [appendLog]

/-! ## Finding: a proved fact that the code misbehaves -/

def unsafeTake (stock n : Int) : Int := stock - n     -- the original forgot the check

/-- FINDING: without the check, taking more than is in stock goes negative. -/
theorem finding_unsafeTake_negative : ∃ stock n : Int, 0 ≤ stock ∧ unsafeTake stock n < 0 :=
  ⟨0, 1, by decide, by decide⟩
