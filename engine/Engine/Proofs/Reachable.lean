import Engine.Hand

/-!
# Which hands and games can really happen

The main theorems talk about hands and games the engine can actually reach, starting
from a fresh deal. These two definitions say what "can reach" means. They are part of
what a reader must trust, so they are kept short.
-/

/-- A hand the engine can reach: a freshly dealt hand, or a hand after any number of
accepted moves. Any stacks, button and seed are allowed for the deal. -/
inductive Hand.Reachable : Hand → Prop
  /-- A freshly dealt hand. -/
  | deal (stacks : Player → Nat) (button : Player) (seed : Nat) :
      Hand.Reachable (startHand stacks button seed)
  /-- The hand after a move the engine accepted. -/
  | move {h h' : Hand} (a : Action) :
      Hand.Reachable h → step h a = .ok h' → Hand.Reachable h'

/-- A game the engine can reach: a new game (500 chips each), then any number of accepted
moves and new hands. -/
inductive Game.Reachable : Game → Prop
  /-- A new game, from any seed. -/
  | start (seed : Nat) : Game.Reachable (newGame seed)
  /-- The game after a move the engine accepted. -/
  | act {g g' : Game} (a : Action) : Game.Reachable g → g.act a = .ok g' → Game.Reachable g'
  /-- The game after the engine started the next hand. -/
  | nextHand {g g' : Game} : Game.Reachable g → g.nextHand = .ok g' → Game.Reachable g'

/-- The cards on the table: both players' hidden cards, then the shared cards. -/
def Hand.dealtCards (h : Hand) : List Card :=
  h.hole 0 ++ h.hole 1 ++ h.board

/-- Example: a new game is reachable. -/
example : Game.Reachable (newGame 7) := .start 7

-- A real move is accepted, so `Game.Reachable.act` applies to real games.
#guard match (newGame 7).act .call with
  | .ok g => g.handNo == 1
  | .error _ => false
