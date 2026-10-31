# A03: Von Neumann's poker model and the indifference principle (bluff share by bet size)

## Summary

**Source:** C. Ferguson, T. S. Ferguson. "On the Borel and von Neumann Poker Models." Venue unsure. https://www.math.ucla.edu/~tom/papers/poker1.pdf

TL;DR: Ferguson and Ferguson restate von Neumann's one-bet poker model with exact formulas and derive them from "indifference equations". From their first equation, the bluff share of the betting range is B/(2B+2) for a bet of B into a pot of 2. That is s/(1+2s) with s = bet / pot. We believed s/(1+2s), and it is confirmed under the conditions below.

What matters for us:
- Balanced bluff share = s/(1+2s) = the caller's required equity (pot odds). It holds for one final betting decision, a polarized betting range, a caller who can only call or fold, and chip-EV (risk-neutral) payoffs.
- With slider k in [0, 2], k * s/(1+2s) <= 2s/(1+2s) < 1 for every bet size. So the target share never reaches 1. But the needed bluffs per value hand is 2s at k = 2, which can be more bluff hands than the range has.
- "Twice the bluff share" (2s/(1+2s)) is not "twice as many bluff hands" (that gives share 2s/(1+3s)). The spec must pick one.
- Von Neumann's exact solution: value B/((B+1)(B+4)); at B = 2 (pot-sized bet), a = 1/9, b = 7/9, c = 5/9, value 1/9, and B = 2 is the best bet size.
- Nothing here is machine-checked. The algebra is a 1-2 hour Lean target.

Verdict: use. It gives the exact baseline for the bluff slider and its conditions.

## Citation

- Chris Ferguson, Thomas S. Ferguson. "On the Borel and von Neumann Poker Models." Source type: paper hosted on T. Ferguson's UCLA page. Venue: unsure. The PDF I read does not print a venue. (I believe it appeared in Game Theory and Applications, around 2003, but I did not verify this.) Treat as "paper, venue unverified".
- URL fetched: https://www.math.ucla.edu/~tom/papers/poker1.pdf (fetched 2026-10-31; full text read, sections 1 and 3).
- The underlying model is from von Neumann and Morgenstern, Theory of Games and Economic Behavior (1944), section 19. Book NOT opened: UNVERIFIED; everything below is as Ferguson and Ferguson state it.
- Citation count: not looked up.

Book named by the lead, NOT opened:
- Bill Chen, Jerrod Ankenman. The Mathematics of Poker. ConJelCo, Pittsburgh, 2006. ISBN 978-1886070257. Source type: book. I found only retailer and catalog listings (search results); I could not open the book or a publisher page. UNVERIFIED. I state nothing from its content. Not counted.

## Claim status

| Claim | Status |
|---|---|
| Theorem 2 (value and optimal strategies of von Neumann's poker) | Proved on paper (von Neumann 1944; re-derived by Ferguson and Ferguson by the principle of indifference). |
| Optimal fixed bet size is B = 2 (the pot) | Proved on paper (set dV/dB = 0). |
| Bluffing must use the worst hands | Proved on paper (part of Theorem 2; explained informally in the paper). |
| Bluff share = B/(2B+2) = s/(1+2s) | Derived by me in this note from their equation (6), on paper. Short and checkable; not stated in this form in the paper. |
| Caller's required equity = s/(1+2s) | Standard pot-odds arithmetic, derived by me below. |
| Slider x baseline < 1 for slider <= 2 | Derived by me below. |
| Anything machine-checked | Nothing found. |

## Setting and definitions (von Neumann's model, as in Ferguson and Ferguson)

Plain words: each player gets a random number between 0 and 1 as their "hand"; higher wins. Both ante 1, so the pot is 2. Player I may bet B or check. If Player I checks, hands are compared at once. If Player I bets, Player II calls or folds.

Payoffs to Player I (precise):
- Check: +1 if X > Y, -1 if X < Y.
- Bet, Player II folds: +1.
- Bet, Player II calls: +(B+1) if X > Y, -(B+1) if X < Y.

Hands X, Y are independent and uniform on [0, 1]. Each player knows only their own hand.

## Main result (Theorem 2, as stated by Ferguson and Ferguson)

- Value to Player I: V(B) = B / ((B+1)(B+4)).
- Player I's unique optimal strategy: bet if X < a or X > b, check if a < X < b, where
  a = B / ((B+1)(B+4)),  b = (B^2 + 4B + 2) / ((B+1)(B+4)).
- Player II's unique admissible optimal strategy: call if Y > c, fold otherwise, where
  c = B(B+3) / ((B+1)(B+4)).
- Order: 0 < a < c < b < 1.
- Example, pot-limit B = 2: a = 1/9, b = 7/9, c = 5/9, V(2) = 1/9.
- The best fixed bet size for Player I is B = 2, the size of the pot.
- Other optimal strategies for Player II exist: any call/fold rule on hands between a and b whose average calling probability there is (b - c)/(b - a). Only the threshold rule above is admissible (it also punishes Player I for bluffing with non-worst hands).

The indifference equations (the paper's derivation, "gambler's point of view": money already in the pot counts as a bonus):
- (6) Player II with Y = c is indifferent between calling and folding: (B+2)a - B(1-b) = 0.
- (7) Player I with X = a is indifferent between checking and betting: 2c - B(1-c) = 2a.
- (8) Player I with X = b is indifferent: 2c + (B+2)(b-c) - B(1-b) = 2b, which reduces to 2b - c = 1.

## The bluff share formula (derived here from equation 6)

Player I's bets are bluffs (X < a, mass a) and value bets (X > b, mass 1 - b).
- From (6): a / (1 - b) = B / (B + 2). This is the bluff-to-value ratio.
- Bluff share of the betting range: a / (a + (1 - b)) = B / (B + B + 2) = B / (2B + 2).
- Check at B = 2: a = 1/9, 1 - b = 2/9, share = 1/3 = 2/6. Correct.
- Write the bet as a fraction of the pot: the pot before the bet is 2, so s = B/2. Then share = 2s / (4s + 2) = s / (1 + 2s). Bluff-to-value ratio = B/(B+2) = s/(1+s).

Why equation (6) is the general "polarized river" rule: the caller's threshold hand c beats every bluff (a < c) and loses to every value bet (b > c). So at the threshold the caller holds a pure "bluff-catcher". The same algebra applies to any spot with these conditions.

General one-street statement (my derivation; plain arithmetic):
- Pot P before the bet. Bettor bets S = sP. Caller calls S to win P + S.
- Caller's hand beats every bluff and loses to every value hand. Let q = bluff share of the bettor's betting range.
- Caller's chip EV of calling, counting from the moment of the decision: q(P + S) - (1 - q)S. Folding is 0.
- Calling EV = 0 iff q = S / (P + 2S) = s / (1 + 2s). Calling EV > 0 iff q > s/(1+2s).
- The caller's required equity (pot odds) is the same number: S / (P + 2S) = s/(1+2s).
- The bettor's bluffs are indifferent between betting and giving up when the caller calls with probability P/(P+S) = 1/(1+s) (assuming a bluff never wins at showdown and giving up scores 0). This is a simplified polarized model. It is not exactly von Neumann's model, where checking the worst hand still wins sometimes (equation 7).

Exact conditions for "balanced bluff share = s/(1+2s)":
1. One final betting decision: no more cards, and the caller can only call or fold (no raise).
2. The bettor's betting range is polarized against the caller's hand: each bet hand either beats it or loses to it. No ties, no split pots.
3. Payoffs are chips (risk neutral). A risk-averse caller (our Risk slider) is indifferent at a different share. So the bluff baseline must be defined in chip EV, separate from the Risk slider.
4. Use the effective bet: if a stack is smaller than S, S is the amount actually at risk.
5. No rake. The pot P includes all money already in the middle.

## Slider x baseline (derived here)

Target share with slider k: q(k, s) = k * s / (1 + 2s).
- For k in [0, 2] and s >= 0: q <= 2s/(1 + 2s) < 1, because 2s < 1 + 2s. So the share is always below 1. It tends to 1 as s grows (s = 1 gives 2/3; s = 2 gives 4/5; s = 10 gives 20/21).
- Feasibility problem: share q needs q/(1 - q) bluff hands per value hand. At k = 2 this is 2s/(1 + 2s - 2s) = 2s. A pot-sized bet at k = 2 needs 2 bluffs per value hand; a 3x pot overbet needs 6. The bot's range may not hold that many bluff candidates. The spec must say what happens then (for example: use all available bluff hands and report the shortfall).
- Ambiguity to resolve: "k times the bluff share" is not "k times as many bluff hands". Doubling the bluff count gives share 2s/(1 + 3s), not 2s/(1 + 2s). Pick one definition and state it in the spec.

## Assumptions and limitations

- Uniform [0, 1] hands, one bet size fixed before play, one round, no raising.
- Risk-neutral payoffs.
- The bluff-share formula needs a polarized range. Real NLHE river ranges often have medium hands that bet for thin value; then the formula is only a guide.

## What is formally verified

Nothing in the source. No machine-checked proof found.

## Code artifacts

None. License not applicable.

## Relevance to our project

- Gives the exact "game theory baseline" for the bluff slider and the conditions under which it is exact.
- Shows the bluff slider at 2 never asks for more than 100% bluffs, but may ask for more bluff hands than exist.
- Gives a neat, provable fact for the demo: the best fixed bet size in von Neumann's game is the pot.

## Candidate theorems for us

1. Caller indifference at the baseline (pure algebra).
   ```lean
   def baselineShare (s : ℚ) : ℚ := s / (1 + 2*s)
   theorem caller_indifferent (s : ℚ) (hs : 0 ≤ s) :
       baselineShare s * (1 + s) - (1 - baselineShare s) * s = 0
   theorem call_profitable_iff (s q : ℚ) (hs : 0 ≤ s) :
       0 < q * (1 + s) - (1 - q) * s ↔ baselineShare s < q
   ```
   About 1 hour (`field_simp`, `ring`, `linarith`).
2. Slider stays below 1.
   ```lean
   theorem slider_share_lt_one (k s : ℚ) (hk0 : 0 ≤ k) (hk : k ≤ 2) (hs : 0 ≤ s) :
       k * baselineShare s < 1
   ```
   About 30 minutes.
3. Von Neumann's formulas satisfy the indifference equations (6), (7), (8), and at B = 2 give 1/9, 7/9, 5/9, 1/9.
   ```lean
   theorem vn_indiff (B : ℚ) (hB : 0 < B) :
       (B+2)*a B - B*(1 - b B) = 0 ∧ 2*c B - B*(1 - c B) = 2*a B ∧ 2*b B - c B = 1
   example : a 2 = 1/9 ∧ b 2 = 7/9 ∧ c 2 = 5/9 ∧ V 2 = 1/9 := by norm_num [a, b, c, V]
   ```
   About 1-2 hours. A full proof that these strategies are optimal in the continuous game needs integrals; estimate 15+ hours; not recommended.
4. On the actual bot code: in a river spot with a polarized range, the share of bluffs among the bot's bet hands equals k * baselineShare s exactly (when enough bluff candidates exist).
   ```lean
   theorem bot_bluff_share (spot : RiverSpot) (k : ℚ) (h : enoughBluffCandidates spot k) :
       bluffShare (botBetRange spot k) = k * baselineShare spot.betFrac
   ```
   About 4-10 hours, depending on how the bot picks hands.
5. Spec rejects bad output: at a pot-sized bet, a 1/2 bluff share is not balanced.
   ```lean
   example : baselineShare 1 ≠ 1/2 := by norm_num [baselineShare]
   ```
