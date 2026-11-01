import Engine.Equity
import Engine.River

/-!
# Engine: the slider bot (MVP §5)

A port of `src/ai/slider/decide.ts` (`decideWithCounts`). The TypeScript stays as the
reference, and `Engine/SliderTests.lean` checks the two agree on many spots.

The player sets one slider, Risk (0 to 100: appetite for risk). `Sliders.ofRisk` turns it
into the two internal settings the bot reads: `risk`, how heavily a lost chip counts (call it
caution: 0 is plain chip profit, 100 counts a lost chip three times), and `bluffPct`, the
bluff share of the river betting set (0 to 60%). The bot looks at its own two cards, the
board and the chips. It never sees the other player's cards.

- Facing a bet: raise pot-sized if its win chance is at least 75% and a raise is legal.
  Otherwise call if `callPays` at its Risk. Otherwise fold.
- No bet to face, before the river: bet pot-sized if its win chance is at least 65% and a
  bet is legal. Otherwise check.
- No bet to face, on the river: bet pot-sized if its hand is in the river betting set
  (`riverRole`, `Engine/River.lean`). Otherwise check.

All math is in whole numbers. Bet and raise sizes are kept inside the legal amounts.
-/

/-- The bot's two internal settings. `risk` (caution) is 0 to 100; `bluffPct` is a
percentage from 0 to 60. The app sets both from the one Risk slider with `Sliders.ofRisk`. -/
structure Sliders where
  risk : Nat
  bluffPct : Nat
  deriving Repr, BEq, DecidableEq

/-- The one slider the player sees, turned into the bot's two internal settings. Risk 0 is
the rock: it counts a lost chip three times (`risk` 100) and never bluffs. Risk 50 is the
textbook setting: plain chip profit (`risk` 0), and bluffs are 33% of its river bets, the
break-even share against a pot-sized bet. Risk 100 is the maniac: still plain chip profit,
and bluffs are 60% of its river bets. In between, both numbers move in a straight line,
rounded to the nearest whole number. A value above 100 counts as 100. -/
def Sliders.ofRisk (r : Nat) : Sliders :=
  let r := min r 100
  if r ≤ 50 then ⟨100 - 2 * r, (33 * r + 25) / 50⟩
  else ⟨0, 33 + (27 * (r - 50) + 25) / 50⟩

#guard Sliders.ofRisk 0 == ⟨100, 0⟩
#guard Sliders.ofRisk 25 == ⟨50, 17⟩
#guard Sliders.ofRisk 50 == ⟨0, 33⟩
#guard Sliders.ofRisk 75 == ⟨0, 47⟩
#guard Sliders.ofRisk 100 == ⟨0, 60⟩
#guard Sliders.ofRisk 250 == ⟨0, 60⟩

/-- A move as short text: `fold`, `check`, `call` or `raise 40` (raise to 40 this round). -/
def Action.text : Action → String
  | .fold => "fold"
  | .check => "check"
  | .call => "call"
  | .raiseTo n => s!"raise {n}"

/-- The move stays in the hand and puts chips in: a call or a raise. -/
def Action.continues : Action → Bool
  | .call | .raiseTo _ => true
  | .fold | .check => false

/-- The bot's move and one plain sentence saying why, to show after the hand. -/
structure BotChoice where
  action : Action
  reason : String

/-- Facing a bet, the bot raises when its win chance (ties counting half) is at least this,
in percent. -/
def raiseAtPercent : Nat := 75

/-- With no bet to face, before the river, the bot bets the pot when its win chance is at
least this, in percent. -/
def betAtPercent : Nat := 65

/-! ## Win chance and the call rule -/

/-- True when the win chance, with ties counting half, is at least `percent`%. -/
def Counts.atLeast (c : Counts) (percent : Nat) : Bool :=
  2 * percent * c.total ≤ 100 * (2 * c.win + c.tie)

/-- The win chance in percent, ties counting half, rounded half up. Only for the reason
text; decisions use `Counts.atLeast`. 0 when there are no outcomes. -/
def Counts.percent (c : Counts) : Nat :=
  (200 * (2 * c.win + c.tie) + 2 * c.total) / (4 * c.total)

example : Counts.percent ⟨1, 0, 2⟩ = 33 := by decide
example : Counts.percent ⟨1, 1, 2⟩ = 38 := by decide

/-- Is calling `toCall` chips to win a pot of `pot` worth it at this Risk? A call wins
`pot`, loses `toCall`, or on a split gains half of `pot - toCall`. Each lost chip counts
`1 + risk / 50` times as much as a won chip. Times 200, in whole numbers:

  100 × (2 × win × pot + tie × (pot − toCall)) ≥ 2 × (100 + 2 × risk) × loss × toCall

At Risk 0 this is plain chip profit. A higher Risk only makes the right side bigger. -/
def callPays (c : Counts) (pot toCall risk : Nat) : Bool :=
  2 * (100 + 2 * risk) * c.loss * toCall ≤ 100 * (2 * c.win * pot + c.tie * (pot - toCall))

-- Against a pot-sized bet (pot 200, call 100) the bot needs 1/3 wins at Risk 0 and 1/2 at
-- Risk 50 (these match `decide.test.ts`).
example : callPays ⟨1, 0, 2⟩ 200 100 0 = true := by decide
example : callPays ⟨1, 0, 2⟩ 200 100 1 = false := by decide
example : callPays ⟨1, 0, 1⟩ 200 100 50 = true := by decide
example : callPays ⟨1, 0, 1⟩ 200 100 51 = false := by decide

/-! ## What the bot sees -/

/-- What the bot looks at, as in `SliderView` in `decide.ts`. -/
structure View where
  /-- The bot's two cards. -/
  hole : List Card
  /-- 0, 3, 4 or 5 cards. -/
  board : List Card
  /-- The chips the bot can win if it calls or checks now: earlier streets plus both
  bets on this street, leaving out any part of the other bet the bot cannot match. -/
  pot : Nat
  /-- Chips the bot must add to call, or 0 with no bet to face. -/
  toCall : Nat
  /-- Chips the bot has already put in on this street. -/
  streetBet : Nat
  /-- The smallest and largest legal raise, as street totals, or `none` if the bot may
  not bet or raise. -/
  raise : Option (Nat × Nat)
  /-- The bot's two internal settings. -/
  sliders : Sliders
  /-- The Risk to quote in the bot's reasons: in the app, the Risk the player set (0 to
  100). `none` quotes the internal `risk`. The decision never reads this field
  (`botDecide_action_shown`). -/
  shownRisk : Option Nat := none

/-- The bot's chips in on this street plus all its chips behind: its all-in street total. -/
def State.allIn (s : State) : Nat := s.bet s.toAct + s.stack s.toAct

/-- The legal raises, as street totals: from a full raise (or all-in, if that is less) up
to all-in. `none` when no raise is legal. The same bounds as the screen's raise slider. -/
def State.raiseBounds (s : State) : Option (Nat × Nat) :=
  if Legal s (.raiseTo s.allIn) then
    some (min (s.bet (other s.toAct) + s.minRaise) s.allIn, s.allIn)
  else none

/-- The pot the bot can win now: earlier streets, its own bet, and the other bet up to
what the bot can match. -/
def State.potToWin (s : State) : Nat :=
  s.pot + s.bet s.toAct + min (s.bet (other s.toAct)) (s.bet s.toAct + s.toCall)

/-- The bot's view of state `s`, as `sliderView` in `fromHand.ts` builds it. `shown` is the
Risk to quote in the bot's reasons: in the app, the value the player set. -/
def viewOf (sl : Sliders) (hole board : List Card) (s : State) (shown : Option Nat := none) :
    View :=
  { hole, board, pot := s.potToWin, toCall := s.toCall, streetBet := s.bet s.toAct,
    raise := s.raiseBounds, sliders := sl, shownRisk := shown }

/-! ## The decision -/

/-- Keep `target` inside `lo .. hi`. -/
def clampTo (target lo hi : Nat) : Nat := min hi (max lo target)

/-- A pot-sized raise, as a street total: the bot's chips in so far, plus the call, plus
the pot after calling. -/
def View.potRaiseTarget (v : View) : Nat := v.streetBet + v.toCall + (v.pot + v.toCall)

/-- A pot-sized bet, as a street total: the bot's chips in so far plus the pot. -/
def View.potBetTarget (v : View) : Nat := v.streetBet + v.pot

/-- "win chance 62%", with a note on the flop that it is an estimate. -/
def chanceText (v : View) (c : Counts) : String :=
  s!"win chance {c.percent}%" ++
    if v.board.length = 3 then s!" (estimated from {flopSamples} deals)" else ""

/-- "Bet 40" with no chips in yet on this street, otherwise "Raise to 40". -/
def betVerb (v : View) (to : Nat) : String :=
  if v.streetBet > 0 then s!"Raise to {to}" else s!"Bet {to}"

/-- Bet pot-sized with a hand from the river betting set, kept inside the legal sizes. Check
if no bet is legal. `role` is "value" or "bluff"; `why` says why the hand is in the set. -/
def riverBetOrCheck (v : View) (role why : String) : BotChoice :=
  match v.raise with
  | some (lo, hi) =>
    let to := clampTo v.potBetTarget lo hi
    ⟨.raiseTo to, s!"{betVerb v to}: {why}."⟩
  | none => ⟨.check, s!"Check: a {role} hand, but no bet is allowed."⟩

/-- The river with no bet to face, as `riverOpeningFromSet` in `decide.ts`: bet pot-sized
with a hand from the river betting set (`riverRole`, a value hand or a bluff), otherwise
check. -/
def riverOpening (v : View) : BotChoice :=
  match riverRole v.sliders.bluffPct v.board v.hole with
  | .value => riverBetOrCheck v "value" "a value hand, among the strongest 30% on this board"
  | .bluff => riverBetOrCheck v "bluff" s!"a bluff, picked at Bluff {v.sliders.bluffPct}%"
  | .check => ⟨.check, "Check: this hand is not in the river betting set."⟩

/-- The bot's move for given counts, as `decideWithCounts` in `decide.ts` (MVP §5). -/
def decideView (v : View) (c : Counts) : BotChoice :=
  let chance := chanceText v c
  if v.toCall > 0 then
    match v.raise with
    | some (lo, hi) =>
      if c.atLeast raiseAtPercent then
        let to := clampTo v.potRaiseTarget lo hi
        ⟨.raiseTo to, s!"Raise to {to}: {chance} is at least {raiseAtPercent}%."⟩
      else callOrFold chance
    | none => callOrFold chance
  else if v.board.length = 5 then riverOpening v
  else
    match v.raise with
    | some (lo, hi) =>
      if c.atLeast betAtPercent then
        let to := clampTo v.potBetTarget lo hi
        ⟨.raiseTo to, s!"{betVerb v to}: {chance} is at least {betAtPercent}%."⟩
      else checkMove chance
    | none => checkMove chance
where
  callOrFold (chance : String) : BotChoice :=
    let odds := s!"calling {v.toCall} to win {v.pot} at Risk {v.shownRisk.getD v.sliders.risk}, with {chance}"
    if callPays c v.pot v.toCall v.sliders.risk then ⟨.call, s!"Call: worth {odds}."⟩
    else ⟨.fold, s!"Fold: not worth {odds}."⟩
  checkMove (chance : String) : BotChoice :=
    ⟨.check, s!"Check: {chance} is under {betAtPercent}%."⟩

/-- The bot's move in state `s` for given counts. `shown` is the Risk quoted in the reason. -/
def decideWithCounts (sl : Sliders) (c : Counts) (hole board : List Card) (s : State)
    (shown : Option Nat := none) : BotChoice :=
  decideView (viewOf sl hole board s shown) c

/-- **The slider bot.** It works out its counts (`countsFor`, which does not look at the
sliders), then decides. The same inputs always give the same move. `shown` is the Risk the
player set, quoted in the reason; the move does not depend on it (`botDecide_action_shown`). -/
def botDecide (sl : Sliders) (seed : Nat) (hole board : List Card) (s : State)
    (shown : Option Nat := none) : BotChoice :=
  decideWithCounts sl (countsFor seed hole board) hole board s shown

/-! ## Examples

Spots from `decide.test.ts`: a flop with 100 in the pot from earlier, the other player bets
50, so the pot to win is 150 and the call is 50. A raise may go from 100 to 450. -/

/-- The flop spot above, at Risk 50 and Bluff 33%. -/
def exFlopView : View :=
  { hole := [], board := [⟨12, .spades⟩, ⟨11, .diamonds⟩, ⟨0, .clubs⟩],
    pot := 150, toCall := 50, streetBet := 0, raise := some (100, 450), sliders := ⟨50, 33⟩ }

-- 80% wins: raise pot-sized, to 50 (call) + 200 (pot after calling) = 250.
#guard (decideView exFlopView ⟨80, 0, 20⟩).action.text == "raise 250"
#guard (decideView exFlopView ⟨80, 0, 20⟩).reason ==
  "Raise to 250: win chance 80% (estimated from 1000 deals) is at least 75%."
-- The same raise when at most 200 is legal is cut down to 200.
#guard (decideView { exFlopView with raise := some (100, 200) } ⟨80, 0, 20⟩).action.text == "raise 200"
-- 40% wins: calling 50 to win 150 pays at Risk 0 and 50, but not at Risk 100.
#guard (decideView { exFlopView with sliders := ⟨0, 33⟩ } ⟨40, 0, 60⟩).action.text == "call"
#guard (decideView exFlopView ⟨40, 0, 60⟩).action.text == "call"
#guard (decideView { exFlopView with sliders := ⟨100, 33⟩ } ⟨40, 0, 60⟩).action.text == "fold"
#guard (decideView { exFlopView with sliders := ⟨100, 33⟩ } ⟨40, 0, 60⟩).reason ==
  "Fold: not worth calling 50 to win 150 at Risk 100, with win chance 40% (estimated from 1000 deals)."
-- In the app the reason quotes the Risk the player set: Risk 0 is the internal pair (100, 0).
#guard (decideView { exFlopView with sliders := Sliders.ofRisk 0, shownRisk := some 0 } ⟨40, 0, 60⟩).reason ==
  "Fold: not worth calling 50 to win 150 at Risk 0, with win chance 40% (estimated from 1000 deals)."
#guard (decideView { exFlopView with sliders := Sliders.ofRisk 100, shownRisk := some 100 } ⟨40, 0, 60⟩).reason ==
  "Call: worth calling 50 to win 150 at Risk 100, with win chance 40% (estimated from 1000 deals)."
-- No bet to face: bet the pot with 70% wins, check with 60%.
#guard (decideView { exFlopView with pot := 100, toCall := 0, raise := some (10, 400) } ⟨70, 0, 30⟩).action.text == "raise 100"
#guard (decideView { exFlopView with pot := 100, toCall := 0, raise := some (10, 400) } ⟨60, 0, 40⟩).action.text == "check"
/-- The river with no bet to face, on a board of A K 2 5 7 with 100 in the pot. The river
betting set decides. -/
def exRiverView (hole : List Card) : View :=
  { exFlopView with
    hole
    board := [⟨12, .spades⟩, ⟨11, .diamonds⟩, ⟨0, .clubs⟩, ⟨3, .hearts⟩, ⟨5, .hearts⟩]
    pot := 100, toCall := 0, raise := some (10, 400) }

-- Two aces are a value hand: bet the pot.
#guard (decideView (exRiverView [⟨12, .clubs⟩, ⟨12, .hearts⟩]) ⟨99, 0, 1⟩).reason ==
  "Bet 100: a value hand, among the strongest 30% on this board."
-- Eight-six is picked as a bluff at Bluff 33%.
#guard (decideView (exRiverView [⟨6, .clubs⟩, ⟨4, .diamonds⟩]) ⟨0, 0, 1⟩).reason ==
  "Bet 100: a bluff, picked at Bluff 33%."
-- A pair of sevens is in neither set: check, whatever the counts say.
#guard (decideView (exRiverView [⟨5, .clubs⟩, ⟨1, .diamonds⟩]) ⟨99, 0, 1⟩).reason ==
  "Check: this hand is not in the river betting set."

-- The start of a hand: the small blind owes 5, so the pot to win is 15 and a pot-sized
-- raise goes to 5 + 5 + 20 = 30. A raise may go from 20 to 500.
#guard (viewOf ⟨50, 20⟩ [] [] exStart).pot == 15
#guard (viewOf ⟨50, 20⟩ [] [] exStart).raise == some (20, 500)
#guard (decideWithCounts ⟨50, 20⟩ ⟨80, 0, 20⟩ [] [] exStart).action.text == "raise 30"
-- With 40% wins, calling 5 to win 15 pays at Risk 100 (plain chip profit) but not at Risk 0.
#guard (decideWithCounts (Sliders.ofRisk 0) ⟨40, 0, 60⟩ [] [] exStart (some 0)).reason ==
  "Fold: not worth calling 5 to win 15 at Risk 0, with win chance 40%."
#guard (decideWithCounts (Sliders.ofRisk 100) ⟨40, 0, 60⟩ [] [] exStart (some 100)).action.text == "call"
-- After a short all-in the bot may not re-raise, so with a strong hand it calls.
#guard (decideWithCounts ⟨50, 20⟩ ⟨99, 0, 1⟩ [] [] exShortAllIn).action.text == "call"
