import Engine
import Engine.Protocol

/-!
# The game program: one JSON request per line in, one JSON reply per line out

The browser (through the Node bridge in `src/app/api/game/route.ts`) sends commands, and
this program answers with the table as the human may see it. All the work is in
`respond` (`Engine/Protocol.lean`), which runs the game session in
`Engine/Session.lean`; this file only reads and writes lines.
-/

def main : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let session ← IO.mkRef (none : Option Session)
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break   -- end of input
    let line := line.trimAscii.toString
    if line.isEmpty then continue
    let (next, reply) := respond (← session.get) line
    session.set next
    stdout.putStrLn reply.compress
    stdout.flush
