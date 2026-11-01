import Engine.Proofs.Session
import Engine.Proofs.Chips
import Engine.Proofs.RiskUtility

/-!
# Examples: every hypothesis met on a real input, and bad outputs rejected

CLAUDE.md §4 asks two things of each main theorem:
- an `example` on a concrete input where every hypothesis holds, so the theorem is not true
  only because its hypotheses can never hold;
- a known-bad output that the statement rejects, so the statement really says something.

This file does that for `step_keeps_chips` and `illegal_move_rejected` (on a hand built by
hand), and for the four session theorems of `Engine/Proofs/Session.lean`: (a)
`handle_error_unchanged`, (b) `handle_keeps_reachable`, (c) `bot_move_accepted` and (d)
`viewOf_toCall_le_pot`. Theorems (b) and (c) need a reachable game, which cannot be built
by hand, so they use real games: a new game, and hand 2 after the human folds hand 1.
-/

open Lean (Json toJson)

namespace ProofExamples

/-! ## A hand built by hand -/

/-- The start of a hand, built by hand: 500 chips each. Player 0 is on the button, posted
the small blind (5) and must act. Player 1 posted the big blind (10). Player 0 holds A♠ K♠
and player 1 holds 7♦ 2♣. No card is dealt in these examples, so the deck is left empty. -/
def exHand : Hand :=
  { chips := exStart
    street := .preflop
    button := 0
    hole := fun p => if p = 0 then [⟨12, .spades⟩, ⟨11, .spades⟩] else [⟨5, .diamonds⟩, ⟨0, .clubs⟩]
    board := []
    deck := []
    acted := fun _ => false
    ended := none }

/-! ### `step_keeps_chips` -/

/-- Every hypothesis met: the engine accepts the button's call, and the hand after it still
holds 1,000 chips. -/
example : ∃ h', step exHand .call = .ok h' ∧ h'.chips.total = 1000 := by
  obtain ⟨h', hs⟩ := legal_move_accepted exHand .call rfl (by decide)
  exact ⟨h', hs, (step_keeps_chips _ _ _ hs).trans (by decide)⟩

/-- A known-bad output: a table after the call where player 1 has one chip more than before
(491, not 490). It holds 1,001 chips. -/
def exChipFromNowhere : State :=
  { exStart with stack := fun p => if p = 0 then 490 else 491, bet := fun _ => 10 }

/-- `step_keeps_chips` rules it out: the engine never answers the call with that table. -/
example (h' : Hand) (hbad : h'.chips = exChipFromNowhere) : step exHand .call ≠ .ok h' := by
  intro hs
  have hkeep := step_keeps_chips _ _ _ hs
  rw [hbad] at hkeep
  exact absurd hkeep (by decide)

/-! ### `illegal_move_rejected` -/

/-- Every hypothesis met: the hand is not over, and checking is illegal because the button
owes 5 chips. The engine rejects the check. -/
example : step exHand .check = .error "illegal move" :=
  illegal_move_rejected exHand .check rfl (by decide)

/-- A known-bad output: an engine that accepted that check. The theorem rules out every new
hand. -/
example (h' : Hand) : step exHand .check ≠ .ok h' := by
  rw [illegal_move_rejected exHand .check rfl (by decide)]
  intro h
  cases h

/-! ## Real games -/

/-- Hand 2 of the game from seed 7, after the human folded hand 1. The bot (player 1) is on
the button with 505 chips and acts first. -/
def exGame2 : Game :=
  { hand := startHand ((newGame 7).hand.payFold 1).chips.stack 1 (handSeed 7 2),
    handNo := 2, seed := 7 }

/-- Hand 2 is reachable: a new game, the human's fold, then the next hand. -/
theorem exGame2_reachable : exGame2.Reachable :=
  .nextHand (g := { newGame 7 with hand := (newGame 7).hand.payFold 1 })
    (.act .fold (.start 7) rfl) rfl

/-- In hand 2 the hand is not over, and it is the bot's turn. -/
theorem exGame2_bot_to_act : exGame2.hand.ended = none ∧ exGame2.hand.chips.toAct = bot :=
  ⟨rfl, rfl⟩

/-- The session right after `new_game` with seed 7, Risk 50 and Bluff 33. The human is on
the button and acts first, so the bot has not moved yet. -/
def exSession : Session :=
  Session.dealt { game := newGame 7, sliders := ⟨50, 33⟩ } (newGame 7) (fun _ => startingStack)

/-- `Session.handle` accepts that `new_game` and gives `exSession`. -/
theorem exSession_start : Session.handle none (.newGame 7 50 33) = .ok exSession := rfl

/-! ### (c) `bot_move_accepted` -/

/-- Every hypothesis met: in hand 2 the game is reachable and the hand is not over (and it
is the bot's turn). So the engine accepts the move the bot picks there, with the sliders and
the hand seed the app uses. -/
example : ∃ h', step exGame2.hand
    (botDecide ⟨50, 33⟩ (handSeed 7 2) (exGame2.hand.hole bot) exGame2.hand.board
      exGame2.hand.chips).action = .ok h' :=
  bot_move_accepted exGame2 exGame2_reachable exGame2_bot_to_act.1 _ _ _ _

/-- A known-bad output: a bot that always checks. In hand 2 it owes 5 chips, so the engine
rejects its check. `bot_move_accepted` says this never happens to the slider bot. -/
example : ¬ ∃ h', step exGame2.hand .check = .ok h' := by
  rintro ⟨h', hs⟩
  exact absurd (accepted_move_is_legal _ _ _ hs) (by decide)

/-! ### (b) `handle_keeps_reachable` -/

/-- Every hypothesis met, from no game: `new_game` is accepted, so the new session's game is
reachable. -/
theorem exSession_reachable : exSession.game.Reachable :=
  handle_keeps_reachable none _ _ (fun _ h => nomatch h) exSession_start

/-- Every hypothesis met, with a game running: after `new_game` the human folds, which the
session accepts, and the game after the fold is reachable. -/
example : ∃ s', Session.handle (some exSession) (.act .fold) = .ok s' ∧ s'.game.Reachable := by
  obtain ⟨s', hs⟩ : ∃ s', Session.handle (some exSession) (.act .fold) = .ok s' := ⟨_, rfl⟩
  refine ⟨s', hs, handle_keeps_reachable _ _ _ (fun s h => ?_) hs⟩
  cases h
  exact exSession_reachable

/-- A known-bad output: a session whose table holds 1,001 chips. Its game is not reachable
(T1), so `handle_keeps_reachable` says `new_game` never gives it. -/
example (s' : Session) (hbad : s'.game.hand.chips.total = 1001) :
    Session.handle none (.newGame 7 50 33) ≠ .ok s' := by
  intro hs
  have := chips_always_1000 _ (handle_keeps_reachable none _ _ (fun _ h => nomatch h) hs)
  omega

/-- A session whose game is broken: its table holds 2,005 chips. -/
def exBadSession : Session :=
  { exSession with game := { exSession.game with hand := { exSession.game.hand with
      chips := { exStart with stack := fun _ => 995 } } } }

/-- Why `handle_keeps_reachable` assumes the old game is reachable: a `state` command accepts
any session and keeps its game, even this one, whose game is not reachable. -/
example : Session.handle (some exBadSession) .state = .ok { exBadSession with events := #[] } ∧
    ¬ exBadSession.game.Reachable := by
  refine ⟨rfl, fun hr => ?_⟩
  exact absurd (chips_always_1000 _ hr) (by decide)

/-! ### (a) `handle_error_unchanged` -/

/-- The request `{"cmd":"act","action":"check"}`, as JSON. -/
def exCheckJson : Json := Json.mkObj [("cmd", toJson "act"), ("action", toJson "check")]

-- Lean's JSON reader turns that request line into `exCheckJson`. `Json.parse` is a
-- `partial def`, so no proof can run it; this check runs it during the build.
#guard match Json.parse "{\"cmd\":\"act\",\"action\":\"check\"}" with
  | .ok j => j == exCheckJson
  | .error _ => false

/-- Every hypothesis met (the line's JSON by the `#guard` above): after `new_game`, the human
tries to check while owing 5 chips. The session rejects it with "illegal move", and
`respond` keeps the session and shows the table as it was. -/
example (line : String) (hjson : Json.parse line = .ok exCheckJson) :
    respond (some exSession) line =
      (some exSession, Json.mkObj [("error", toJson "illegal move"),
        ("state", stateJson { exSession with events := #[] })]) :=
  handle_error_unchanged (some exSession) line exCheckJson (.act .check) "illegal move"
    hjson rfl rfl

/-- Known-bad outputs: answering that rejected check by dropping the game, or by keeping any
other session. The theorem rules out both. -/
example (line : String) (hjson : Json.parse line = .ok exCheckJson) (s' : Session)
    (hother : s' ≠ exSession) (r : Json) :
    respond (some exSession) line ≠ (none, r) ∧ respond (some exSession) line ≠ (some s', r) := by
  rw [handle_error_unchanged (some exSession) line exCheckJson (.act .check) "illegal move"
    hjson rfl rfl]
  refine ⟨fun h => ?_, fun h => hother ?_⟩
  · simp only [Prod.mk.injEq, reduceCtorEq, false_and] at h
  · simp only [Prod.mk.injEq, Option.some.injEq] at h
    exact h.1.symm

/-! ### (d) `viewOf_toCall_le_pot` -/

/-- The theorem has no hypotheses. On `exHand` the button must call 5 to win a pot of 15. -/
example : (viewOf ⟨50, 33⟩ [] [] exHand.chips).toCall = 5 ∧
    (viewOf ⟨50, 33⟩ [] [] exHand.chips).pot = 15 := by decide

example : (viewOf ⟨50, 33⟩ [] [] exHand.chips).toCall ≤ (viewOf ⟨50, 33⟩ [] [] exHand.chips).pot :=
  viewOf_toCall_le_pot _ _ _ _

/-- After the spec's short all-in (`exShortAllIn`), the call is 50 and the pot is 350. -/
example : (viewOf ⟨50, 33⟩ [] [] exShortAllIn).toCall = 50 ∧
    (viewOf ⟨50, 33⟩ [] [] exShortAllIn).pot = 350 := by decide

/-- With it, the two Risk theorems apply to the real bot in every state, with no extra
condition. If the bot calls, the call is worth it at its Risk... -/
example (sl : Sliders) (seed : Nat) (hole board : List Card) (s : State)
    (hcall : (botDecide sl seed hole board s).action = .call) :
    (callGamble (countsFor seed hole board) (viewOf sl hole board s).pot
      (viewOf sl hole board s).toCall).Takes sl.risk :=
  bot_calls_only_when_worth_it _ _ (viewOf_toCall_le_pot sl hole board s) hcall

/-- ...and if it folds, the call is not worth it at its Risk. -/
example (sl : Sliders) (seed : Nat) (hole board : List Card) (s : State)
    (hfold : (botDecide sl seed hole board s).action = .fold) :
    ¬ (callGamble (countsFor seed hole board) (viewOf sl hole board s).pot
      (viewOf sl hole board s).toCall).Takes sl.risk :=
  bot_folds_only_when_not_worth_it _ _ (viewOf_toCall_le_pot sl hole board s) hfold

/-- A known-bad output: a view that counted only the chips from earlier betting rounds as
the pot. At the start of a hand that pot is 0, but the button must call 5, so such a view
would break the theorem. -/
example : ¬ (exHand.chips.toCall ≤ exHand.chips.pot) := by decide

end ProofExamples
