# When Lean is not the best tool for the weekend

Lean is the strongest general choice. A team verifying existing Rust, C or a
protocol design may get further with a tool built for that job. Offer these
when the Lean route would eat the whole weekend, and check the event rules
first: they may require Lean.

| Tool | Verifies | Style | Pick it when |
| --- | --- | --- | --- |
| [Dafny](https://dafny.org) | Its own language; compiles to C#, Java, Go, Python, JavaScript | Annotations checked by an SMT solver | Track A with the least proof writing |
| [Verus](https://github.com/verus-lang/verus) | Rust written in a verified subset | SMT-backed annotations inside Rust | New Rust code with proofs next to it |
| [Kani](https://github.com/model-checking/kani) | Existing Rust | Bounded model checking | Prove no panics or overflows up to a size bound, without porting |
| [F*](https://fstar-lang.org) | Its own language; extracts to C and OCaml | Dependent types plus SMT | Low-level or cryptographic code |
| [Frama-C](https://frama-c.com) / [CBMC](https://www.cprover.org/cbmc/) | Existing C | Deductive (WP) or bounded model checking | Existing C, without porting |
| [TLA+](https://lamport.azurewebsites.net/tla/tla.html) | Designs | Model checking state machines | Concurrency or protocol bugs in a design |
| [Rocq](https://rocq-prover.org) / [Isabelle](https://isabelle.in.tum.de) | Anything you can model | Interactive proof, like Lean | Someone on the team already knows it |
| Property-based testing (Hypothesis, fast-check, proptest) | Existing code | Random testing against a spec | Alongside a proof, never instead of one |

Rule of thumb: if the team's question is "how do I get my code into the
prover", consider Kani or Frama-C. If it is "how do I say what my code should
do", stay in Lean.
