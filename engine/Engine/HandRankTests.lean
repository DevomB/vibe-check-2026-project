import Poker
import Engine.Deck

/-!
# Hand ranking tests

Showdowns with a known correct answer, checked by `showdown` from `Poker/Spec/HandRank.lean`.
Most of them test kickers: when two players have the same kind of hand, the next highest
cards decide, and cards outside the best five never count. Every `#guard` runs on
`lake build`, so a wrong answer fails the build.
-/

/-- Cards from text, for example `cards "Ah Kd"`. Rank is one of 2-9, T, J, Q, K, A; suit is
one of c, d, h, s. Trusted test literals only: unknown ranks/suits fall back to two/clubs. -/
def cards (s : String) : List Card :=
  (s.splitOn " ").filter (· ≠ "") |>.map fun w =>
    let r := "23456789TJQKA".toList.idxOf (w.toList.getD 0 ' ')
    let suit := match w.toList.getD 1 ' ' with
      | 'd' => Suit.diamonds | 'h' => .hearts | 's' => .spades | _ => .clubs
    ⟨⟨r % 13, Nat.mod_lt _ (by decide)⟩, suit⟩

#guard (cards "Ah Td 2c").map toString == ["Ah", "Td", "2c"]

/-- Who wins: player 0's two cards, player 1's two cards, then the five board cards. -/
def winner (p0 p1 board : String) : Outcome :=
  showdown (cards p0) (cards p1) (cards board)

/-- Score of exactly five cards. -/
def score (hand : String) : List Nat := handScore (cards hand)

/-! ## One pair: the kickers decide -/

-- Same pair of aces. First kicker: king beats queen.
#guard winner "Ah Kd" "As Qd" "Ad 7c 5s 3h 2c" == .player0
-- Same pair, same first kicker (king on the board). Second kicker: 9 beats 8.
#guard winner "Ah 9d" "As 8d" "Ad Kc 7s 4h 2c" == .player0
-- Same pair, same first two kickers. Third kicker: 9 beats 8.
#guard winner "Ah 9d" "As 8d" "Ad Kc Qs 4h 2c" == .player0
-- The board's K Q J are better than both players' kickers, so both play A A K Q J: a tie.
#guard winner "Ah 9d" "As 8d" "Ad Kc Qs Jh 2c" == .tie
-- Pair of kings on the board. The ace in player 0's hand is the best kicker.
#guard winner "Ah 3d" "Qs Jd" "Kd Kc 9s 7h 2c" == .player0
-- Pair on the board and both hands are too low to play: both play K K A Q J.
#guard winner "2h 3d" "4s 5d" "Kd Kc As Qh Jc" == .tie
-- A higher pair beats a lower pair, even when the lower pair has an ace kicker.
#guard winner "9h 4d" "7h Ad" "9d 7c 5s 3h 2c" == .player0
-- A pocket pair beats a pair made with the board when it is higher.
#guard winner "Qh Qd" "Js Ad" "Jd 8c 5s 3h 2c" == .player0

/-! ## Two pair -/

-- Same two pair on the board (kings and nines). The kicker decides: ace beats queen.
#guard winner "Ah 3d" "Qs Jd" "Kd Kc 9s 9h 2c" == .player0
-- Counterfeited: player 0's pair of threes does not play, because the board's kings and
-- nines are better. Player 1's ace kicker wins.
#guard winner "3h 3d" "As 2d" "Kd Kc 9s 9h 8c" == .player1
-- Three pairs in seven cards: only the best two count, and the fifth card is the best
-- card left. Player 0: K K 9 9 4. Player 1: K K 9 9 Q.
#guard winner "4h 2d" "Qs 2c" "Kd Kc 9s 9h 4c" == .player1
-- Higher top pair wins: aces and twos beat kings and queens.
#guard winner "Ah 2d" "Kh Qd" "As Kd Qs 2h 7c" == .player0

/-! ## Three of a kind, full house, four of a kind -/

-- Trips on the board: the kickers decide. Player 0: 7 7 7 A K. Player 1: 7 7 7 K Q.
#guard winner "Ah 3d" "Qs Jd" "7d 7c 7s Kh 2c" == .player0
-- Full houses: the three of a kind counts first. Kings full beats nines full.
#guard winner "Kh 3d" "9d Ac" "Kd Kc 9s 9h 2c" == .player0
-- Two threes of a kind make a full house of the higher one, full of the lower one.
-- Both players have kings full of nines: a tie.
#guard winner "Ks 9c" "Kh 2d" "Kd Kc 9s 9h 2c" == .tie
-- Same three of a kind, different pair: queens beat jacks.
#guard winner "Qh Qd" "Jh Jd" "Ad Ac As 5h 2c" == .player0
-- Four nines on the board: the kicker decides. Ace beats king.
#guard winner "Ah 3d" "Ks Qd" "9d 9c 9s 9h 2c" == .player0
-- Four nines and an ace on the board: both play the board.
#guard winner "Kh 3d" "Qs Jd" "9d 9c 9s 9h Ac" == .tie

/-! ## Flushes -/

-- Both have a heart flush. Compare all five cards: A 9 7 4 3 beats A 9 7 4 2.
#guard winner "3h Kd" "2h Qd" "Ah 9h 7h 4h 2c" == .player0
-- Five hearts on the board. Player 0's 2 is too low to play; player 1's 5 replaces the 4.
#guard winner "2h 3c" "5h 3d" "Ah Kh 9h 7h 4h" == .player1
-- Five hearts on the board and neither hand improves it: a tie.
#guard winner "2h 3c" "3h 2c" "Ah Kh 9h 7h 4h" == .tie

/-! ## Straights -/

-- Jack-high straight beats nine-high straight.
#guard winner "Th Jd" "5d Ad" "9d 8c 7s 6h 2c" == .player0
-- The wheel (A 2 3 4 5) is the lowest straight; a six-high straight beats it.
#guard winner "Ah 5d" "5s 6d" "2d 3c 4s Kh Kc" == .player1
-- No wrapping round: K A 2 3 4 is not a straight. Both have ace-high, and player 1's
-- 9 8 beat player 0's 9 4.
#guard winner "3h 4d" "8h 7d" "Qd Kc As 2h 9c" == .player1
#guard score "Kc Ad 2h 3s 4c" == [0, 12, 11, 2, 1, 0]
-- The ace counts high in a straight to the ace (T J Q K A).
#guard score "Tc Jd Qh Ks Ac" == [4, 12]
#guard score "Ac 2d 3h 4s 5c" == [4, 3]

/-! ## High card -/

-- The fifth card decides: A J 8 6 5 beats A J 8 6 4.
#guard winner "4h 3d" "5s 3c" "Ad Jc 8s 6h 2c" == .player1
-- Only five cards count: both play A J 8 6 5, so the 4 vs 2 does not matter.
#guard winner "4h 3d" "4s 2d" "Ad Jc 8s 6h 5c" == .tie

/-! ## Kinds of hand, in order -/

def kindStraightFlush := "9h Th Jh Qh Kh"
def kindFourOfAKind   := "Ac Ad Ah As 2c"
def kindFullHouse     := "Kc Kd Kh 2s 2c"
def kindFlush         := "Ac Jc 9c 6c 3c"
def kindStraight      := "9c Td Jh Qs Kc"
def kindThreeOfAKind  := "Qc Qd Qh 3s 2c"
def kindTwoPair       := "Ac Ad Kh Ks 2c"
def kindOnePair       := "Ac Ad Kh Qs Jc"
def kindHighCard      := "Ac Kd Qh Js 9c"

/-- Weakest first. Each kind must beat every kind before it, even when the weaker hand has
higher cards. -/
def kindsInOrder : List String :=
  [kindHighCard, kindOnePair, kindTwoPair, kindThreeOfAKind, kindStraight, kindFlush, kindFullHouse, kindFourOfAKind,
   kindStraightFlush]

#guard kindsInOrder.map (fun h => (score h).head!) == [0, 1, 2, 3, 4, 5, 6, 7, 8]
#guard (List.range kindsInOrder.length).all fun i =>
  (List.range kindsInOrder.length).all fun j =>
    if i < j then decide (score kindsInOrder[i]! < score kindsInOrder[j]!) else true

/-! ## Random deals

Deal 2,000 random hands from shuffled decks and check two things that must always hold. -/

/-- Seven-card deals from a seeded shuffle: player 0's two cards, player 1's two, the board. -/
def randomDeal (seed : Nat) : List Card × List Card × List Card :=
  let d := shuffle seed fullDeck
  (d.take 2, (d.drop 2).take 2, (d.drop 4).take 5)

/-- Swapping the two players swaps the result. -/
def Outcome.swap : Outcome → Outcome
  | .player0 => .player1 | .player1 => .player0 | .tie => .tie

#guard (List.range 2000).all fun seed =>
  let (a, b, board) := randomDeal seed
  showdown a b board == (showdown b a board).swap

-- A player's best score is at least the score of every five cards they could choose.
#guard (List.range 300).all fun seed =>
  let (a, _, board) := randomDeal seed
  let best := bestScore (a ++ board)
  (choose 5 (a ++ board)).all fun five => decide (handScore five ≤ best)
