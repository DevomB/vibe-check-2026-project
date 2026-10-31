#!/usr/bin/env python3
"""Differential test: the original implementation against the verified Lean port.

Edit the three marked places, then run from the Lean project root:
    lake build serve && python3 difftest.py 100000

Both sides get the same random inputs (biased toward edge values). Any
disagreement prints the input and both outputs and exits 1. A clean run prints
the number of inputs checked: put that number in the README.
"""
import json
import logging
import random
import subprocess
import sys

sys.dont_write_bytecode = True       # don't leave __pycache__ in the original repo
logging.disable(logging.CRITICAL)    # the original's logging would flood the output

# 1. Import the original code. Add its directory to sys.path if needed.
# sys.path.insert(0, "../original-repo")
# from shop.pricing import apply_coupon as original_apply_coupon
#
# If the original takes structured values, write a small adapter with the same
# argument shapes Serve.lean expects. JSON shapes on the Lean side:
#   Lean Int/Nat <-> number    Lean (a, b) <-> [a, b]    Lean Option <-> value or null
#   Lean List/Array <-> array  Lean String <-> string     structures: add `deriving FromJson, ToJson`
# Example: original checkout(cart: list[dict], coupon: dict | None) vs Lean
# checkout (cart : List (Int × Int)) (coupon : Option (Int × Int)):
#   def original_checkout(cart, coupon):
#       return checkout([{"price_cents": p, "qty": q} for p, q in cart],
#                       None if coupon is None else {"percent": coupon[0], "cap_cents": coupon[1]})


def original_transfer(a, b, amt):  # placeholder: delete once the real import works
    if amt <= a:
        return (a - amt, b + amt)
    return None


# 2. The Lean server binary built from Serve.lean.
LEAN_SERVER = [".lake/build/bin/serve"]


def edge_int(r: random.Random, lo: int, hi: int) -> int:
    """Uniform most of the time, boundary values 25% of the time."""
    if r.random() < 0.25:
        return r.choice([lo, lo + 1, hi - 1, hi, 0 if lo <= 0 <= hi else lo, (lo + hi) // 2])
    return r.randint(lo, hi)


# 3. One entry per function: (name in Serve.lean, input generator, original function).
CASES = [
    ("transfer", lambda r: (edge_int(r, 0, 10**6), edge_int(r, 0, 10**6), edge_int(r, 0, 10**6)),
     original_transfer),
]


def normalize(x):
    """Make Python values comparable with Lean's JSON (tuples become lists, None stays null)."""
    return json.loads(json.dumps(x))


class LeanServer:
    def __init__(self, cmd):
        self.p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)

    def call(self, fn, args):
        self.p.stdin.write(json.dumps({"fn": fn, "args": list(args)}) + "\n")
        self.p.stdin.flush()
        reply = json.loads(self.p.stdout.readline())
        if "error" in reply:
            raise RuntimeError(f"Lean server error for {fn}{tuple(args)}: {reply['error']}")
        return reply["ok"]

    def close(self):
        self.p.stdin.close()
        self.p.wait(timeout=10)


def main() -> int:
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 10_000
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    r = random.Random(seed)
    lean = LeanServer(LEAN_SERVER)
    try:
        for fn, gen, original in CASES:
            for i in range(n):
                args = gen(r)
                want = normalize(original(*args))
                got = lean.call(fn, args)
                if want != got:
                    print(f"MISMATCH {fn}{tuple(args)}\n  original: {want}\n  lean:     {got}")
                    return 1
            print(f"{fn}: {n} inputs, 0 mismatches (seed {seed})")
    finally:
        lean.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
