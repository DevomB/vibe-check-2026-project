# F03: Avellaneda and Stoikov (2008), "High-frequency trading in a limit order book"

## Summary

**Source:** Marco Avellaneda, Sasha Stoikov. "High-frequency trading in a limit order book." Quantitative Finance 8(3), April 2008, pp. 217-224. https://doi.org/10.1080/14697680701381228

TL;DR: A dealer who posts bid and ask quotes maximizes the expected exponential utility of its profit at a final time. Exponential utility gives it a "reservation" (indifference) price: the price at which it does not care whether it holds one more share. That price sits below the market mid-price when the dealer is long and above it when short, by an amount that grows with the dealer's risk-aversion parameter, its inventory, the volatility and the time left. The optimal quotes are then set around the reservation price. As the risk-aversion parameter goes to zero, the strategy becomes the plain symmetric strategy around the mid-price; at a high value the dealer "will go to great lengths to avoid accumulating an inventory".

What matters for us:
- One parameter moves the dealer's indifference point away from the risk-neutral one, and at zero the risk-neutral rule comes back. Our loss weight does the same for one call: at internal caution 0 the bot calls when the call wins chips on average (plain pot odds), and each step of caution raises the equity it needs (`callPays` in `engine/Engine/Slider.lean`; at a pot-sized bet: 1/3 at caution 0, 1/2 at 50, 3/5 at 100).
- The mechanism is different and we must say so: Avellaneda and Stoikov use exponential (constant absolute risk aversion) utility over a continuous profit and an inventory that persists; we use a piecewise-linear penalty on lost chips, decided one bet at a time (see B01's table, row "loss penalty relative to current stack"). Only the role of the parameter is the same, not the formula.
- Nothing from this paper is computed by the engine. It supports the framing in `docs/THEORY.md`.

Verdict: use (framing only).

## Citation

- Marco Avellaneda and Sasha Stoikov. "High-frequency trading in a limit order book." *Quantitative Finance*, vol. 8, no. 3, April 2008, pp. 217-224. DOI 10.1080/14697680701381228. Peer-reviewed journal article. The article says "Received 24 April 2006; in final form 3 April 2007". A 2006 working-paper version circulated, which is why some sources cite it as 2006.

## URLs fetched (all fetched 2026-11-01)

- https://api.semanticscholar.org/graph/v1/paper/DOI:10.1080/14697680701381228 : title, authors, year, journal, volume and pages confirmed; 590 citations listed; no abstract.
- https://www.tandfonline.com/doi/abs/10.1080/14697680701381228 : HTTP 403. Not read.
- https://www.math.nyu.edu/~avellane/HighFrequencyTrading.pdf : the published article (journal header "Quantitative Finance, Vol. 8, No. 3, April 2008, 217-224"). Read as text (decompressed locally, saved only to a temp folder outside the repo). The prose of sections 1, 2.2, 2.3, 3.1 and 3.3 was readable. **Greek letters and most formula symbols did not survive the text extraction**, so the formulas below are marked by how they were checked.
- https://hummingbot.org/blog/technical-deep-dive-into-the-avellaneda--stoikov-strategy/ : a trading-software vendor's write-up of the model. Used only for the symbol-level form of the two formulas. It cites the paper as 2006 and gives no journal.

## Claim status

| Claim | Status |
|---|---|
| "The agent's objective is to maximize the expected exponential utility of his P&L profile at a terminal time T. This choice of convex risk measure is particularly convenient, since it will allow us to define reservation (or indifference) prices which are independent of the agent's wealth." | Verified, quoted from section 2.2 of the article. |
| Definition 1: the reservation bid price is the price that makes the agent indifferent between its current portfolio and its current portfolio plus one share; the reservation ask is defined the same way for one share less | Verified (section 2.2; the words, not the symbols). |
| When the agent is long, the reservation price is below the mid-price; when short, above it; the closer to the final time, the less risky the inventory | Verified (sections 2.2 and 2.3). |
| The optimal quotes come from a two-step procedure: solve the dynamic-programming equation for the reservation prices, then choose the distances from the mid-price by trading off execution probability against gain | Verified (section 3.1). |
| Objective, equation (13): u(s, x, q, t) = max E_t[ −exp( −γ (X_T + q_T S_T) ) ], with γ the risk-aversion parameter | Structure visible in the extracted text ("exp", "X_T + q_T S_T"); the symbol γ and the signs are taken from the vendor write-up and lecture slides. Symbol-level detail UNVERIFIED in the primary text. |
| Reservation price r = s − q γ σ² (T − t) | From the vendor write-up only. The article's prose confirms the direction and the dependence on inventory and time left, not the exact form. UNVERIFIED in the primary text. |
| Optimal total spread δa + δb = γ σ² (T − t) + (2/γ) ln(1 + γ/κ) | From the vendor write-up only; the article's extracted text shows the "ln(1 + ...)" fragments. UNVERIFIED in the primary text. |
| As the risk-aversion parameter goes to zero the inventory strategy and the symmetric strategy are identical; at a value of 1 the agent is "very risk averse" and avoids inventory, with lower variance and more modest profit | Verified in words (section 3.3); the parameter's symbol is garbled in the text. |
| Anything machine-checked | No. |

## Setting and definitions (plain words)

- The mid-price of the stock moves as a Brownian motion with volatility σ. The dealer holds cash x and q shares. It posts a bid and an ask; market orders hit them at rates that fall off with the distance from the mid-price.
- Exponential utility: the dealer values a profit W as −exp(−γ W). A bigger γ means it dislikes variance more. The reservation price is where the dealer is indifferent to one more share.
- Inventory risk: holding shares exposes the dealer to the mid-price moving. The paper's dealer is "one player in the market" and takes the mid-price as the true price; it does not model informed traders (that is Kyle, F01, and Glosten and Milgrom, F02).

## Main results (as far as verified)

1. Reservation prices exist and depend only on inventory, volatility, the risk-aversion parameter and the time left, not on wealth (section 2.2).
2. The optimal quotes are the reservation prices adjusted by a term that calibrates to how fast orders arrive at each distance (section 3.1, equations 18 and 19 in the article).
3. In simulations the inventory strategy has a much lower variance of profit than the symmetric strategy, at some cost in average profit; the gap grows with the risk-aversion parameter (section 3.3).

## Assumptions and limitations

- Continuous time, one share per order, no informed traders, exponential utility, a finite horizon.
- A poker call is one discrete decision with two answers and no inventory to carry. We borrow only the role of the parameter: a dial from "price at the plain expectation" to "demand a margin that grows with the dial".

## What is formally verified

Nothing in the source.

## Code artifacts

None used. Hummingbot's implementation of the strategy exists (open source) but we did not read its code.

## Relevance to our project

- Gives the third part of the market-making reading in `docs/THEORY.md`: the loss weight (1 + caution/50 per lost chip) plays the role of the dealer's risk-aversion parameter. At zero both reduce to risk-neutral pricing (Kyle's and Glosten and Milgrom's market maker); above zero both demand a margin.
- The theorem we have about this dial is the monotonicity one: at one decision, more caution never turns a fold into a call (`risk_monotone`, `botDecide_risk_monotone`, `more_risk_takes_fewer_gambles` in `engine/Checks/Challenge.lean`). Avellaneda and Stoikov prove nothing of that shape; the comparison is a reading.

## Candidate theorems for us

None from this source.
