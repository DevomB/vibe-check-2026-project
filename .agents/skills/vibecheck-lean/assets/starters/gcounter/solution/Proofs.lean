import __LIB__.Spec

namespace __LIB__.Proofs
open __LIB__

theorem incr_comm (c : GCounter n) (i j : Fin n) : (c.incr i).incr j = (c.incr j).incr i := by
  funext k; simp only [GCounter.incr]; split <;> split <;> grind

theorem converges : Spec.converges := by
  intro n c l₁ l₂ h
  induction h generalizing c with
  | nil => rfl
  | cons x _ ih => exact ih (c.incr x)
  | swap x y l => simp [GCounter.applyAll, List.foldl, incr_comm]
  | trans _ _ ih1 ih2 => exact (ih1 c).trans (ih2 c)

theorem mergeComm : Spec.mergeComm := by
  intro n a b; funext i; simp only [GCounter.merge]; omega

theorem mergeAssoc : Spec.mergeAssoc := by
  intro n a b c; funext i; simp only [GCounter.merge]; omega

theorem mergeIdem : Spec.mergeIdem := by
  intro n a; funext i; simp [GCounter.merge]

end __LIB__.Proofs
