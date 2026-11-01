import Engine.Proofs.Session

/-!
# Checks for `legal_move_accepted`

`legal_move_accepted` (proved in `Engine/Proofs/Session.lean`) is the other half of T3:
`accepted_move_is_legal` and `illegal_move_rejected` say the engine never accepts a bad move,
which an engine that rejects everything would also satisfy. This one says every legal move
in a hand that is not over is accepted.
-/

/-- The conditions can hold: on a real deal (500 chips each), the small blind may call, so
the engine accepts the call. -/
example : ∃ h', step (startHand (fun _ => startingStack) 0 7) .call = .ok h' :=
  legal_move_accepted _ _ rfl (by decide)

/-- The same for a raise to 20, the smallest raise allowed there. -/
example : ∃ h', step (startHand (fun _ => startingStack) 0 7) (.raiseTo 20) = .ok h' :=
  legal_move_accepted _ _ rfl (by decide)

/-- The statement rejects an engine that turns this legal call away: on the real deal, `step`
never answers the call with an error, whatever the message. -/
example (msg : String) :
    step (startHand (fun _ => startingStack) 0 7) .call ≠ .error msg := by
  obtain ⟨h', hok⟩ :=
    legal_move_accepted (startHand (fun _ => startingStack) 0 7) .call rfl (by decide)
  rw [hok]; intro h; cases h

#print axioms legal_move_accepted
