import Engine.Equity

/-!
# Engine: the slider bot

The bot has two sliders, Risk (0 to 100) and Bluff (0% to 60%), and plays by the rules in
MVP §5. Ported from the TypeScript reference `src/ai/slider/decide.ts`.

The bot's move is split in two steps, so the proofs can use each one:
`botDecide` = `countsFor` (how often the hand wins) + `decideWithCounts` (what to do with that).

STUB (step 0): `decideWithCounts` checks when nothing is owed and otherwise calls.
-/

/-- The two sliders. `risk` is 0 to 100; `bluffPct` is a percentage from 0 to 60. -/
structure Sliders where
  risk : Nat
  bluffPct : Nat
  deriving Repr, BEq, DecidableEq

/-- The bot's move, and one plain sentence saying why, to show after the hand. -/
structure BotChoice where
  action : Action
  reason : String

/-- The bot's move for given win/tie/loss counts, in betting state `s`.

STUB: check when nothing is owed, otherwise call. -/
def decideWithCounts (_sl : Sliders) (_counts : Counts) (_hole _board : List Card) (s : State) :
    BotChoice :=
  if s.toCall = 0 then ⟨.check, "Check: nothing to call."⟩ else ⟨.call, "Call."⟩

/-- The bot's move: count how often its hand wins, then decide. `seed` drives the flop's
random deals; the same inputs always give the same move. -/
def botDecide (sl : Sliders) (seed : Nat) (hole board : List Card) (s : State) : BotChoice :=
  decideWithCounts sl (countsFor seed hole board) hole board s

#guard match (botDecide ⟨50, 20⟩ 7 [] [] exStart).action with | .call => true | _ => false
#guard match (botDecide ⟨50, 20⟩ 7 [] [] { exStart with bet := fun _ => 10 }).action with
  | .check => true | _ => false
