import Spec.Basics

/-!
# Poker spec: which hand wins

A deliberately simple reference for ranking hands. The game's fast evaluator
must give the same winner as this one.

Idea: give every five-card hand a *score*, a list of numbers. The first number is the
kind of hand (pair, flush, ...). The rest break ties (which pair? which kicker?).
A hand with the bigger list wins, comparing numbers left to right like words in a dictionary.
-/

/-- Kinds of hand, weakest first. -/
inductive HandType where
  | highCard | pair | twoPair | threeKind | straight
  | flush | fullHouse | fourKind | straightFlush

/-- How strong each kind of hand is: 0 (high card) up to 8 (straight flush). -/
def HandType.strength : HandType → Nat
  | .highCard => 0 | .pair => 1 | .twoPair => 2 | .threeKind => 3 | .straight => 4
  | .flush => 5 | .fullHouse => 6 | .fourKind => 7 | .straightFlush => 8

/-- The distinct ranks in a hand, each paired with how many times it appears.
Written as (count, rank). The most-repeated ranks come first, and higher ranks come first
among equal counts. Example: a full house of three 9s and two 4s gives `[(3, 7), (2, 2)]`. -/
def rankGroups (hand : List Card) : List (Nat × Nat) :=
  let ranks := (hand.map (·.rank.val)).eraseDups
  let groups := ranks.map fun r => (hand.countP (fun c => c.rank.val == r), r)
  groups.mergeSort (fun a b => decide (a.1 > b.1 ∨ (a.1 = b.1 ∧ a.2 ≥ b.2)))

/-- Given five different ranks, highest first: if they form a straight, its top rank.
The ace can also be low (A-2-3-4-5), which counts as a five-high straight. -/
def straightHigh : List Nat → Option Nat
  | [a, b, c, d, e] =>
    if a = b + 1 ∧ b = c + 1 ∧ c = d + 1 ∧ d = e + 1 then some a
    else if [a, b, c, d, e] = [12, 3, 2, 1, 0] then some 3
    else none
  | _ => none

/-- Are all the cards the same suit? -/
def sameSuit : List Card → Bool
  | [] => true
  | c :: rest => rest.all (·.suit == c.suit)

/-- The score of exactly five cards. Bigger is better. -/
def handScore (hand : List Card) : List Nat :=
  let groups := rankGroups hand
  let counts := groups.map (·.1)
  let ranks := groups.map (·.2)
  let score (t : HandType) : List Nat := t.strength :: ranks
  match straightHigh ranks, sameSuit hand, counts with
  | some high, true, _ => [HandType.straightFlush.strength, high]
  | _, _, [4, 1] => score .fourKind
  | _, _, [3, 2] => score .fullHouse
  | _, true, _ => score .flush
  | some high, _, _ => [HandType.straight.strength, high]
  | _, _, [3, 1, 1] => score .threeKind
  | _, _, [2, 2, 1] => score .twoPair
  | _, _, [2, 1, 1, 1] => score .pair
  | _, _, _ => score .highCard

/-- All ways to pick `k` cards from a list, keeping their order. -/
def choose {α : Type} : Nat → List α → List (List α)
  | 0, _ => [[]]
  | _ + 1, [] => []
  | k + 1, x :: xs => (choose k xs).map (x :: ·) ++ choose (k + 1) xs

/-- The best score among all five-card hands inside the given cards
(a player's two hole cards plus the five on the board). -/
def bestScore (cards : List Card) : List Nat :=
  ((choose 5 cards).map handScore).foldl (fun a b => if a < b then b else a) []

/-- Who won. -/
inductive Outcome where
  | player0 | player1 | tie
  deriving DecidableEq, Repr

/-- The winner at showdown: each player makes their best five-card hand from
their two hole cards and the board. The better hand wins. Equal hands tie. -/
def showdown (hole0 hole1 board : List Card) : Outcome :=
  let a := bestScore (hole0 ++ board)
  let b := bestScore (hole1 ++ board)
  if a < b then .player1 else if b < a then .player0 else .tie

/-! ## Tests on known hands -/

/-- A card from a rank number (2 to 10, then 11 = jack, 12 = queen, 13 = king, 14 = ace). -/
def card (r : Nat) (s : Suit) : Card := ⟨⟨(r - 2) % 13, Nat.mod_lt _ (by decide)⟩, s⟩

def royalFlush := [card 14 .spades, card 13 .spades, card 12 .spades, card 11 .spades, card 10 .spades]
def fourNines := [card 9 .clubs, card 9 .diamonds, card 9 .hearts, card 9 .spades, card 14 .clubs]
def wheel := [card 14 .spades, card 2 .hearts, card 3 .diamonds, card 4 .clubs, card 5 .spades]
def sixHigh := [card 2 .spades, card 3 .hearts, card 4 .diamonds, card 5 .clubs, card 6 .spades]
def fullHouse := [card 9 .clubs, card 9 .diamonds, card 9 .hearts, card 4 .spades, card 4 .clubs]
def aceFlush := [card 14 .hearts, card 9 .hearts, card 7 .hearts, card 4 .hearts, card 2 .hearts]

#guard decide (handScore fourNines < handScore royalFlush)
#guard handScore wheel == [4, 3]                       -- a straight, five-high
#guard decide (handScore wheel < handScore sixHigh)    -- the wheel is the lowest straight
#guard decide (handScore aceFlush < handScore fullHouse)

-- Pair of aces beats pair of kings.
#guard showdown [card 14 .spades, card 14 .hearts] [card 13 .spades, card 13 .hearts]
  [card 2 .diamonds, card 7 .clubs, card 9 .spades, card 11 .hearts, card 4 .diamonds] == .player0

-- Same pair of aces: the better kicker (king vs queen) wins.
#guard showdown [card 14 .spades, card 13 .diamonds] [card 14 .hearts, card 12 .diamonds]
  [card 14 .diamonds, card 7 .clubs, card 5 .spades, card 3 .hearts, card 2 .clubs] == .player0

-- When the board is a royal flush, both players play the board and tie.
#guard showdown [card 2 .diamonds, card 3 .diamonds] [card 4 .hearts, card 5 .hearts]
  [card 14 .clubs, card 13 .clubs, card 12 .clubs, card 11 .clubs, card 10 .clubs] == .tie
