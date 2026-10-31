import Engine.Hand

/-!
# Engine: the simple bot, and the moves the screen offers

The bot checks when it can and otherwise calls. It never folds and never raises.

`legalOptions` lists the moves the human's buttons should offer, worked out from the
spec's `Legal`, so the browser never decides what is legal.
-/

/-- The bot's move: check if nothing is owed, otherwise call. -/
def botMove (s : State) : Action :=
  if s.toCall = 0 then .check else .call

/-- **The bot only makes legal moves.** Whenever the player to act may act at all, the
bot's move is legal. -/
theorem botMove_legal (s : State) (h : s.MayAct) : Legal s (botMove s) := by
  unfold botMove
  split
  · exact ⟨h, by assumption⟩
  · exact ⟨h, by simp only; omega⟩

/-- The moves the screen offers the player to act.
- `fold`, `check`: whether that button works.
- `call`: chips needed to call, 0 when there is nothing to call. If the player has fewer
  chips than that, it is all they have (calling all-in).
- `raise`: the smallest and largest total bet for this round a raise can make, or
  `none` if no raise is allowed. The largest is always all-in. -/
structure LegalOptions where
  fold : Bool
  check : Bool
  call : Nat
  raise : Option (Nat × Nat)
  deriving Repr, BEq

/-- The moves the player to act may make in state `s`. -/
def legalOptions (s : State) : LegalOptions :=
  let me := s.toAct
  let allIn := s.bet me + s.stack me
  { fold := decide (Legal s .fold)
    check := decide (Legal s .check)
    call := if decide (Legal s .call) then min s.toCall (s.stack me) else 0
    raise :=
      if decide (Legal s (.raiseTo allIn)) then
        some (min (s.bet (other me) + s.minRaise) allIn, allIn)
      else none }

-- At the start of a hand, the small blind may fold, call 5, or raise to anything from 20
-- to 500 (all-in).
#guard legalOptions exStart == { fold := true, check := false, call := 5, raise := some (20, 500) }

-- After a short all-in, the other player may call or fold but not raise.
#guard legalOptions exShortAllIn == { fold := true, check := false, call := 50, raise := none }

-- A player who may not act gets no buttons at all.
#guard legalOptions exAllInToAct == { fold := false, check := false, call := 0, raise := none }

-- The bot calls when it owes chips and checks when it doesn't.
example : botMove exStart = .call := rfl
example : botMove { exStart with bet := fun _ => 10 } = .check := rfl

-- The bot's move is accepted by the engine in a real hand.
#guard (step (startHand (fun _ => startingStack) 0 7)
    (botMove (startHand (fun _ => startingStack) 0 7).chips)).toBool
