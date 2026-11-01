import Engine.Proofs.Chips
import Engine.Proofs.EndsSpec

/-!
# The right player wins the pot

T1 (`Engine/Proofs/Chips.lean`) shows chips are never created or destroyed. That alone
does not say *who* gets them: paying the pot to the loser also keeps the total. These
theorems close that gap.

For a hand dealt from stacks `S` (both above 0) and played with any accepted moves:

- **Showdown** (`showdown_pays_better_hand`): the recorded result is the spec's `showdown`
  on the players' real cards and board. The winner ends the hand with more chips than they
  started it with, and the loser with fewer. On a tie both end with exactly what they
  started with.
- **Fold** (`fold_pays_other_player`, `fold_records_other_player`): folding records the
  other player as the winner, and that player ends with more chips than they started with,
  while the player who folded ends with fewer.

## How the proof works

While a hand is being played, one fact holds for each player `p` (`PaidIn`):

    chips p still holds + chips p bet this round + half the pot = chips p started with

and the pot is even, and each player has put in at least one chip (they posted a blind).
Every part of the engine keeps this fact. At the end, it fixes the payout: at a showdown
both players have put in half the pot each, so the winner gains that half and the loser
loses it.
-/

/-! ## The fact that holds during a hand -/

/-- During a hand dealt from stacks `S`: each player's stack, bet and half of the pot add up
to what they started with; the pot is even; and each player has put in at least one chip. -/
def PaidIn (S : Player → Nat) (s : State) : Prop :=
  s.stack 0 + s.bet 0 + s.pot / 2 = S 0 ∧
  s.stack 1 + s.bet 1 + s.pot / 2 = S 1 ∧
  s.pot % 2 = 0 ∧
  0 < s.bet 0 + s.pot / 2 ∧
  0 < s.bet 1 + s.pot / 2

/-- What a finished hand must satisfy: the right player was paid. -/
def EndPaid (S : Player → Nat) (h : Hand) : Prop :=
  (∀ r, h.ended = some (.showdown r) →
    r = showdown (h.hole 0) (h.hole 1) h.board ∧
    (r = .player0 → S 0 < h.chips.stack 0 ∧ h.chips.stack 1 < S 1) ∧
    (r = .player1 → S 1 < h.chips.stack 1 ∧ h.chips.stack 0 < S 0) ∧
    (r = .tie → h.chips.stack 0 = S 0 ∧ h.chips.stack 1 = S 1)) ∧
  (∀ w, h.ended = some (.folded w) →
    S w < h.chips.stack w ∧ h.chips.stack (other w) < S (other w))

/-- A hand is on track: while it is played the fact `PaidIn` holds, and once it is over the
right player was paid. -/
def PayoutOk (S : Player → Nat) (h : Hand) : Prop :=
  (h.ended = none → PaidIn S h.chips) ∧ EndPaid S h

/-- A hand that is not over is on track as soon as `PaidIn` holds. -/
theorem payoutOk_of_paidIn {S : Player → Nat} {h : Hand} (hn : h.ended = none)
    (hp : PaidIn S h.chips) : PayoutOk S h :=
  ⟨fun _ => hp, fun r he => by simp [hn] at he, fun w he => by simp [hn] at he⟩

/-! ## Each part of the engine keeps the fact -/

/-- Every player is player 0 or player 1. -/
theorem player_cases (p : Player) : p = 0 ∨ p = 1 := by
  match p with
  | ⟨0, _⟩ => exact .inl rfl
  | ⟨1, _⟩ => exact .inr rfl

/-- A legal check, call or raise only moves chips from the mover's stack to their bet. -/
theorem applyMove_paidIn {S : Player → Nat} (s : State) (a : Action) (hl : Legal s a)
    (hp : PaidIn S s) : PaidIn S (applyMove s a) := by
  unfold PaidIn at *
  cases a with
  | fold => exact hp
  | check => exact hp
  | call =>
    have hle : min s.toCall (s.stack s.toAct) ≤ s.stack s.toAct := Nat.min_le_right _ _
    simp only [applyMove]
    rcases player_cases s.toAct with ht | ht <;> rw [ht] at hle ⊢ <;> simp [setFor] <;> omega
  | raiseTo n =>
    have hpay : n - s.bet s.toAct ≤ s.stack s.toAct := by
      simp only [Legal] at hl; exact hl.2.2.2.1
    simp only [applyMove]
    rcases player_cases s.toAct with ht | ht <;> rw [ht] at hpay ⊢ <;> simp [setFor] <;> omega

/-- Giving back the unmatched part of a bet keeps the fact, and leaves both bets equal. -/
theorem returnUncalled_paidIn {S : Player → Nat} (s : State) (hp : PaidIn S s) :
    PaidIn S (returnUncalled s) ∧ (returnUncalled s).bet 0 = (returnUncalled s).bet 1 := by
  unfold PaidIn at *
  unfold returnUncalled
  split
  · simp [setFor]; omega
  · split
    · simp [setFor]; omega
    · omega

/-- Moving equal bets into the pot keeps the fact, and leaves both bets at 0. -/
theorem collectBets_paidIn {S : Player → Nat} (s : State) (hp : PaidIn S s)
    (heq : s.bet 0 = s.bet 1) :
    PaidIn S (collectBets s) ∧ (collectBets s).bet 0 = 0 ∧ (collectBets s).bet 1 = 0 := by
  unfold PaidIn at *
  dsimp only [collectBets]
  omega

/-! ## The payouts -/

/-- A showdown pays the right player, when the bets are already in the pot. -/
theorem payShowdown_ok {S : Player → Nat} (h : Hand) (hp : PaidIn S h.chips)
    (hb0 : h.chips.bet 0 = 0) (hb1 : h.chips.bet 1 = 0) : PayoutOk S h.payShowdown := by
  unfold PaidIn at hp
  refine ⟨fun he => by simp [Hand.payShowdown] at he, ?_, fun w he => by simp [Hand.payShowdown] at he⟩
  intro r he
  simp only [Hand.payShowdown, Option.some.injEq, HandEnd.showdown.injEq] at he
  subst he
  refine ⟨rfl, ?_, ?_, ?_⟩
  · intro hr; simp only [Hand.payShowdown, hr]; simp; omega
  · intro hr; simp only [Hand.payShowdown, hr]; simp; omega
  · intro hr
    simp only [Hand.payShowdown, hr]
    match hbtn : h.button with
    | ⟨0, _⟩ => simp [other]; omega
    | ⟨1, _⟩ => simp [other]; omega

/-- A fold pays the player named as the winner: they gain what the other player put in,
and the other player loses it. -/
theorem payFold_ok {S : Player → Nat} (h : Hand) (w : Player) (hp : PaidIn S h.chips) :
    PayoutOk S (h.payFold w) := by
  unfold PaidIn at hp
  refine ⟨fun he => by simp [Hand.payFold] at he, fun r he => by simp [Hand.payFold] at he, ?_⟩
  intro w' he
  simp only [Hand.payFold, Option.some.injEq, HandEnd.folded.injEq] at he
  subst he
  match w with
  | ⟨0, _⟩ => simp [Hand.payFold, setFor, other]; omega
  | ⟨1, _⟩ => simp [Hand.payFold, setFor, other]; omega

/-! ## Ending betting rounds and passing the turn -/

/-- Ending betting rounds keeps the hand on track, however many rounds are ended. -/
theorem finishStreet_ok {S : Player → Nat} (fuel : Nat) (h : Hand) (hn : h.ended = none)
    (hp : PaidIn S h.chips) : PayoutOk S (h.finishStreet fuel) := by
  induction fuel generalizing h with
  | zero => exact payoutOk_of_paidIn hn hp
  | succ fuel ih =>
    obtain ⟨hr, heq⟩ := returnUncalled_paidIn h.chips hp
    obtain ⟨hc, hb0, hb1⟩ := collectBets_paidIn _ hr heq
    simp only [Hand.finishStreet]
    split
    · next heqn =>
      split at heqn <;> try (cases heqn)
      exact payShowdown_ok _ hc hb0 hb1
    · split
      · exact payoutOk_of_paidIn (by simpa [Hand.dealBoard] using hn) hc
      · exact ih _ (by simpa [Hand.dealBoard] using hn) hc

/-- Passing the turn keeps the hand on track. -/
theorem passTurn_ok' {S : Player → Nat} (h : Hand) (first : Player) (hn : h.ended = none)
    (hp : PaidIn S h.chips) : PayoutOk S (h.passTurn first) := by
  unfold Hand.passTurn
  split
  · exact payoutOk_of_paidIn hn hp
  · exact finishStreet_ok _ _ hn hp

/-! ## Moves, deals and whole runs -/

/-- An accepted move keeps the hand on track. -/
theorem step_ok {S : Player → Nat} (h h' : Hand) (a : Action) (hok : PayoutOk S h)
    (hs : step h a = .ok h') : PayoutOk S h' := by
  unfold step at hs
  split at hs
  · cases hs
  next hn =>
  have hn : h.ended = none := by simpa using hn
  have hp := hok.1 hn
  split at hs
  · cases hs
  next hl =>
  split at hs
  · cases hs; exact payFold_ok _ _ hp
  · cases hs
    exact passTurn_ok' _ _ hn (applyMove_paidIn _ _ (Decidable.of_not_not hl) hp)

/-- A hand dealt from two stacks above 0 starts on track: each player posted a blind of at
least one chip. -/
theorem startHand_ok (S : Player → Nat) (button : Player) (seed : Nat) (h0 : 0 < S 0)
    (h1 : 0 < S 1) : PayoutOk S (startHand S button seed) := by
  unfold startHand
  have hn : (dealHand S button seed).ended = none := by
    rw [dealHand_eq_dealFrom]; exact dealFrom_ended _ _ _
  refine passTurn_ok' _ _ hn ?_
  rw [dealHand_eq_dealFrom, dealFrom_chips]
  unfold PaidIn
  have hsb : smallBlind = 5 := rfl
  have hbb : bigBlind = 10 := rfl
  match button with
  | ⟨0, _⟩ => simp [other, hsb, hbb]; omega
  | ⟨1, _⟩ => simp [other, hsb, hbb]; omega

/-- Any run of accepted moves keeps the hand on track. -/
theorem runsTo_ok {S : Player → Nat} (as : List Action) (h h' : Hand) (hok : PayoutOk S h)
    (hrun : RunsTo h as h') : PayoutOk S h' := by
  induction as generalizing h with
  | nil => simp only [RunsTo, RunsWith] at hrun; subst hrun; exact hok
  | cons a as ih =>
    obtain ⟨h₁, hs, hrest⟩ := hrun
    exact ih h₁ (step_ok _ _ _ hok hs) hrest

/-! ## The main theorems -/

/-- **At a showdown, the better hand wins the pot.** Deal a hand from stacks `S` (both above
0) and play any accepted moves. If the hand ends at a showdown with result `r`, then `r` is
the spec's `showdown` on the players' real cards and the board; the winner ends the hand
with more chips than they started it with and the loser with fewer; and on a tie both end
with exactly what they started with. -/
theorem showdown_pays_better_hand (S : Player → Nat) (button : Player) (seed : Nat)
    (h0 : 0 < S 0) (h1 : 0 < S 1) (as : List Action) (h' : Hand)
    (hrun : RunsTo (startHand S button seed) as h') (r : Outcome)
    (hend : h'.ended = some (.showdown r)) :
    r = showdown (h'.hole 0) (h'.hole 1) h'.board ∧
    (r = .player0 → S 0 < h'.chips.stack 0 ∧ h'.chips.stack 1 < S 1) ∧
    (r = .player1 → S 1 < h'.chips.stack 1 ∧ h'.chips.stack 0 < S 0) ∧
    (r = .tie → h'.chips.stack 0 = S 0 ∧ h'.chips.stack 1 = S 1) :=
  (runsTo_ok as _ h' (startHand_ok S button seed h0 h1) hrun).2.1 r hend

/-- **A fold pays the other player.** Deal a hand from stacks `S` (both above 0) and play
any accepted moves. If the hand ends with `w` recorded as the winner of a fold, then `w`
ends the hand with more chips than they started it with, and the other player with fewer. -/
theorem fold_pays_other_player (S : Player → Nat) (button : Player) (seed : Nat)
    (h0 : 0 < S 0) (h1 : 0 < S 1) (as : List Action) (h' : Hand)
    (hrun : RunsTo (startHand S button seed) as h') (w : Player)
    (hend : h'.ended = some (.folded w)) :
    S w < h'.chips.stack w ∧ h'.chips.stack (other w) < S (other w) :=
  (runsTo_ok as _ h' (startHand_ok S button seed h0 h1) hrun).2.2 w hend

/-- **Folding gives the hand to the other player.** When the engine accepts a fold, the
hand ends, and the player recorded as the winner is the one who did not fold. -/
theorem fold_records_other_player (h h' : Hand) (hs : step h .fold = .ok h') :
    h'.ended = some (.folded (other h.chips.toAct)) := by
  unfold step at hs
  split at hs
  · cases hs
  split at hs
  · cases hs
  · cases hs; rfl

/-! ## Checks

The theorems' conditions hold on real deals, for every kind of ending, and their conclusions
reject the wrong payouts. With 3 chips each, both blinds are all-in, so the hand is dealt
straight to a showdown. -/

/-- A real deal (seed 7, 3 chips each) that ends at a showdown, so every condition of
`showdown_pays_better_hand` holds. (Lean's checker can confirm the hand ends at a showdown,
but will not run the hand ranking itself, so the outcome is checked by `#guard` below.) -/
theorem seven_ends_at_showdown :
    ∃ r, (startHand (fun _ => 3) 0 7).ended = some (.showdown r) := ⟨_, rfl⟩

/-- The theorem applies to that real hand: its result is the spec's `showdown` on the real
cards and board. -/
example : ∃ r, (startHand (fun _ => 3) 0 7).ended = some (.showdown r) ∧
    r = showdown ((startHand (fun _ => 3) 0 7).hole 0) ((startHand (fun _ => 3) 0 7).hole 1)
      (startHand (fun _ => 3) 0 7).board :=
  let ⟨r, hr⟩ := seven_ends_at_showdown
  ⟨r, hr, (showdown_pays_better_hand (fun _ => 3) 0 7 (by decide) (by decide) [] _ rfl r hr).1⟩

-- The three kinds of showdown on real deals, with the chips each player ends with.
-- Seed 7: player 0 wins (a pair of eights against ace high) and goes from 3 to 6 chips.
#guard (startHand (fun _ => 3) 0 7).ended matches some (.showdown .player0)
#guard (startHand (fun _ => 3) 0 7).chips.stack 0 == 6 && (startHand (fun _ => 3) 0 7).chips.stack 1 == 0
-- Seed 0: player 1 wins.
#guard (startHand (fun _ => 3) 0 0).ended matches some (.showdown .player1)
#guard (startHand (fun _ => 3) 0 0).chips.stack 1 == 6 && (startHand (fun _ => 3) 0 0).chips.stack 0 == 0
-- Seed 32: a tie, and both keep their 3 chips.
#guard (startHand (fun _ => 3) 0 32).ended matches some (.showdown .tie)
#guard (startHand (fun _ => 3) 0 32).chips.stack 0 == 3 && (startHand (fun _ => 3) 0 32).chips.stack 1 == 3

/-- A real fold: 500 chips each, and the small blind (player 0) folds at once. -/
def foldedHand : Hand := (startHand (fun _ => startingStack) 0 7).payFold 1

example : RunsTo (startHand (fun _ => startingStack) 0 7) [.fold] foldedHand :=
  ⟨_, rfl, rfl⟩

/-- Folding records player 1, the one who did not fold, as the winner. -/
example : foldedHand.ended = some (.folded (other (startHand (fun _ => startingStack) 0 7).chips.toAct)) :=
  fold_records_other_player _ _ rfl

/-- `fold_pays_other_player` applies: player 1 ends with more than 500, player 0 with fewer. -/
example : 500 < foldedHand.chips.stack 1 ∧ foldedHand.chips.stack 0 < 500 :=
  fold_pays_other_player (fun _ => startingStack) 0 7 (by decide) (by decide) [.fold]
    foldedHand ⟨_, rfl, rfl⟩ 1 rfl

/-! The conclusions reject the wrong payouts. -/

/-- Paying the pot to the loser (seed 7, player 0 won, but player 0 ends with 0 and player 1
with 6) breaks the showdown conclusion. -/
example : ¬ (3 < (0 : Nat) ∧ (6 : Nat) < 3) := by decide

/-- Splitting a pot that player 0 won (both keep 3) breaks it too. -/
example : ¬ (3 < (3 : Nat) ∧ (3 : Nat) < 3) := by decide

/-- Recording the player who folded as the winner breaks `fold_records_other_player`:
player 0 folded, so `.folded 0` is not the recorded end it requires. -/
example : (some (.folded 0) : Option HandEnd) ≠
    some (.folded (other (startHand (fun _ => startingStack) 0 7).chips.toAct)) := by
  intro h
  have hw : (0 : Player) = other (startHand (fun _ => startingStack) 0 7).chips.toAct := by
    simpa using h
  have ht : (startHand (fun _ => startingStack) 0 7).chips.toAct = 0 := rfl
  rw [ht] at hw
  exact absurd hw (by decide)

#print axioms showdown_pays_better_hand
#print axioms fold_pays_other_player
#print axioms fold_records_other_player
