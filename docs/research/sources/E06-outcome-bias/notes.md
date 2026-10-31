# E06: Outcome bias (Baron and Hershey 1988) and "Thinking in Bets" (Duke, book)

## Summary

**Source:** Baron, Hershey. "Outcome bias in decision evaluation." Journal of Personality and Social Psychology 54(4), 1988, pp. 569-579. https://doi.org/10.1037/0022-3514.54.4.569. A. Duke. Thinking in Bets (book, 2018).

TL;DR: Baron and Hershey showed in 5 studies that people rate the same decision as better, and the decider as more competent, when the outcome happened to be good, even though they agree outcomes should not matter. This is "outcome bias". Annie Duke's popular book makes the same point with poker examples.
- This is the scientific reason for our product: a review that grades decisions, not results, fixes a known human bias.
- Our proved property "verdicts never depend on hidden cards / on the outcome" is the formal antidote to outcome bias. Strong pitch line.
- The luck-vs-skill graph makes the bias visible: "you lost 40 bb but played +12 bb better than expected".
- Psychology, not math: nothing here to prove, only to cite.

Verdict: use (for the pitch and README motivation only; no theorems come from it directly).

## Citations
1. Jonathan Baron, John C. Hershey. "Outcome bias in decision evaluation." Journal of Personality and Social Psychology, 54(4), 569-579, April 1988. DOI 10.1037/0022-3514.54.4.569 (PubMed lists it as 10.1037//0022-3514.54.4.569). PMID 3367280.
   - Fetched 2026-10-31: https://pubmed.ncbi.nlm.nih.gov/3367280/ (record and abstract). The DOI link https://doi.org/10.1037/0022-3514.54.4.569 redirects to APA PsycNet, which only showed "Loading..." to our fetcher.
   - Source type: peer-reviewed journal article (empirical psychology).
   - Citation count: not looked up.
2. Annie Duke. "Thinking in Bets: Making Smarter Decisions When You Don't Have All the Facts." Portfolio (Penguin Random House). Hardcover, ebook and audio Feb 6, 2018; paperback May 7, 2019, ISBN 9780735216372.
   - Fetched 2026-10-31: https://penguinrandomhouse.com/books/552885/thinking-in-bets-by-annie-duke
   - Source type: popular book (opinion / non-academic). We read only the publisher's description, not the book.

## Claim status
| Claim | Status |
|---|---|
| People rate decisions better when outcomes are good (outcome bias) | Shown empirically (5 studies, undergraduate subjects), peer-reviewed. |
| In gambles, thinking was rated better when the option not chosen turned out badly | Shown empirically (per the abstract). |
| Subjects felt they should ignore outcomes but did not | Shown empirically (per the abstract). |
| Cause: outcomes change how salient the arguments on each side seem | Authors' suggested explanation (hypothesis), not established. |
| Good decisions can have bad outcomes; separate skill from luck | Opinion / popular advice (Duke). The publisher text mentions poker and "professional poker players"; it does not use the word "resulting" (we did not check the book itself). |

## Setting and definitions
- Outcome bias: judging the quality of a decision by how it turned out, instead of by what was known when it was made.
- Studies (from the abstract): subjects read descriptions and outcomes of decisions made by others under uncertainty, on medical matters or monetary gambles, then rated the quality of thinking, the decider's competence, and their own willingness to let the decider decide for them.

## Main results
- Better outcomes led to higher ratings of thinking quality and competence (all 5 studies, per abstract). No effect sizes copied (abstract only; numbers not seen).

## Assumptions and limitations
- Student subjects; vignette studies. Effect sizes not seen by us.
- Duke's book is advice, not evidence.

## What is formally verified
Nothing (psychology).

## Code artifacts and licenses
None.

## Relevance to our project
- Motivation for the whole "game review" idea: players blame or credit themselves for luck. Our review separates the two, with a proof that the grade cannot see the outcome or hidden cards.
- Pitch sentence (our words): "People judge decisions by results, a bias psychologists have measured since 1988. Our review is proved not to."
- Careful wording: we prove "the verdict depends only on what you could see when you decided". That is the precise, checkable version of "we don't judge by results".

## Candidate theorems for us
1. Outcome independence: the verdict for a decision is the same for every possible future runout and every possible bot hand consistent with what the human saw.
   - Lean shape: `theorem verdict_outcome_independent (s t : HandState) (a : Action) (hview : s.humanView = t.humanView) : verdict s a = verdict t a`
   - Estimate: 1 to 3 h (shared with E03/E04 theorem; same statement).
2. Bad-output example: a "results-oriented grader" (label by chips won) is rejected by the spec.
   - Lean shape: `example : ¬ (∀ s t, s.humanView = t.humanView → resultGrade s = resultGrade t) := by ...` with two concrete deals.
   - Estimate: 1 h.
