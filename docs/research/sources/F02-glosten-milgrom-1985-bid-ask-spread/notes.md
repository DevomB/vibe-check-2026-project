# F02: Glosten and Milgrom (1985), "Bid, Ask and Transaction Prices in a Specialist Market with Heterogeneously Informed Traders"

## Summary

**Source:** Lawrence R. Glosten, Paul R. Milgrom. "Bid, Ask and Transaction Prices in a Specialist Market with Heterogeneously Informed Traders." Journal of Financial Economics 14(1), 1985, pp. 71-100. https://doi.org/10.1016/0304-405X(85)90044-3

TL;DR: A risk-neutral, competitive market maker (the "specialist") who makes zero expected profit still quotes a bid below and an ask above the expected value, purely because some customers know more than it does. The customer's willingness to trade at a quoted price is itself information: the ask is the expected value given that someone wants to buy at it, the bid the expected value given that someone wants to sell at it. The losses to informed traders are paid for by gains from uninformed "liquidity" traders. If informed traders are too many or too well informed, no quotes break even and the market shuts down.

What matters for us:
- This is the cleanest statement of "price the trade on what the counterparty's willingness to trade tells you". Our review does exactly that for a river call: it grades the call against the hands the bot would bet with on that board (`RiverSpot.botHands`, built from `riverBettingSet`), not against a random hand. The bettor's value hands are the informed trades; its bluffs are the liquidity trades that make calling pay.
- The bot itself does not do this when it calls: it uses its win chance against a random hand (`countsFor`), not against what the human's bet says. That is a known gap, disclosed in `docs/THEORY.md` and the README.
- Glosten and Milgrom's specialist is risk neutral. Our caution above 0 is a departure from their model, as it is from Kyle's (F01).
- Their "market shuts down" case is the poker case of a bettor who never bluffs: against it no bluff-catching call pays, and the right answer is to fold.

Verdict: use (framing only). Nothing from this paper is computed by the engine.

## Citation

- Lawrence R. Glosten and Paul R. Milgrom. "Bid, Ask and Transaction Prices in a Specialist Market with Heterogeneously Informed Traders." *Journal of Financial Economics*, vol. 14, no. 1, March 1985, pp. 71-100. DOI 10.1016/0304-405X(85)90044-3. Peer-reviewed journal article. The article says "Received August 1983, final version received September 1984".
- Search results also list an earlier version as Northwestern University CMSEMS Discussion Paper 570 (1983). Not opened: UNVERIFIED.

## URLs fetched (all fetched 2026-11-01)

- https://api.semanticscholar.org/graph/v1/paper/DOI:10.1016/0304-405X(85)90044-3 : title, authors, year, journal, volume and pages confirmed; 6,275 citations listed; no abstract.
- https://econpapers.repec.org/RePEc:eee:jfinec:v:14:y:1985:i:1:p:71-100 : seen in search results only (volume, issue, pages agree). Not opened directly.
- https://www.sciencedirect.com/science/article/pii/0304405X85900443 : HTTP 403. Not read.
- https://www.edegan.com/pdfs/Glosten%20Milgrom%20%281985%29%20-%20Bid%20Ask%20and%20Transaction%20Prices%20in%20a%20Specialist%20Market%20with%20Heterogeneously%20Informed%20Trades.pdf : a scan of the published article with a text layer. Read as text (decompressed locally, saved only to a temp folder outside the repo). The title page, abstract, introduction and Proposition 1 were readable; subscripts in formulas are garbled.
- https://ronming1303.github.io/documents/Glosten_Milgrom_1985_.pdf : turned out to be a student's summary notes (December 2024), not the paper. Not used.

## Claim status

| Claim | Status |
|---|---|
| Abstract (quoted below) | Verified, read in the scan. |
| The specialist is risk neutral, competitive, and makes zero expected profit on each transaction | Verified (section 1 and section 2). |
| The spread is "a purely informational phenomenon": it exists with zero transaction costs and zero inventory costs, because the specialist faces adverse selection | Verified (section 1, quoted below). |
| Proposition 1: if bid and ask prices satisfy the zero-profit conditions (ask = expected value given that a trader buys at the ask; bid = expected value given that a trader sells at the bid), then ask ≥ expected value ≥ bid, strictly when adverse selection is possible | Statement verified (section 2). Proof not checked by me. |
| The spread widens when insiders' information is better or insiders are more numerous relative to liquidity traders; the market can shut down | Verified (section 1). |
| Transaction prices follow a martingale; serial correlation of price changes depends on the share of the spread due to adverse selection | Stated in the abstract (verified). Details not read. |
| Anything machine-checked | No. |

Abstract, verbatim from the scan: "The presence of traders with superior information leads to a positive bid-ask spread even when the specialist is risk-neutral and makes zero expected profits. The resulting transaction prices convey information, and the expectation of the average spread squared times volume is bounded by a number that is independent of insider activity. The serial correlation of transaction price differences is a function of the proportion of the spread due to adverse selection. A bid-ask spread implies a divergence between observed returns and realizable returns. Observed returns are approximately realizable returns plus what the uninformed anticipate losing to the insiders."

Quote (section 1): "The core idea is that the specialist faces an adverse selection problem, since a customer agreeing to trade at the specialist's ask or bid price may be trading because he knows something that the specialist does not. In effect, then, the specialist must recoup the losses suffered in trades with the well informed by gains in trades with liquidity traders."

## Setting and definitions (plain words)

- One asset with an unknown final value V. Traders arrive one at a time. Each is either informed (knows something about V) or a liquidity trader (trades for reasons unrelated to V). The specialist cannot tell which is which.
- The specialist quotes an ask (price to buy from it) and a bid (price to sell to it). Zero expected profit means each quote equals the expected value of V given everything public plus the fact that this trader accepted that quote.
- Adverse selection: the trades the specialist gets are more often the bad ones for it, because informed traders only trade when the quote is wrong in their favour.

## Main results (as far as verified)

1. Proposition 1: with zero-profit quotes, ask ≥ E[V] ≥ bid, strictly when adverse selection is possible. The spread is positive without any cost or risk aversion.
2. The spread responds to the mix of traders: better-informed or more numerous insiders widen it. With too many insiders the market shuts down.
3. Prices are a martingale with respect to public information and converge towards full revelation over time (abstract and introduction).

## Assumptions and limitations

- Risk neutrality everywhere, one unit per trade, a competitive specialist, no inventory limits.
- In poker the "quote" is fixed by the bettor (the bet size and the pot), and the caller's only choice is to accept or not. So the caller is a specialist who cannot move its quote, only decide whether to trade at the quote it was given.

## What is formally verified

Nothing in the source.

## Code artifacts

None.

## Relevance to our project

- Justifies the review's model of the bot's hands: grade the call against the set of hands that would have bet (`RiverSpot.botHands`), because "the bot bet" is information, and the zero-profit rule says to price on it.
- Explains in plain words why bluffs are what makes calling worthwhile: the uninformed trades pay for the informed ones.
- Names a gap: the bot's own calls use equity against a random hand, not the conditional equity Glosten and Milgrom would use.

## Candidate theorems for us

None from this source. The theorems that already pin down the review's model are `review_worth`, `review_call_best_iff_equity` and `no_hindsight` (`engine/Checks/Challenge.lean`).
