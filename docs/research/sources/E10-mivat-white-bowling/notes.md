# E10: MIVAT, "Learning a Value Analysis Tool for Agent Evaluation" (White and Bowling, IJCAI 2009)

## Summary

**Source:** White, Bowling. "Learning a Value Analysis Tool for Agent Evaluation." IJCAI 2009. https://www.ijcai.org/Abstract/09/326

TL;DR: MIVAT writes the identity we want in one line: actual result = skill + luck + position, where skill sums value changes at players' actions, luck sums value changes at chance events, and position is the value at the start (their Equation 9). If the value before each chance event is the probability-weighted average of the values after it (the "zero-luck constraint"), luck has mean zero and "skill + position" is an unbiased estimate. The paper then learns the value function from data.
- Equation 9 is exactly our seed theorem "EV + luck = actual result". It holds on every single hand by cancellation (telescoping); no probability needed.
- The zero-luck constraint (Equation 11) is a definition, so luck's mean zero is a short finite-sum lemma.
- In MIVAT, "skill" includes ALL players' actions (bot too). Since our bot is known code, AIVAT (E03) lets us move the bot's action terms into luck. For a deterministic bot those terms are 0 anyway.
- The value function can be anything that satisfies Eq. 11 at chance nodes; a learned or heuristic one is fine. Good news for our "labeled estimates" before the river.

Verdict: use. It gives the exact, citable statement of "skill + luck + position = result".

## Citation
- Martha White, Michael H. Bowling. "Learning a Value Analysis Tool for Agent Evaluation." Proceedings of the Twenty-First International Joint Conference on Artificial Intelligence (IJCAI-09), 2009, pages 1976-1980 (IJCAI abstract page; AIVAT's reference list says 1976-1981; unsure which).
- Fetched 2026-10-31: https://www.ijcai.org/Abstract/09/326 (official abstract page) and https://www.ijcai.org/Proceedings/09/Papers/326.pdf (official PDF, read as text; not saved in repo).
- Source type: peer-reviewed conference paper (IJCAI-09).
- Citation count: not looked up.

## Claim status
| Claim | Status |
|---|---|
| u_j(z) = S(z) + L(z) + P (skill + luck + position) | Exact algebraic identity (terms cancel). Stated in the paper; trivially provable. Not machine-checked. |
| With the zero-luck constraint, the advantage sum S + P is unbiased | Proved on paper (in Zinkevich et al. 2006, E09); restated here. |
| Defining V at chance nodes by Equation 11 guarantees the zero-luck constraint | Follows from the definition (paper states it). |
| Learned linear value functions reduce variance, incl. first estimators for no-limit and 6-player limit | Shown empirically. |

## Setting and definitions
- Plain words: pick any value function V that guesses "what player j will win from here". Walk through the hand. Each time a player acts, the change in V is "skill". Each time chance acts (cards), the change in V is "luck". The value at the very start is "position". Add them up and you get exactly what player j actually won, because each V cancels with the next one.
- Precise (paper's equations, ASCII; the sum is over the steps "h then a" that are prefixes of the terminal history z):
  - (5) `S_Vj(z) = sum over ha ⊑ z with P(h) ≠ c of ( V_j(ha) - V_j(h) )` (skill; steps where a player, not chance, acts)
  - (6) `L_Vj(z) = sum over ha ⊑ z with P(h) = c of ( V_j(ha) - V_j(h) )` (luck; chance steps)
  - (7) `P_Vj = V_j(∅)` (position: value of the empty history)
  - (8) advantage sum estimator `u^_Vj(z) = S_Vj(z) + P_Vj`
  - (9) `u_j(z) = S_Vj(z) + L_Vj(z) + P_Vj` (needs V_j(terminal) = u_j; our reading)
  - Zero-luck constraint: `E[ L_Vj(z) | σ ] = 0`.
  - (11) define V at chance nodes as `V_j(h) = sum_{a' in A(h)} f_c(a'|h) V_j(ha')` (f_c = chance probabilities), so (12) `L_Vj(z) = sum over chance steps of ( V_j(ha) - sum_{a'} f_c(a'|h) V_j(ha') )`.
- Footnote assumption (from the text): the chance player never acts twice in a row (a "trivial" condition the paper notes; text partly cut).

## Main results (empirical)
- Data: 2008 AAAI Computer Poker Competition (9 agents two-player limit, 4 two-player no-limit, 6 six-player limit) = "Bots-Bots"; plus one strong program vs weak-to-strong humans = "Bot-Humans". 450,000 training hands, 50,000 test hands.
- Features: hand strength (HS), hand-strength-squared (HS2), pot equity (PE, needs all hands), times pot size; quadratic cross-products in two-player games; DIVAT's value as an extra feature in "MIVAT+".
- Two-player limit, SD (units as in paper, likely small bets per hand; unsure), Table 1: Bot-Humans: MIVAT 2.387, MIVAT+ 2.220, DIVAT 2.238, Money 5.669. Bots-Bots: 2.542, 2.454, 2.506, 5.438. (Column order read from the garbled table header "MIVAT MIVAT+ DIVAT Money"; treat as approximately right.)
- Two-player no-limit ($1000 stacks in the competition), Table 3: MIVAT 32.407158 vs Money 42.339743.

## Assumptions and limitations
- Value function must be fixed before evaluating (learned on separate training data); otherwise unbiasedness can break.
- Skill includes every player's actions, so on its own it is not "your skill"; with a known-strategy bot use AIVAT's split.
- Hidden cards: features like pot equity need everyone's cards; per-decision verdicts built on those would depend on hidden cards (see E03/E04 for the fix).

## What is formally verified
Nothing machine-checked.

## Code artifacts and licenses
None linked in the paper text we saw.

## Relevance to our project
- Equation 9 is our seed theorem "EV plus luck equals the actual result", already stated in the literature. Citing it makes our Lean theorem easy to explain: "we machine-checked the MIVAT/AIVAT decomposition for the code that actually runs".
- Equation 11 tells us how to define the value at chance nodes so luck has mean zero: as the exact average over the next card. For the river and all-in, our engine can enumerate the remaining cards exactly.
- For the luck graph: plot cumulative position + skill (the "EV line") and cumulative actual result; the gap is cumulative luck, exactly.

## Candidate theorems for us
1. Skill + luck + position = actual, on every recorded hand.
   - Lean shape: `theorem skill_add_luck_add_position (z : RecordedHand) (V : Hist → Rat) (hT : V z.full = z.payoff) : skill V z + luck V z + V [] = z.payoff`
   - Estimate: 2 to 3 h (induction on the event list; telescoping).
2. Zero-luck at a chance node when V is defined by Equation 11.
   - Lean shape: `theorem zero_luck_step (h : Hist) (cards : List Card) (p : Card → Rat) (hp : (cards.map p).sum = 1) (V : Hist → Rat) (hV : V h = (cards.map fun c => p c * V (h ++ [c])).sum) : (cards.map fun c => p c * (V (h ++ [c]) - V h)).sum = 0`
   - Estimate: 1 to 2 h.
3. Uniform dealing: the deck's remaining-card probabilities sum to 1 (needed by 2).
   - Lean shape: `theorem deal_prob_sum (deck : List Card) (hne : deck ≠ []) : (deck.map fun _ => (1 : Rat) / deck.length).sum = 1`
   - Estimate: 0.5 to 1 h.
