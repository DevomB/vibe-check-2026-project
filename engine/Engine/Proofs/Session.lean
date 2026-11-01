import Engine.Protocol
import Engine.Proofs.Legal
import Engine.Proofs.BotLegal

/-!
# The game session: proofs about the code the app runs

The app keeps one `Option Session` (no game yet, or the game being played). For each
request line, `Main.lean` replaces it with `(respond cur line).1` (`Engine/Protocol.lean`).
`respond` reads the request and runs `Session.handle` (`Engine/Session.lean`), which plays
the human's move and then the bot's moves (`Session.runBot`). The theorems here are about
those functions, not about copies of them.

## The statements

**(a) `handle_error_unchanged`.** If a request line holds a game command and
`Session.handle` rejects that command, `respond` keeps the session exactly as it was. Its
reply is the error message and the table as it was before, with no new events.

    theorem handle_error_unchanged (cur : Option Session) (line : String) (j : Json)
        (c : Command) (e : String)
        (hjson : Json.parse line = .ok j) (hreq : parseRequest j = .ok (.game c))
        (hrej : Session.handle cur c = .error e) :
        respond cur line =
          (cur, Json.mkObj [("error", toJson e),
            ("state", match cur with
              | some s => stateJson { s with events := #[] }
              | none => Json.null)])

**(b) `handle_keeps_reachable`.** Suppose the session's game is reachable, or there is no
game yet. If `Session.handle` accepts a command, the new session's game is reachable too.
The assumption is needed: a `state` command accepts any session and keeps its game. With
`chips_always_1000` and `no_card_dealt_twice`, T1 and T2 then hold for the game the app
plays.

    theorem handle_keeps_reachable (cur : Option Session) (c : Command) (s' : Session)
        (hcur : ∀ s, cur = some s → s.game.Reachable)
        (hok : Session.handle cur c = .ok s') :
        s'.game.Reachable

**(c) `bot_move_accepted`.** In a reachable game where the hand is not over, `step`
accepts the move the slider bot picks, for any sliders, seed and cards.

    theorem bot_move_accepted (g : Game) (hg : g.Reachable) (hnot : g.hand.ended = none)
        (sl : Sliders) (seed : Nat) (hole board : List Card) :
        ∃ h', step g.hand (botDecide sl seed hole board g.hand.chips).action = .ok h'

**(d) `viewOf_toCall_le_pot`.** In every state, the chips the bot must add to call are at
most the pot it can win. No reachability is needed. So the condition `v.toCall ≤ v.pot` of
`bot_calls_only_when_worth_it` and `bot_folds_only_when_not_worth_it` holds for every view
the bot really gets. It is about the bot alone, so its proof goes in
`Engine/Proofs/RiskUtility.lean`.

    theorem viewOf_toCall_le_pot (sl : Sliders) (hole board : List Card) (s : State) :
        (viewOf sl hole board s).toCall ≤ (viewOf sl hole board s).pot

## What to review

The statements mention `respond`, `parseRequest`, `stateJson`, `Session.handle` (and what
it runs: `Session.start`, `Session.dealt`, `Session.humanAct`, `Session.move`,
`Session.runBot`), `Game.Reachable`, `step`, `botDecide`, `viewOf`, `State.toCall` and
`State.potToWin`.

`Json.parse` is a `partial def` in Lean's library, so no proof can work out what it returns
for a given line. The theorems hold whatever it returns.
-/

open Lean (Json toJson)

/-! ## Small facts about moves -/

/-- A legal move in a hand that is not over is accepted. -/
theorem legal_move_accepted (h : Hand) (a : Action) (hnot : h.ended = none)
    (hl : Legal h.chips a) : ∃ h', step h a = .ok h' := by
  unfold step
  simp only [hnot, Option.isSome_none, Bool.false_eq_true, ↓reduceIte, hl, not_true_eq_false]
  split <;> exact ⟨_, rfl⟩

/-- If `step` accepts a move in the game's hand, the game accepts it. -/
theorem Game.act_of_step {g : Game} {a : Action} {h' : Hand} (hs : step g.hand a = .ok h') :
    g.act a = .ok { g with hand := h' } := by
  simp [Game.act, hs, bind, Except.bind, pure, Except.pure]

/-- If the game accepts a move, so does the session. -/
theorem Session.move_ok_of_act {s : Session} {a : Action} {g' : Game}
    (hg : s.game.act a = .ok g') : ∃ next, s.move a = .ok next := by
  unfold Session.move
  simp [hg, bind, Except.bind, pure, Except.pure]

/-! ## (c) The bot's move is accepted -/

/-- **(c) The engine accepts the slider bot's move.** In a reachable game where the hand is
not over, `step` accepts the move `botDecide` picks, for any sliders, seed and cards. -/
theorem bot_move_accepted (g : Game) (hg : g.Reachable) (hnot : g.hand.ended = none)
    (sl : Sliders) (seed : Nat) (hole board : List Card) :
    ∃ h', step g.hand (botDecide sl seed hole board g.hand.chips).action = .ok h' :=
  legal_move_accepted _ _ hnot
    (botDecide_legal sl seed hole board _ (player_to_act_may_act g hg hnot))

/-- In a session whose game is reachable, when it is the bot's turn, the session accepts
the bot's move: `Session.runBot` never needs its fallback. -/
theorem Session.botChoice_accepted (s : Session) (hs : s.game.Reachable)
    (hbot : s.botToAct = true) : ∃ next, s.move s.botChoice.action = .ok next := by
  have hnot : s.game.hand.ended = none := by
    simp only [Session.botToAct, Bool.and_eq_true, Option.isNone_iff_eq_none] at hbot
    exact hbot.1
  obtain ⟨h', hstep⟩ := bot_move_accepted s.game hs hnot s.sliders
    (handSeed s.game.seed s.game.handNo) (s.game.hand.hole bot) s.game.hand.board
  exact Session.move_ok_of_act (Game.act_of_step hstep)

#print axioms bot_move_accepted
#print axioms Session.botChoice_accepted
