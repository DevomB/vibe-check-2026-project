/-! # Level 8: a verified compiler

The classic capstone: compile arithmetic expressions to a stack machine and prove
that running the compiled code computes the same value as evaluating the
expression. The key is a lemma generalized over the rest of the program and the
stack. Finish this and you have proved a compiler correct. -/

inductive Expr where
  | num : Nat → Expr
  | add : Expr → Expr → Expr
  | mul : Expr → Expr → Expr

def Expr.eval : Expr → Nat
  | .num n => n
  | .add a b => a.eval + b.eval
  | .mul a b => a.eval * b.eval

inductive Instr where
  | push : Nat → Instr
  | add
  | mul

def exec : List Instr → List Nat → List Nat
  | [], s => s
  | .push n :: is, s => exec is (n :: s)
  | .add :: is, b :: a :: s => exec is ((a + b) :: s)
  | .mul :: is, b :: a :: s => exec is ((a * b) :: s)
  | _ :: is, s => exec is s

def compile : Expr → List Instr
  | .num n => [.push n]
  | .add a b => compile a ++ compile b ++ [.add]
  | .mul a b => compile a ++ compile b ++ [.mul]

#eval exec (compile (.add (.num 2) (.mul (.num 3) (.num 4)))) []  -- [14]

-- Exercise 8.1: the generalized lemma.
theorem exec_compile (e : Expr) (rest : List Instr) (s : List Nat) :
    exec (compile e ++ rest) s = exec rest (e.eval :: s) := by
  induction e generalizing rest s with
  | num n => simp [compile, exec, Expr.eval]
  | add a b iha ihb => simp [compile, List.append_assoc, iha, ihb, exec, Expr.eval]
  | mul a b iha ihb => simp [compile, List.append_assoc, iha, ihb, exec, Expr.eval]

-- Exercise 8.2: the headline theorem.
theorem compile_correct (e : Expr) : exec (compile e) [] = [e.eval] := by
  have := exec_compile e [] []
  simpa [exec] using this
