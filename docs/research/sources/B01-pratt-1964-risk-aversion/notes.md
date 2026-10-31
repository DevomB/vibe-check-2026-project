# B01: Pratt (1964), "Risk Aversion in the Small and in the Large"

## Summary (also in summary.md)

TL;DR: Pratt's classic paper (Econometrica 32, 1964, pp. 122-136; peer-reviewed; abstract only seen, full text paywalled) defines the risk premium and the measure r(x) = -u''/u'. It shows that a higher r everywhere means a concave increasing transform of utility and a bigger risk premium for every gamble. Theorem wording verified through Kimball's open NBER paper w2848; the full list of equivalent conditions and the strict form are **unsure**.

- Use the derivative-free form: uB = G o uA with G concave and nondecreasing. Then "B strictly accepts a gamble over a sure amount implies A strictly accepts" follows from Jensen in 3 lines, over `Rat` and finite lotteries.
- Recommended slider family: quadratic utility u_r(x) = x - r x^2/(2M), r in [0,1], M = total chips. Exact in `Rat`, increasing on [0, M], bigger r = more risk-averse. Gain is a straight line in r, so the nesting theorem is short (3-5 h).
- Mean-variance is easy but rejects free rolls (fails dominance). CARA, CRRA and Kelly need exp/log, so they are not exact.
- The theorem covers risky-vs-sure choices (call/fold, shove/fold), not "bet small vs bet big".
- Quadratic utility gets more cautious as the stack grows. Disclose this.

Verdict: use. It is the exact theorem the Risk slider claims, and the discrete version is cheap to prove over `Rat`.

## Citation

- **Primary:** John W. Pratt, "Risk Aversion in the Small and in the Large", *Econometrica* 32(1/2), January 1964, pp. 122-136. JSTOR stable 1913738, DOI 10.2307/1913738. Peer-reviewed journal article.
- **Secondary, open (used for the theorem wording):** Miles S. Kimball, "Precautionary Saving in the Small and in the Large", NBER Working Paper w2848 (preprint / working paper; the journal version appeared in *Econometrica* 58(1), 1990, per common citation; **unsure**, I did not open the journal page).

## URLs fetched (all fetched 2026-10-31)

- https://www.econometricsociety.org/publications/econometrica/1964/01/01/risk-aversion-small-and-large : landing page opened. It shows title, author, volume 32, issue 1, pages 122-136, and the abstract. Full text needs a login. **I saw the abstract only.**
- https://www.jstor.org/stable/1913738 and https://doi.org/10.2307/1913738 : the DOI redirects to JSTOR; the JSTOR page did not load for the fetch tool (script wall). Not read.
- https://www.nber.org/papers/w2848.pdf : Kimball's open working paper, read as text (saved only to a temp folder outside the repo). It restates Pratt's two main results in words (see below).
- https://tse-fr.eu/sites/default/files/medias/doc/wp/2013/wp_idei_804.pdf : Gollier, Hammitt and Treich, "Risk and Choice: A Research Saga", IDEI working paper 804, July 2013. Read as text. Used only for context (it describes what Pratt's paper does; it does not restate Theorem 1).
- Citation count: not looked up (Semantic Scholar rate-limited me). Gollier et al. (2013) say the paper had "more than 5000 citations" on Google Scholar at that time; I did not check this myself.

## Claim status

| Claim | Status |
|---|---|
| For a small risk with mean 0 and variance s^2, the risk premium is about (s^2 / 2) * r(x), where r(x) = -u''(x)/u'(x) | Proved on paper (Pratt 1964). Wording verified via Kimball's restatement (his eq. 3). |
| If r1(x) >= r2(x) for all x, then u1 = g(u2) for some increasing concave g | Proved on paper (Pratt 1964). Verified via Kimball's restatement ("See Pratt (1964) for a proof"). |
| If r1(x) >= r2(x) for all x, then person 1's risk premium is at least person 2's for every wealth x and every risk ("in the large") | Proved on paper (Pratt 1964). Verified via Kimball's restatement. |
| The three conditions are *equivalent*, and there is also a strict ("strong") form | Proved on paper (Pratt 1964) as far as I recall. **Unsure: I could not open the paper, so I cannot confirm the exact list of conditions, their lettering, or the side conditions.** |
| The same measure was found independently by Arrow (1965) | Stated by Kimball and by Gollier et al.; I did not open Arrow's book. Arrow (1965) / (1971) is **UNVERIFIED** here. |
| Anything here is machine-checked | No. I found no proof-assistant version of Pratt's theorem (see B02, B03). |

## Setting and definitions

Plain words first.

- A **utility function** u says how much a person "likes" each amount of money. More money is better, so u is increasing.
- A **gamble** (or risk) is a random amount z added to your current wealth x.
- The **risk premium** pi(x, z) is the amount of sure money you would give up to get rid of the risk. Precisely: u(x + E[z] - pi) = E[u(x + z)]. So x + E[z] - pi is the sure amount you value the same as the gamble (the **certainty equivalent**).
- **Risk averse** means you would pay to avoid a fair gamble: pi > 0 when E[z] = 0. Under expected utility this is the same as u being concave (Gollier et al. 2013 state this as the "key and simple property").
- The **Arrow-Pratt measure** (local, absolute risk aversion) is r(x) = -u''(x) / u'(x). It needs u to be twice differentiable with u' > 0. It does not change if you rescale u by a positive constant or add a constant.
- "**In the small**" means for tiny gambles: Kimball restates Pratt as pi(x, e) = (s^2 / 2) * r(x) + o(s^2), for a small mean-zero risk e with variance s^2.
- "**In the large**" means for all gambles, of any size.

## Main results (as far as verified)

1. **Local formula.** For a small mean-zero risk with variance s^2: risk premium is about (s^2/2) * r(x). (Verified via Kimball.)
2. **Comparative theorem.** Given two utility functions u1, u2, if r1(x) >= r2(x) for all x, then
   - u1(x) = g(u2(x)) where g is increasing and concave, and
   - pi1(x, z) >= pi2(x, z) for every x and every risk z.
   (Verified via Kimball's restatement. Pratt's paper states these as equivalent conditions; the reverse directions and the strict version I could not check.)
3. **Abstract (verified):** the paper "concerns utility functions for money", discusses "a measure of risk aversion in the small, the risk premium or insurance premium for an arbitrary risk, and a natural concept of decreasing risk aversion", and also treats risks as a proportion of total assets (relative risk aversion).

## Assumptions and limitations

- Expected utility: the decision maker ranks gambles by E[u(wealth)]. Real people often violate this; Gollier et al. (2013) note this.
- The measure r(x) needs derivatives. Our code uses exact rationals and finite lotteries, so for us the **concave-transform form (u1 = g o u2, g concave increasing)** is the useful one: it needs no derivatives at all.
- The theorem compares a risky gamble against a **sure** amount. It does not say that a more risk-averse person always prefers the "safer" of two risky options. Kimball mentions Ross (1981) "strongly more risk averse" as the stronger notion needed for such comparisons (I did not open Ross 1981; **UNVERIFIED**). For poker this matters: call vs fold and shove vs fold are risky-vs-sure; "bet small vs bet big" is risky-vs-risky.

## What is formally verified

Nothing in this source. It is a paper proof. See B02 (Mathlib has Jensen's inequality, which is the engine of the discrete proof) and B03 (Isabelle has von Neumann-Morgenstern utility, but no risk aversion).

## Code artifacts and licenses

None.

## Relevance to our project

This is the theorem behind the **Risk slider**. Our claim "if bot B is more risk-averse than A, every gamble B accepts, A also accepts" is the "in the large" direction of Pratt's theorem, specialized to accepting a gamble instead of staying with a sure amount.

### Engineering constraint: exact rationals

exp, log and real powers cannot be computed exactly in Lean's `Rat`. So CARA (u = -exp(-a x)), CRRA (u = x^(1-g)/(1-g) or log x) and Kelly (log utility) are out for code we prove things about. Families that are exact in `Rat`:

| Family | Formula (x = final chips, w = current chips, X = chip change, M = total chips) | Bigger r = more risk-averse (Pratt sense)? | "B accepts => A accepts" for r_A <= r_B? | Respects "never worse" gambles (first-order dominance)? |
|---|---|---|---|---|
| Quadratic | u_r(x) = x - r x^2 / (2M), 0 <= r <= 1, x in [0, M] | Yes. r(x) = r / (M - r x), which grows with r. u_r is increasing on [0, M] because u_r'(x) = 1 - r x / M >= 0. | Yes (proof below). | Yes on [0, M], because u_r is increasing there. Chips are conserved, so final chips are always in [0, M]. |
| Concave piecewise-linear add-on | u_r(x) = x + r g(x), g fixed, concave, nondecreasing, piecewise linear (e.g. g(x) = min(x - k, 0)) | Yes. u_s = G o u_r with G piecewise linear; G's slopes are (1 + s a)/(1 + r a) over the slopes a of g, and these fall as a falls when s >= r, so G is concave and increasing. (My derivation, on paper; not checked.) | Yes (same proof). | Yes, u_r is increasing. |
| Loss penalty relative to current stack | score_r(X) = E[X] - r E[max(0, -X)] ("each chip lost counts 1 + r times") | Yes for one decision (it is the piecewise-linear case with kink at the current stack). But the reference point moves with the stack, so it is not one fixed utility over final chips. | Yes, trivially, because the penalty is >= 0. | Yes. |
| Mean-variance (Markowitz) | score_r(X) = E[X] - r Var(X) | Not expected utility, so the Pratt notion does not apply directly. | Yes, trivially (penalty >= 0). | **No.** Example: X = 0 or +100 chips, each with probability 1/2 (cannot lose). With r = 0.1: score = 50 - 0.1 * 2500 = -200 < 0, so the bot folds a free roll. |
| Mean-CVaR (see B06) | score_l(X) = (1 - l) E[X] + l * TailMean_a(X), l in [0, 1], TailMean_a = average of the worst a-share of outcomes | Not expected utility. | Yes, trivially (penalty E[X] - TailMean >= 0). | Yes, both parts are monotone. |
| CARA, CRRA, Kelly/log | need exp / log / real powers | Yes on paper | Yes on paper | Yes |
| | **Not exactly computable in Rat: reject for proved code.** | | | |

### Recommended family and the theorem it supports

**Quadratic utility on the bounded chip range**, u_r(x) = x - r x^2 / (2M), with M = total chips (1000 heads-up, 3000 six-handed) and the slider r in [0, 1] (as a `Rat`).

The gain from a gamble (finite lottery of (probability, chip change) pairs, probabilities >= 0 summing to 1) is

  Gain_r(w, L) = E[u_r(w + X)] - u_r(w) = E[X] - r * P(w, L),  where  P(w, L) = (2 w E[X] + E[X^2]) / (2M).

Two facts make the proof short:

1. Gain is **affine in r** (a straight line in r), and Gain_0 = E[X] (the risk-neutral bot).
2. **If the most cautious bot strictly accepts, the risk-neutral bot strictly accepts.** If Gain_s > 0 then E[X] (1 - s w / M) > (s / 2M) E[X^2] >= 0, so E[X] > 0. (This is Jensen's inequality for this particular u; here it reduces to E[X^2] >= 0.)

Then for 0 <= r <= s: if P <= 0, Gain_r >= E[X] > 0; if P > 0, Gain_r >= Gain_s > 0. So **every gamble the s-bot strictly accepts, the r-bot strictly accepts.** The non-strict version (">= 0") also holds for 0 <= r <= s <= 1 and 0 <= w <= M, with one extra case (s = 1, w = M forces X = 0 everywhere), so prove the strict version first.

Known side effect to disclose: the quadratic bot's Arrow-Pratt measure r / (M - r x) **grows with its stack** ("increasing absolute risk aversion"): it gets more cautious as it gets richer. That is a known oddity of quadratic utility. For a chip-capped game it is defensible, but say it plainly in the UI copy.

### The general discrete Pratt statement (if we want the textbook form)

For utilities uA, uB on chip amounts, with uB = G o uA where G is concave and nondecreasing on the range of uA: for every finite lottery L and stack w,

  E[uB(w + X)] > uB(w)  implies  E[uA(w + X)] > uA(w).

Proof sketch: suppose A does not strictly accept: E[uA(w + X)] <= uA(w). Jensen for concave G: E[G(uA(w + X))] <= G(E[uA(w + X)]). G nondecreasing: G(E[uA(w + X)]) <= G(uA(w)) = uB(w). So E[uB(w + X)] <= uB(w): B does not strictly accept either. For the non-strict version (">="), G must be strictly increasing.

## Candidate theorems for us

1. **Quadratic risk nesting (strict).** "If the more cautious bot would take this gamble rather than fold, the less cautious bot would too."
   ```lean
   theorem quad_accept_mono (M : ℚ) (hM : 0 < M) (r s w : ℚ) (L : Lottery)
       (hL : L.WellFormed) (hr : 0 ≤ r) (hrs : r ≤ s) (hs : s ≤ 1)
       (hw : 0 ≤ w ∧ w ≤ M) :
       0 < gainQuad M s w L → 0 < gainQuad M r w L
   ```
   `Lottery := List (ℚ × ℚ)` (probability, chip change); `gainQuad` must be the same function the bot calls. Estimate: 3-5 h (sum lemmas over lists, E[X^2] >= 0, then `nlinarith`).
2. **Risk-averse implies risk-neutral accepts** (the r = 0 case, a stand-alone lemma): 1-2 h.
3. **Discrete Pratt theorem** for any uA, uB = G o uA with G concave and monotone, over `ℚ`, using Mathlib `ConcaveOn.le_map_sum` (B02): 3-6 h, mostly bridging `List` lotteries to `Finset` sums.
4. **Quadratic is "more risk-averse" in Pratt's sense** (exists concave increasing G with u_s = G o u_r): skip; G needs a square root. Instead prove the piecewise-linear family version if wanted: 6-10 h.
5. **Spec rejects bad behaviour:** `¬ RespectsDominance meanVarianceScore`, by the free-roll example, with `decide`/`norm_num`: about 1 h. Shows why we did not use mean-variance.
6. **Satisfiable hypotheses:** an `example` with M = 1000, r = 1/2, s = 1, w = 500 and a concrete call-or-fold lottery: 0.5 h.
