# Summary: B01: Pratt (1964), "Risk Aversion in the Small and in the Large"


TL;DR: Pratt's classic paper (Econometrica 32, 1964, pp. 122-136; peer-reviewed; abstract only seen, full text paywalled) defines the risk premium and the measure r(x) = -u''/u'. It shows that a higher r everywhere means a concave increasing transform of utility and a bigger risk premium for every gamble. Theorem wording verified through Kimball's open NBER paper w2848; the full list of equivalent conditions and the strict form are **unsure**.

- Use the derivative-free form: uB = G o uA with G concave and nondecreasing. Then "B strictly accepts a gamble over a sure amount implies A strictly accepts" follows from Jensen in 3 lines, over `Rat` and finite lotteries.
- Recommended slider family: quadratic utility u_r(x) = x - r x^2/(2M), r in [0,1], M = total chips. Exact in `Rat`, increasing on [0, M], bigger r = more risk-averse. Gain is a straight line in r, so the nesting theorem is short (3-5 h).
- Mean-variance is easy but rejects free rolls (fails dominance). CARA, CRRA and Kelly need exp/log, so they are not exact.
- The theorem covers risky-vs-sure choices (call/fold, shove/fold), not "bet small vs bet big".
- Quadratic utility gets more cautious as the stack grows. Disclose this.

Verdict: use. It is the exact theorem the Risk slider claims, and the discrete version is cheap to prove over `Rat`.


Full extraction: [notes.md](notes.md).
