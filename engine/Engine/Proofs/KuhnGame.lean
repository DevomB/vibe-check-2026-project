import Engine.KuhnGame

/-!
# The playable Kuhn game does what the theory says

`Engine/KuhnGame.lean` is the game a person plays. `Engine/Proofs/Kuhn.lean` proved the bot's
strategies are a Nash equilibrium, about the strategies on paper. These theorems connect the
two:

- **Fair deal** (`kDeal_each_once`): the six random numbers 0 to 5 give the six deals, each
  exactly once.
- **The bot rolls the right odds** (`botP1_frequencies`, `botP2_frequencies`): of its three
  equally likely random numbers, the bot takes each choice exactly as many times as its
  equilibrium strategy says (for example, it bluffs a jack for exactly one of the three).
- **The bot only makes legal moves** (`botP1_legal`, `botP2_legal`).
- **The game matches the theory** (`botP1Total_eq`, `botP2Total_eq`): against any way a person
  plays, the game's average result, over every deal and every bot roll, is exactly what the
  theory's payoff formula gives.
- **So the bot can't be beaten** (`kuhn_game_bot_p1`, `kuhn_game_bot_p2`,
  `kuhn_game_unbeatable`, and the `_mix` versions for players who mix their choices at
  random): no way of playing wins chips from the bot on average.
-/

/-! ## The deal and the bot's rolls -/

/-- **Fair deal.** The random numbers 0 to 5 give the six possible deals, each exactly once. So
if the random number is fair, every deal is equally likely. -/
theorem kDeal_each_once : (List.range 6).map kDeal = kuhnDeals := by decide

/-- **The bot as player 1 rolls the right odds.** For every card, out of the three equally
likely rolls, the bot bets, checks then calls, and checks then folds exactly as many times as
its equilibrium weights say. -/
theorem botP1_frequencies (c : KCard) :
    (botRolls.filter (botP1Line c · = .bet)).length = (p1Equilibrium c).bet ∧
    (botRolls.filter (botP1Line c · = .checkCall)).length = (p1Equilibrium c).checkCall ∧
    (botRolls.filter (botP1Line c · = .checkFold)).length = (p1Equilibrium c).checkFold := by
  cases c <;> decide

/-- **The bot as player 2 rolls the right odds.** For every card, out of the three rolls, it
bets after a check and calls a bet exactly as many times as its equilibrium weights say. -/
theorem botP2_frequencies (c : KCard) :
    (botRolls.filter (botP2Move c · [.check] = .bet)).length = (p2Equilibrium c).bet ∧
    (botRolls.filter (botP2Move c · [.bet] = .call)).length = (p2Equilibrium c).call := by
  cases c <;> decide

/-- Player 1 is to act only at the start, or after "check, bet". -/
theorem kToAct_zero {moves : List KMove} (h : kToAct moves = some 0) :
    moves = [] ∨ moves = [.check, .bet] := by
  unfold kToAct at h
  split at h <;> simp_all

/-- Player 2 is to act only after "check" or after "bet". -/
theorem kToAct_one {moves : List KMove} (h : kToAct moves = some 1) :
    moves = [.check] ∨ moves = [.bet] := by
  unfold kToAct at h
  split at h <;> simp_all

/-- **The bot as player 1 only makes legal moves**, whatever its card and roll, whenever it is
player 1's turn. -/
theorem botP1_legal (c : KCard) (r : Nat) (moves : List KMove) (hturn : kToAct moves = some 0) :
    (botP1Line c r).move moves ∈ kLegal moves := by
  rcases kToAct_zero hturn with rfl | rfl <;> cases botP1Line c r <;> decide

/-- **The bot as player 2 only makes legal moves**, whatever its card and roll, whenever it is
player 2's turn. -/
theorem botP2_legal (c : KCard) (r : Nat) (moves : List KMove) (hturn : kToAct moves = some 1) :
    botP2Move c r moves ∈ kLegal moves := by
  rcases kToAct_one hturn with rfl | rfl <;> simp only [botP2Move] <;> split <;> decide

/-! ## The game follows the rules -/

/-- A sequence of moves the game has accepted, one move at a time from the start. -/
inductive KAccepted : List KMove → Prop
  | start : KAccepted []
  | move {ms ms' : List KMove} (m : KMove) : KAccepted ms → kStep ms m = .ok ms' → KAccepted ms'

/-- The beginnings of the five endings: every way a hand can stand part-way through. -/
def kuhnStages : List (List KMove) :=
  [[], [.check], [.bet], [.check, .bet]] ++ kuhnEndings

/-- From every stage, each of the four moves is either rejected or leads to another stage
(checked for every stage and every move). -/
theorem kStep_stays_all : ∀ ms ∈ kuhnStages, ∀ m ∈ [KMove.check, .bet, .call, .fold],
    (match kStep ms m with
     | .ok ms' => decide (ms' ∈ kuhnStages)
     | .error _ => true) = true := by
  decide

theorem kStep_stays_in_stages (ms : List KMove) (hms : ms ∈ kuhnStages) (m : KMove)
    (hm : m ∈ [KMove.check, .bet, .call, .fold]) (ms' : List KMove)
    (hs : kStep ms m = .ok ms') : ms' ∈ kuhnStages := by
  have := kStep_stays_all ms hms m hm
  rw [hs] at this
  simpa using this

/-- At every stage, the hand is over exactly at the five endings. -/
theorem stages_over_iff : ∀ ms ∈ kuhnStages, (kToAct ms = none ↔ ms ∈ kuhnEndings) := by
  decide

theorem accepted_in_stages {ms : List KMove} (h : KAccepted ms) : ms ∈ kuhnStages := by
  induction h with
  | start => decide
  | move m _ hs ih =>
    exact kStep_stays_in_stages _ ih m (by cases m <;> decide) _ hs

/-- **The game follows the rules.** Every sequence of moves the game accepts is part of one
of the five ways a hand can end (`kuhnEndings`), and the hand is over (nobody is asked to
move) exactly when it has reached one of them. So no move outside the rules is possible, and
no hand stops part-way. -/
theorem kuhn_game_follows_rules {ms : List KMove} (h : KAccepted ms) :
    ms ∈ kuhnStages ∧ (kToAct ms = none ↔ ms ∈ kuhnEndings) := by
  have hs := accepted_in_stages h
  exact ⟨hs, stages_over_iff ms hs⟩

/-- Every ending can really happen: the game accepts each of the five. -/
example : KAccepted [.check, .bet, .call] :=
  .move .call (.move .bet (.move .check .start rfl) rfl) rfl

/-- The statement rejects a game that lets player 2 re-raise: "bet, bet" is not one of the
stages the rules allow. -/
example : [KMove.bet, .bet] ∉ kuhnStages := by decide

/-! ## The game matches the theory

A human strategy is a function on the three cards; to check every one, we list them by their
choices (64 for player 2, 27 for player 1) and let Lean check each. -/

/-- A player 2 strategy from its six choices. -/
def mkP2 (a b c d e f : Bool) : HumanP2
  | .jack => ⟨a, b⟩ | .queen => ⟨c, d⟩ | .king => ⟨e, f⟩

theorem mkP2_eq (h : HumanP2) :
    h = mkP2 (h .jack).1 (h .jack).2 (h .queen).1 (h .queen).2 (h .king).1 (h .king).2 := by
  funext c; cases c <;> rfl

theorem botP1Total_eq_all : ∀ a b c d e f : Bool,
    botP1Total (mkP2 a b c d e f) = kuhnPayoff p1Equilibrium (mkP2 a b c d e f).weights := by
  decide

/-- **The game matches the theory (bot as player 1).** Against any human player 2, the game's
total result over every deal and bot roll equals the theory's payoff for the bot's
equilibrium strategy against that human's choices. -/
theorem botP1Total_eq (h : HumanP2) : botP1Total h = kuhnPayoff p1Equilibrium h.weights := by
  rw [mkP2_eq h]; exact botP1Total_eq_all _ _ _ _ _ _

/-- A player 1 line from a number 0, 1 or 2. -/
def lineOf (n : Fin 3) : P1Line :=
  match n with | 0 => .bet | 1 => .checkCall | 2 => .checkFold

def P1Line.index : P1Line → Fin 3
  | .bet => 0 | .checkCall => 1 | .checkFold => 2

theorem lineOf_index (l : P1Line) : lineOf l.index = l := by cases l <;> rfl

/-- A player 1 strategy from its three choices. -/
def mkP1 (a b c : Fin 3) : HumanP1
  | .jack => lineOf a | .queen => lineOf b | .king => lineOf c

theorem mkP1_eq (h : HumanP1) : h = mkP1 (h .jack).index (h .queen).index (h .king).index := by
  funext c; cases c <;> simp [mkP1, lineOf_index]

theorem botP2Total_eq_all : ∀ a b c : Fin 3,
    botP2Total (mkP1 a b c) = kuhnPayoff (mkP1 a b c).weights p2Equilibrium := by
  decide

/-- **The game matches the theory (bot as player 2).** Against any human player 1, the game's
total result over every deal and bot roll equals the theory's payoff for that human's choices
against the bot's equilibrium strategy. -/
theorem botP2Total_eq (h : HumanP1) : botP2Total h = kuhnPayoff h.weights p2Equilibrium := by
  rw [mkP1_eq h]; exact botP2Total_eq_all _ _ _

/-! ## So the bot can't be beaten -/

theorem HumanP2.weights_valid (h : HumanP2) : h.weights.Valid 1 := by
  intro c
  simp only [HumanP2.weights]
  constructor <;> split <;> rfl

theorem HumanP1.weights_valid (h : HumanP1) : h.weights.Valid 1 := by
  intro c
  simp only [HumanP1.weights]
  split <;> rfl

/-- **The bot as player 1 can't be beaten.** Against any human player 2, player 1's total over
the 18 equally likely deals and rolls is at least −1: the bot averages at least −1/18 of a chip
per hand, the value of the game. -/
theorem kuhn_game_bot_p1 (h : HumanP2) : -1 ≤ botP1Total h := by
  rw [botP1Total_eq]
  exact kuhn_bot_as_player1 1 h.weights h.weights_valid

/-- **The bot as player 2 can't be beaten.** Against any human player 1, player 1's total over
the 18 equally likely deals and rolls is at most −1: the human averages at most −1/18 of a chip
per hand. -/
theorem kuhn_game_bot_p2 (h : HumanP1) : botP2Total h ≤ -1 := by
  rw [botP2Total_eq]
  exact kuhn_bot_as_player2 1 h.weights h.weights_valid

/-- **Nobody beats the bot.** Play one hand in each seat against the bot, with any choices:
your winnings, on average, are at most 0. (As player 1 you win `botP2Total h1`; as player 2 you
win what player 1 loses, `-botP1Total h2`.) -/
theorem kuhn_game_unbeatable (h1 : HumanP1) (h2 : HumanP2) :
    botP2Total h1 + -botP1Total h2 ≤ 0 := by
  have := kuhn_game_bot_p1 h2
  have := kuhn_game_bot_p2 h1
  omega

/-! ## Players who mix their choices at random

A person may choose at random between ways of playing: this way 2 times in 5, that way 3 times
in 5. Such a mix is a list of ways of playing, each with a weight. Its average result is the
weighted average of theirs, so it can't beat the bot either. -/

/-- **Mixing doesn't help against the bot as player 1.** For any mix of human player 2
strategies with whole-number weights, the weighted total is at least −1 times the total
weight: the bot still averages at least −1/18 per hand. -/
theorem kuhn_game_bot_p1_mix (mix : List (HumanP2 × Nat)) :
    -((mix.map (·.2)).sum : Int) ≤ (mix.map fun (h, w) => (w : Int) * botP1Total h).sum := by
  induction mix with
  | nil => simp
  | cons hw rest ih =>
    obtain ⟨h, w⟩ := hw
    have := kuhn_game_bot_p1 h
    have hw : -(w : Int) ≤ (w : Int) * botP1Total h := by
      have := Int.mul_le_mul_of_nonneg_left this (Int.natCast_nonneg w)
      omega
    simp only [List.map_cons, List.sum_cons] at *
    omega

/-- **Mixing doesn't help against the bot as player 2.** For any mix of human player 1
strategies, the weighted total is at most −1 times the total weight. -/
theorem kuhn_game_bot_p2_mix (mix : List (HumanP1 × Nat)) :
    (mix.map fun (h, w) => (w : Int) * botP2Total h).sum ≤ -((mix.map (·.2)).sum : Int) := by
  induction mix with
  | nil => simp
  | cons hw rest ih =>
    obtain ⟨h, w⟩ := hw
    have := kuhn_game_bot_p2 h
    have hw : (w : Int) * botP2Total h ≤ -(w : Int) := by
      have := Int.mul_le_mul_of_nonneg_left this (Int.natCast_nonneg w)
      omega
    simp only [List.map_cons, List.sum_cons] at *
    omega

/-! ## Checks -/

-- A real hand: the bot (player 1) holds the king and its roll is 0, so it bets; a human with
-- the queen who always calls loses 2.
#guard kResult .king .queen (kHand ((botP1Line .king 0).move) ((mkP2 false true false true false true .queen).move)) == -2 * -1

-- The theorems apply to a real way of playing: a human player 2 who always calls and never
-- bluffs. The game's total is 4 (the bot averages +4/18 = +2/9 per hand), at least −1.
example : -1 ≤ botP1Total (fun _ => ⟨false, true⟩) := kuhn_game_bot_p1 _
#guard botP1Total (fun _ => ⟨false, true⟩) == 4

-- A human player 1 who always bets loses 2/18 = 1/9 of a chip per hand to the bot.
#guard botP2Total (fun _ => .bet) == -2

/-- The statements reject a bot that rolls the wrong odds: a bot that bluffed a jack two times
in three would bluff 2 times out of 3 rolls, not the 1 its strategy says. -/
example : ((botRolls.filter (fun r => r % 3 < 2)).length) ≠ (p1Equilibrium .jack).bet := by decide

/-- The statements reject an illegal bot move: calling when nothing has been bet. -/
example : KMove.call ∉ kLegal [] := by decide

#print axioms kuhn_game_follows_rules
#print axioms kDeal_each_once
#print axioms botP1_frequencies
#print axioms botP1Total_eq
#print axioms botP2Total_eq
#print axioms kuhn_game_unbeatable
#print axioms kuhn_game_bot_p1_mix
#print axioms kuhn_game_bot_p2_mix
