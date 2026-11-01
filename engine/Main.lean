import Engine
import Engine.Protocol

/-!
# The game program: one JSON request per line in, one JSON reply per line out

The browser (through the Node bridge in `src/app/api/game/route.ts`) sends commands, and
this program answers with the table as the human may see it. All the work is in
`respond` (`Engine/Protocol.lean`), which runs the game session in
`Engine/Session.lean`; this file only reads and writes lines.
-/

open Lean Elab Term in
/-- The git commit this file is compiled from, as a string literal. It is `"unknown"` if git
fails, or if any file under `engine/` differs from that commit: then the program matches no
commit. Lake compiles this file again whenever the Lean code it imports changes. -/
elab "build_commit%" : term => do
  let dir := (System.FilePath.mk (← getFileName)).parent.getD "."
  let git (args : Array String) : IO (Option String) := do
    try
      let out ← IO.Process.output { cmd := "git", args, cwd := dir }
      pure (if out.exitCode == 0 then some out.stdout.trimAscii.toString else none)
    catch _ => pure none
  let commit ← git #["rev-parse", "--short", "HEAD"]
  let changes ← git #["status", "--porcelain", "--", "."]
  let value := match commit, changes with
    | some c, some "" => if c.isEmpty then "unknown" else c
    | _, _ => "unknown"
  pure (mkStrLit value)

/-- The commit this program was built from, sent in every state for the replay record
(MVP §5, §15). The web server's own checkout can be at a different commit. -/
def engineCommit : String := build_commit%

def main : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let session ← IO.mkRef (none : Option Session)
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break   -- end of input
    let line := line.trimAscii.toString
    if line.isEmpty then continue
    let (next, reply) := respond (← session.get) line engineCommit
    session.set next
    stdout.putStrLn reply.compress
    stdout.flush
