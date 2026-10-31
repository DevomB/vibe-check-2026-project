import __LIB__.Spec

namespace __LIB__.Proofs
open __LIB__

theorem roundtrip : Spec.roundtrip := by
  intro s
  induction s with
  | nil => rfl
  | cons c cs ih =>
    simp only [encode]
    split
    · next d n rest heq =>
      rw [heq] at ih
      split
      · next hcd => subst hcd; simp_all [decode, List.replicate_succ]
      · simp_all [decode]
    · next heq => rw [heq] at ih; simp_all [decode]

theorem countsPositive : Spec.countsPositive := by
  intro s
  induction s with
  | nil => simp [encode]
  | cons c cs ih =>
    simp only [encode]
    split
    · next d n rest heq =>
      rw [heq] at ih
      split <;> simp_all <;> exact fun a b hab => ih.2 a b hab
    · simp

end __LIB__.Proofs
