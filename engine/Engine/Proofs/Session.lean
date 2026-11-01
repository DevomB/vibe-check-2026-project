import Engine.Protocol
import Engine.Proofs.Legal
import Engine.Proofs.BotLegal
import Engine.Proofs.OneSlider

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

The statement covers every valid Peek setting and every build identity. Those affect
only the serialized table; they never change the session kept after a rejected command.

**(b) `handle_keeps_reachable`.** Suppose the session's game is reachable, or there is no
game yet. If `Session.handle` accepts a command, the new session's game is reachable too.
The assumption is needed: a `state` command accepts any session and keeps its game.
`app_game_reachable` below follows the app from its first line, so with
`chips_always_1000` and `no_card_dealt_twice`, T1 and T2 hold for the game the app plays.

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
the bot really gets. It is about the bot alone, so it is proved in
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

/-- If the session accepts a move, the game accepted it and the session holds the new game. -/
theorem Session.move_game {s next : Session} {a : Action} (hm : s.move a = .ok next) :
    s.game.act a = .ok next.game := by
  unfold Session.move at hm
  cases hg : s.game.act a with
  | error e => simp [hg, bind, Except.bind] at hm
  | ok g' =>
    simp [hg, bind, Except.bind, pure, Except.pure] at hm
    subst hm
    rfl

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
the bot's move. So the `.error` branch of `Session.runBot` is never taken in the app (see
"The removed fallback" below). -/
theorem Session.botChoice_accepted (s : Session) (hs : s.game.Reachable)
    (hbot : s.botToAct = true) : ∃ next, s.move s.botChoice.action = .ok next := by
  have hnot : s.game.hand.ended = none := by
    simp only [Session.botToAct, Bool.and_eq_true, Option.isNone_iff_eq_none] at hbot
    exact hbot.1
  obtain ⟨h', hstep⟩ := bot_move_accepted s.game hs hnot s.sliders
    (handSeed s.game.seed s.game.handNo) (s.game.hand.hole bot) s.game.hand.board
  -- The reason quotes the player's Risk; the move is the same (`botDecide_action_shown`).
  unfold Session.botChoice
  rw [botDecide_action_shown]
  exact Session.move_ok_of_act (Game.act_of_step hstep)

/-! ## (b) Every accepted command keeps the game reachable -/

/-- Picking one of two sessions whose games are reachable gives a reachable game. -/
theorem ite_game_reachable {c : Prop} [Decidable c] {a b : Session}
    (ha : a.game.Reachable) (hb : b.game.Reachable) : (if c then a else b).game.Reachable := by
  split <;> assumption

/-- The bot's moves keep the game reachable. -/
theorem Session.runBot_reachable : ∀ (fuel : Nat) (s : Session), s.game.Reachable →
    (Session.runBot fuel s).game.Reachable := by
  intro fuel
  induction fuel with
  | zero => intro s hs; exact hs
  | succ fuel ih =>
    intro s hs
    unfold Session.runBot
    split
    · exact hs
    · dsimp only
      split
      · exact hs
      · next next hm =>
        apply ih
        have hn : next.game.Reachable := .act _ hs (Session.move_game hm)
        -- Logging the reason and keeping the river spot do not change the game.
        exact ite_game_reachable hn hn

/-- Dealing a hand of a reachable game, then letting the bot play, gives a reachable game. -/
theorem Session.dealt_reachable (s : Session) (g : Game) (stacks : Player → Nat)
    (hg : g.Reachable) : (s.dealt g stacks).game.Reachable :=
  Session.runBot_reachable _ _ hg

/-- A new game the session accepts is reachable. -/
theorem Session.start_reachable {seed risk : Nat} {s' : Session}
    (hs : Session.start seed risk = .ok s') : s'.game.Reachable := by
  unfold Session.start at hs
  by_cases h1 : risk > 100 <;>
    simp [h1, throw, throwThe, MonadExceptOf.throw, bind, Except.bind, pure,
      Except.pure] at hs
  subst hs
  exact Session.dealt_reachable _ _ _ (.start seed)

/-- A human move the session accepts, followed by the bot's moves, keeps the game
reachable. -/
theorem Session.humanAct_reachable {s s' : Session} {a : Action} (hs : s.game.Reachable)
    (hok : s.humanAct a = .ok s') : s'.game.Reachable := by
  by_cases h1 : s.game.hand.ended.isSome = true
  · simp [Session.humanAct, h1, throw, throwThe, MonadExceptOf.throw, bind,
      Except.bind] at hok
  by_cases h2 : s.game.hand.chips.toAct ≠ human
  · simp [Session.humanAct, h1, h2, throw, throwThe, MonadExceptOf.throw, bind,
      Except.bind] at hok
  cases hm : s.move a with
  | error e =>
    simp [Session.humanAct, h1, h2, hm, bind, Except.bind] at hok
  | ok next =>
    have hn : next.game.Reachable := .act _ hs (Session.move_game hm)
    simp [Session.humanAct, h1, h2, hm, bind, Except.bind, pure, Except.pure] at hok
    subst hok
    exact Session.runBot_reachable _ _ hn

/-- **(b) Every command the session accepts keeps the game reachable.** If the session's
game is reachable (or there is no game yet), then after any command `Session.handle`
accepts, the new session's game is reachable. -/
theorem handle_keeps_reachable (cur : Option Session) (c : Command) (s' : Session)
    (hcur : ∀ s, cur = some s → s.game.Reachable)
    (hok : Session.handle cur c = .ok s') :
    s'.game.Reachable := by
  cases c with
  | newGame seed risk => exact Session.start_reachable hok
  | act a =>
    cases cur with
    | none => cases hok
    | some s => exact Session.humanAct_reachable (s := { s with events := #[] }) (hcur s rfl) hok
  | nextHand =>
    cases cur with
    | none => cases hok
    | some s =>
      cases hg : s.game.nextHand with
      | error e => simp [Session.handle, hg, bind, Except.bind] at hok
      | ok g =>
        simp [Session.handle, hg, bind, Except.bind, pure, Except.pure] at hok
        subst hok
        exact Session.dealt_reachable _ _ _ (.nextHand (hcur s rfl) hg)
  | state =>
    cases cur with
    | none => cases hok
    | some s =>
      cases hok
      exact hcur s rfl

/-! ## The removed fallback

`Session.runBot` used to test the bot's move first and, if the engine rejected it, play
`botMove` (check or call) instead. That code was removed. What the app does did not change:

- `Session.botChoice_accepted`: in a session whose game is reachable, the engine accepts the
  bot's move. So the old test always passed on such a session.
- `runBot` only runs on such sessions when the old session's game is reachable (or there is
  no game yet), which in the app is always true (`app_game_reachable` below).
  `Session.start` runs it on a new game, `next_hand` on a new hand of a reachable game, and
  `Session.humanAct` after a move the engine accepted in a reachable game (the proofs of
  `Session.start_reachable`, `handle_keeps_reachable` and `Session.humanAct_reachable`
  above). Each bot move keeps the game reachable (`Session.runBot_reachable`).
-/

/-! ## (a) A rejected command changes nothing -/

/-- **(a) A rejected command changes nothing.** If a request line holds a game command and
`Session.handle` rejects it, `respond` keeps the session exactly as it was, and replies with
the error and the table as it was before, with no new events. -/
theorem handle_error_unchanged (cur : Option Session) (line : String) (j : Json)
    (c : Command) (e : String) (peek : Bool) (commit : String)
    (hjson : Json.parse line = .ok j) (hreq : parseRequest j = .ok (.game c))
    (hpeek : parsePeek j = .ok peek)
    (hrej : Session.handle cur c = .error e) :
    respond cur line commit =
      (cur, Json.mkObj [("error", toJson e),
        ("state", match cur with
          | some s => stateJson { s with events := #[] } peek commit
          | none => Json.null)]) := by
  cases cur <;> simp only [respond, hjson, hpeek, hreq, hrej]

/-- `respond` changes the session only when `Session.handle` accepts a game command. Every
other line (bad JSON, an unknown command, a review, a rejected command) keeps it. -/
theorem respond_keeps_session_unless_accepted (cur : Option Session) (line : String) (commit : String) :
    (respond cur line commit).1 = cur ∨
    ∃ j c s, Json.parse line = .ok j ∧ parseRequest j = .ok (.game c) ∧
      Session.handle cur c = .ok s ∧ (respond cur line commit).1 = some s := by
  cases hj : Json.parse line with
  | error e => left; simp only [respond, hj]
  | ok j =>
    cases hp : parsePeek j with
    | error e => left; simp only [respond, hj, hp]
    | ok peek =>
      cases hr : parseRequest j with
      | error e => left; simp only [respond, hj, hp, hr]
      | ok r =>
        cases r with
        | review n =>
          left
          cases cur with
          | none => simp only [respond, hj, hp, hr]
          | some s => cases hv : s.review n <;> simp only [respond, hj, hp, hr, hv]
        | game c =>
          cases hh : Session.handle cur c with
          | error e => left; simp only [respond, hj, hp, hr, hh]
          | ok s => right; exact ⟨j, c, s, rfl, hr, hh, by simp only [respond, hj, hp, hr, hh]⟩

/-- One request line keeps the session's game reachable. -/
theorem respond_keeps_reachable (cur : Option Session) (line : String) (commit : String)
    (hcur : ∀ s, cur = some s → s.game.Reachable) :
    ∀ s, (respond cur line commit).1 = some s → s.game.Reachable := by
  intro s hs
  rcases respond_keeps_session_unless_accepted cur line commit with h | ⟨j, c, s', -, -, hh, h⟩
  · rw [h] at hs; exact hcur s hs
  · rw [h, Option.some.injEq] at hs
    subst hs
    exact handle_keeps_reachable cur c _ hcur hh

/-- **The game the app plays is reachable.** Start with no game and answer any request
lines in order, as `Main.lean` does: whenever there is a game, it is reachable. So T1
(`chips_always_1000`) and T2 (`no_card_dealt_twice`) hold for it. -/
theorem app_game_reachable (lines : List String) (s : Session) (commit : String)
    (hs : lines.foldl (fun cur line => (respond cur line commit).1) none = some s) :
    s.game.Reachable := by
  suffices key : ∀ (lines : List String) (init : Option Session),
      (∀ s, init = some s → s.game.Reachable) →
      ∀ s, lines.foldl (fun cur line => (respond cur line commit).1) init = some s → s.game.Reachable from
    key lines none (by simp) s hs
  intro lines
  induction lines with
  | nil => intro init hinit s hs; exact hinit s hs
  | cons line rest ih =>
    intro init hinit s hs
    exact ih _ (respond_keeps_reachable init line commit hinit) s hs

#print axioms bot_move_accepted
#print axioms Session.botChoice_accepted
#print axioms handle_keeps_reachable
#print axioms handle_error_unchanged
#print axioms app_game_reachable
