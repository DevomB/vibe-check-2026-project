# A01: Kuhn poker, its equilibrium family and game value

## Summary

**Source:** Hoehn, Southey, Holte, Bulitko. "Effective Short-Term Opponent Exploitation in Simplified Poker." AAAI 2005. https://cdn.aaai.org/AAAI/2005/AAAI05-123.pdf. Also Ganzfried, Sandholm, "Safe Opponent Exploitation", ACM TEAC 2015 (see A05).

TL;DR: Kuhn poker (3 cards, ante 1, bet 1, one round) has a known exact solution. Two peer-reviewed papers (Hoehn et al., AAAI 2005; Ganzfried and Sandholm, ACM TEAC 2015) and Wikipedia agree on it. Kuhn's 1950 original was not opened.

What matters for us:
- P2 has one equilibrium strategy: facing a bet, J folds, Q calls 1/3, K calls; facing a check, J bets 1/3, Q checks, K bets.
- P1 has a family with one parameter a in [0, 1]: J bets a/3, Q always checks then calls a/3 + 1/3, K bets a. (Wikipedia writes alpha = a/3 in [0, 1/3].)
- Game value: -1/18 per hand for P1.
- Exploitability = game value minus worst-case payoff. A worst-case opponent can always be a pure strategy, so "exploitability 0" is a finite check over 64 pure opponent strategies with exact rationals. Checking both sides also proves the value, with no LP.
- No machine-checked proof of any of this was found. It is a clear, small novelty target (about 4-8 hours for the value, 6-12 for the whole family).

Verdict: use. It is the core of the "provably unexploitable" mini-mode, and every claim reduces to a finite exact check.

## Citation

Main scholarly source read in full text:
- Bret Hoehn, Finnegan Southey, Robert C. Holte, Valeriy Bulitko. "Effective Short-Term Opponent Exploitation in Simplified Poker." Proceedings of AAAI 2005, pp. 783-788 (page range from search results, not checked on the PDF). Peer-reviewed conference paper.
  - URL fetched: https://cdn.aaai.org/AAAI/2005/AAAI05-123.pdf (fetched 2026-10-31; text read section "Kuhn Poker" and "Nash Equilibria and Exploration").
  - A journal version exists (Southey et al., Machine Learning 74, 2009, doi 10.1007/s10994-008-5091-5). Seen only in search results: UNVERIFIED, not counted.

Second scholarly confirmation (full text read, see also A05):
- Sam Ganzfried, Tuomas Sandholm. "Safe Opponent Exploitation." ACM Transactions on Economics and Computation 3(2), Article 8, April 2015, 28 pages. DOI 10.1145/2716322. Section 9.1 states Kuhn's rules and the full equilibrium set.
  - URL fetched: https://www.cs.cmu.edu/~sandholm/safeExploitation.teac15.pdf (fetched 2026-10-31).

Cross-check (not scholarly):
- Wikipedia, "Kuhn poker". URL fetched: https://en.wikipedia.org/wiki/Kuhn_poker (fetched 2026-10-31). Source type: encyclopedia page.

Original paper (NOT opened):
- H. W. Kuhn, "A simplified two-person poker", in Kuhn and Tucker (eds.), Contributions to the Theory of Games, Vol. 1, Princeton University Press, 1950, pp. 97-103 (citation as given by Wikipedia and by Ganzfried-Sandholm's reference list). UNVERIFIED: I did not open the original. All numbers below come from the three sources above, which agree with each other.

Citation counts: not looked up.

## Claim status

| Claim | Status |
|---|---|
| Rules of Kuhn poker (below) | Stated identically in all three sources. |
| P2 has exactly one equilibrium strategy; P1 has a one-parameter family | Proved on paper by Kuhn 1950 (as reported by Hoehn 2005 and Ganzfried-Sandholm 2015; original not opened). |
| Game value for P1 is -1/18 per hand | Proved on paper (Kuhn 1950, as reported). Restated by all three sources. |
| "these are all the equilibria" | Stated by Ganzfried-Sandholm 2015, citing Kuhn 1950. Proof not given in the paper I read. |
| Gift strategies of P2 = strategies that use any of 4 zero-probability actions | Stated by Ganzfried-Sandholm 2015 (paper claim, short argument). |
| Some equilibrium strategies let P1 learn the opponent faster | Shown empirically (Hoehn 2005). |
| Anything machine-checked | Nothing. No source reports a machine-checked proof about Kuhn poker. A web search (2026-10-31) found no formalization of Kuhn poker in Lean, Coq or Isabelle. |

## Setting and definitions

Plain words: two players, three cards (Jack < Queen < King). Each player puts 1 chip in the pot (the ante), gets one card, and the third card is unused. There is one betting round, and a bet is always exactly 1 chip. Higher card wins at showdown.

Precise rules (Hoehn 2005; Ganzfried-Sandholm 2015 sec. 9.1; Wikipedia):
1. Both players ante 1. Pot = 2.
2. Deal one card to each player, uniformly at random, from {J, Q, K}. 6 equally likely deals.
3. P1 checks or bets 1.
4. If P1 bets: P2 folds (P1 wins the pot of 3, so P1 nets +1) or calls (showdown for pot 4, winner nets +2).
5. If P1 checks: P2 checks (showdown for pot 2, winner nets +1) or bets 1.
6. If P1 checks and P2 bets: P1 folds (P2 nets +1) or calls (showdown for pot 4, winner nets +2).

Information sets (decision points as seen by the player): P1 has 6 (3 cards x {first action, facing a bet after checking}). P2 has 6 (3 cards x {facing a bet, facing a check}). So each player has 2^6 = 64 pure strategies. (My count from the rules, not stated in the sources.)

## Main result: the equilibrium family

Ganzfried-Sandholm 2015 form, parameter a in [0, 1] (they call it alpha):
- P1 with J: bet with probability a/3. If P1 checks and P2 bets: always fold.
- P1 with Q: always check. If P2 then bets: call with probability a/3 + 1/3.
- P1 with K: bet with probability a. If P1 checks and P2 bets: always call.
- P2 facing a bet: J always folds; Q calls with probability 1/3; K always calls.
- P2 facing a check: J bets with probability 1/3; Q always checks; K always bets.

Wikipedia form, parameter alpha in [0, 1/3]: J bets alpha, K bets 3*alpha, Q calls alpha + 1/3. This is the same family with alpha = a/3.

Hoehn 2005 form: P1 parameters (alpha, beta, gamma) = (gamma/3, (1+gamma)/3, gamma) for 0 <= gamma <= 1; P2 parameters eta = 1/3 and xi = 1/3. The letters are attached to decisions in Figure 1 of that paper, which I could not read as text. Under the mapping alpha = J bets, beta = Q calls, gamma = K bets (my inference), this matches the other two forms exactly.

Game value: P1 expects -1/18 per hand (about -0.0556), P2 +1/18, "if either player plays an equilibrium strategy (and neither play dominated strategies)" (Hoehn 2005). Ganzfried-Sandholm state the value of the game to P1 is -1/18 with no extra condition.

Example strategies used in the literature: Hoehn 2005 use the Nash strategy (alpha = 1/6, beta = 1/2, gamma = 1/2), that is, J bets 1/6, Q calls 1/2, K bets 1/2. This is a = 1/2 in the Ganzfried-Sandholm form.

Facts about P2 (Ganzfried-Sandholm 2015 sec. 9.1): P2 has four actions that the equilibrium never uses: (1) call a bet with J, (2) fold K to a bet, (3) check K after P1 checks, (4) bet Q after P1 checks. The first three are dominated; the fourth is iteratively dominated. The "gift" strategies of P2 (see A05) are exactly the strategies that use at least one of these four with positive probability.

Hoehn 2005 also report: P2's strategy space (in the two numbers eta, xi) splits into 6 regions; in each, one P1 pure strategy is the best response. The three dividing lines meet at P2's Nash strategy.

## Exploitability in a small game (how to compute exactly)

Definitions (from A06 Johanson 2011 and A05 Ganzfried-Sandholm 2015):
- Best response to a fixed opponent strategy: a strategy that gets the most expected payoff against it.
- Exploitability of P1's strategy s1: expl(s1) = v1 - min over P2 strategies s2 of u1(s1, s2), where v1 is the game value for P1 (here -1/18).
- Ganzfried-Sandholm: "there always exists a nemesis that is a pure strategy", so the minimum can be taken over the finitely many pure P2 strategies.

So yes: exploitability 0 is checkable by finite enumeration. For Kuhn poker:
1. Fix P1's strategy s1 (probabilities as exact rationals).
2. For each of P2's 64 pure strategies s2, compute u1(s1, s2) as the average over the 6 deals of the payoff along the betting tree. This is exact rational arithmetic.
3. s1 has exploitability 0 iff every one of the 64 numbers is >= -1/18.
4. To also prove the value is -1/18 (not just assume it): fix P2's equilibrium strategy and check that every one of P1's 64 pure strategies gets <= -1/18. Steps 3 and 4 together prove the value and that both strategies are equilibrium strategies. No linear programming or minimax theorem is needed.

Why pure strategies suffice (proved on paper, standard): u1(s1, s2) is linear in P2's mixing, so its minimum over mixtures is reached at a pure strategy. With perfect recall, behaviour strategies and mixed strategies are equivalent (Kuhn's theorem, 1953). For a direct Lean proof on Kuhn poker, you do not need Kuhn's theorem: you can define P2's strategy as 6 independent probabilities, note u1 is affine in each one separately, and conclude the minimum is at a corner. Or you just prove the inequality for all 6 probabilities in [0, 1] with linear arithmetic.

## Independent exact check (done for this note, not a proof)

I wrote a throwaway Python script with exact fractions (kept in my scratchpad, not in the repo). It checks the numbers above:
- For a = 0, 1/2 and 1 (Ganzfried-Sandholm form): P1's equilibrium strategy vs P2's equilibrium = -1/18, and the minimum over all 64 pure P2 strategies = -1/18. So exploitability 0.
- P2's equilibrium vs all 64 pure P1 strategies: maximum = -1/18. So the value is -1/18.
- Bad strategy "always bet J" (K always bets, Q checks then calls 1/3): minimum over pure P2 = -7/18, so exploitability = -1/18 - (-7/18) = 1/3 chip per hand.
- Status: exact computation in Python, not machine-checked. It shows the finite-enumeration plan works and gives target numbers for Lean `#guard` tests.

## Assumptions and limitations

- Hoehn 2005 remove dominated strategies from the game tree before parameterizing. Their parameter count (3 for P1, 2 for P2) is for the reduced tree. A Lean model of the full game should use 6 parameters per player.
- The claim "these are all the equilibria" (Ganzfried-Sandholm) is cited to Kuhn 1950; I did not see a proof.
- The value -1/18 is for P1 in a single hand. If the players swap seats every hand, a pair of hands has value 0.

## What is formally verified

Nothing in these sources. No machine-checked proof of Kuhn poker's value or equilibria was found. This is a gap we can fill.

## Code artifacts

None in these sources. (OpenSpiel and other libraries implement Kuhn poker, but I did not open them; not cited.)

## Relevance to our project

Kuhn poker is the cleanest "provably unexploitable" mini-mode: 6 deals, 12 decision points, 64 pure strategies per side, exact rational values. Every claim fits in a finite check. It is also the test bed used by both opponent-exploitation papers (Hoehn 2005; Ganzfried-Sandholm 2015), so our safe-exploitation demo can be in the same game.

## Candidate theorems for us

1. Game value is -1/18 (finite check).
   Plain English: the strategy pair from Kuhn's paper is an equilibrium, and P1 expects to lose 1/18 chip per hand.
   ```lean
   theorem kuhn_p1_guarantee : ∀ s2 : P2Pure, -1/18 ≤ evP1 (p1Eq (1/2)) (pure2 s2)
   theorem kuhn_p2_guarantee : ∀ s1 : P1Pure, evP1 (pure1 s1) p2Eq ≤ -1/18
   theorem kuhn_value : evP1 (p1Eq (1/2)) p2Eq = -1/18
   ```
   About 4-8 hours, including writing the game as executable Lean (`evP1` over ℚ). Warning (unsure): kernel `decide` on ℚ may be slow; scaling all values by a common denominator into ℤ, or `norm_num`/`simp` on each case, are fallbacks; `native_decide` adds an axiom.
2. The whole family is unexploitable.
   Plain English: for every a in [0, 1], P1's strategy p1Eq a loses at most 1/18 per hand against any P2.
   ```lean
   theorem kuhn_family_unexploitable (a : ℚ) (h0 : 0 ≤ a) (h1 : a ≤ 1) :
       ∀ s2 : P2Mixed, -1/18 ≤ evP1 (p1Eq a) s2
   ```
   About 6-12 hours (64 cases or one affine argument; each case closes with `linarith`/`nlinarith`).
3. Exploitability of our engine's actual Kuhn bot equals a computed number, e.g. 0.
   ```lean
   def exploitability (s1 : P1Mixed) : ℚ := -1/18 - (List.map (fun s2 => evP1 s1 (pure2 s2)) allP2Pure).minimum
   theorem ourBot_exploitability_zero : exploitability ourKuhnBot = 0
   ```
   About 2-4 hours once 1 is done.
4. Spec rejects bad behaviour: P1 "always bluff with J" is exploitable.
   ```lean
   example : exploitability alwaysBetJack = 1/3   -- J and K always bet, Q checks then calls 1/3
   ```
   Under 1 hour once 3 is done. (Value 1/3 from my exact Python check above.)
