# F01: Kyle (1985), "Continuous Auctions and Insider Trading"

## Summary

**Source:** Albert S. Kyle. "Continuous Auctions and Insider Trading." Econometrica 53(6), November 1985, pp. 1315-1335. https://doi.org/10.2307/1913210

TL;DR: A market with one insider who knows the asset's true value, noise traders who trade at random, and competitive risk-neutral market makers who see only the total order flow. The market makers set the price at the expected value given that order flow, so they earn zero on average. They cannot tell the insider's orders from the noise, so the noise is camouflage for the insider. The equilibrium is linear: price = p0 + λ × order flow, and 1/λ ("depth") is the order flow needed to move the price by one dollar. Market makers protect themselves from the insider's adverse selection by making the market less deep.

What matters for us:
- The reading of a river call as market making. The bettor is the insider (it knows its own hand). Its bluffs are the noise: bets that carry no strength and let the strong bets hide among them. The caller is the market maker: it sees only "a bet of this size" and must price it (call or fold at the pot odds on offer).
- Kyle's market makers are risk neutral and price at the conditional expectation. In our engine that is internal caution 0 (user Risk 50): the bot calls exactly when the call does not lose chips on average (`callPays` in `engine/Engine/Slider.lean`). Caution above 0 is a departure from Kyle; his market makers have no risk aversion.
- Nothing from this paper is computed by the engine. It supports the framing in `docs/THEORY.md`, nothing more.

Verdict: use (framing only).

## Citation

- Albert S. Kyle. "Continuous Auctions and Insider Trading." *Econometrica*, vol. 53, no. 6, November 1985, pp. 1315-1335. JSTOR stable 1913210, DOI 10.2307/1913210. Peer-reviewed journal article.
- Page range: the JSTOR cover sheet and Semantic Scholar give 1315-1335; the Econometric Society's own page gives 1315-1336. The scanned article ends on page 1335.

## URLs fetched (all fetched 2026-11-01)

- https://www.econometricsociety.org/publications/econometrica/1985/11/01/continuous-auctions-and-insider-trading : title, author, volume, issue, year and pages confirmed; abstract shown in part.
- https://api.semanticscholar.org/graph/v1/paper/DOI:10.2307/1913210 : title, author, year, journal, volume and pages confirmed; 9,732 citations listed; no abstract.
- https://edegan.com/pdfs/Kyle%20%281985%29%20-%20Continuous%20Auctions%20and%20Insider%20Trader.pdf : a JSTOR scan of the article with a text layer. Read as text (decompressed locally, saved only to a temp folder outside the repo). The abstract, section 1 and the statement of Theorem 1 were readable; Greek letters in the formulas are garbled in the text layer, so formula details below are as far as the words around them allow.
- https://www.jstor.org/stable/1913210 : not opened (script wall).

## Claim status

| Claim | Status |
|---|---|
| Three kinds of traders: a single risk-neutral insider, random noise traders, competitive risk-neutral market makers | Verified (abstract, read in the scan). |
| Market makers set prices equal to the expected liquidation value given the order flow they see ("efficiently, in the semi-strong sense"), so they earn zero profits on average | Verified (section 1). |
| Noise traders provide camouflage that lets the insider profit at their expense | Verified (section 1, quoted below). |
| Theorem 1: a unique equilibrium in which the insider's demand X and the pricing rule P are linear | Statement verified (section 2). Proof not checked by me. |
| 1/λ measures market depth, the order flow needed to move the price by one dollar, and is proportional to the ratio of noise trading to the insider's information | Verified (p. 1320). |
| "Market makers compensate themselves for bad trades due to the adverse selection of insiders by making the market less liquid" (Bagehot's intuition) | Verified (p. 1320, quoted). |
| In the continuous limit prices follow Brownian motion, depth is constant, and all private information is in prices by the end | Verified (abstract). |
| Anything machine-checked | No. Not looked for beyond this project; none expected. |

## Setting and definitions (plain words)

- One risky asset. Its final value v is random. The insider observes v before trading. Noise traders submit random orders. Market makers see only the total order y = insider order + noise order, and set one price for it.
- "Semi-strong efficient" here means: the price is the expected value of v given the order flow the market makers have seen. They earn zero expected profit on each auction.
- Depth: the order flow needed to move the price by one dollar. Tightness: the cost of turning around a position quickly. Resiliency: how fast prices recover from an uninformative shock. Kyle lists these three as the parts of "market liquidity" (section 1).

## Main results (as far as verified)

1. Theorem 1 (single auction): there is a unique linear equilibrium, P(y) = p0 + λ y for the market makers and X(v) = β (v − p0) for the insider, with λ and β fixed by the variance of v and the variance of the noise. One half of the insider's private information ends up in the price.
2. 1/λ is the depth of the market and is proportional to (noise trading) / (insider's information). More noise means a deeper market and more insider profit; the insider's profit is proportional to depth.
3. Sequential auctions converge, as the time between auctions goes to zero, to a continuous-time equilibrium with Brownian prices and constant depth.

Quote (section 1): "Since they cannot distinguish the trading of the insider from the trading of noise traders, the noise traders in effect provide camouflage which enables the insider to make profits at their expense."

## Assumptions and limitations

- Normal distributions, continuous quantities, a single insider who chooses how much to trade, risk-neutral market makers, no transaction costs.
- A poker bet has a fixed size and the caller has two answers (call or fold), not a continuous price. The analogy is about who knows what and who sets the terms, not about the formulas.

## What is formally verified

Nothing in the source.

## Code artifacts

None.

## Relevance to our project

- Gives the first half of the market-making reading in `docs/THEORY.md`: a river bet is an order from a possibly informed counterparty, and the caller is the market maker who must price it with only the order to go on.
- Risk 50 (internal caution 0) is Kyle's risk-neutral market maker. The other Risk values are not in Kyle's model.

## Candidate theorems for us

None. This source is background for the explanation, not a specification of the engine.
