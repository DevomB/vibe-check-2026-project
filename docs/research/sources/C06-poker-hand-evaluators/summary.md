# Summary: C06: Poker hand evaluators: HenryRLee/PokerHandEvaluator (perfect hash) and Cactus Kev's evaluator

**Source:** H. Lee. "PokerHandEvaluator" (Apache-2.0). https://github.com/HenryRLee/PokerHandEvaluator

TL;DR: Fast poker evaluators map every hand to one of 7,462 strength classes using lookup tables. Their correctness evidence is testing, not proof: PokerHandEvaluator compares itself with Cactus Kev's evaluator on every 5-, 6- and 7-card hand. I found no formally verified poker hand evaluator in any proof assistant. That is novelty for us.
- 7,462 = 6,175 non-flush rank patterns + 1,287 flush rank sets. Both evaluators depend only on (the ranks, flush or not). So an exhaustive check can run over 7,462 patterns instead of 2,598,960 hands, after one general "only ranks and flush matter" lemma.
- The honest Lean plan: a simple, readable reference evaluator (category + tie-break list) is the spec. If we want a fast one, prove it equal to the reference on the 7,462 patterns plus the general lemma. Kernel `decide` on 7,462 cases may be feasible; on 2.6M hands it is not (opinion).
- 7-card hands: define the 7-card value as the best of the 21 five-card subsets. Then 7-card correctness follows from the 5-card proof by construction; no 133,784,560-hand check is needed.
- Cactus Kev's page could not be opened (expired certificate). Its details are UNVERIFIED here.

Verdict: use. It gives the counts, the test strategy to copy, and confirms that a verified evaluator is new.


Full extraction: [notes.md](notes.md).
