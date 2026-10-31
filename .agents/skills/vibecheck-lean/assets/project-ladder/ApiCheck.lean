/-! A runnable L1 API checker. Grow this file through the project ladder.
The I/O adapter is supplied; the learner develops and proves the pure policy.
At L1, healthy means HTTP 200. No retry or verification claim is made yet. -/

namespace ApiCheck

/-- The first policy: recognize one HTTP success status. -/
def isHealthy (status : Nat) : Bool := status == 200

/-- A finite timeout used by the actual curl invocation. -/
def timeoutSeconds : Nat := 5

/-- Keep each command argument separate, including the supplied URL. -/
def requestArgs (url : String) : Array String :=
  #["--silent", "--show-error", "--max-time", toString timeoutSeconds,
    "--output", "/dev/null", "--write-out", "%{http_code}", "--url", url]

/-- Interpret curl's status text independently of process execution. -/
def parseStatus (text : String) : Option Nat := text.trimAscii.toString.toNat?

end ApiCheck

/-- I/O adapter. Later milestones move further decisions into the pure core. -/
def main (args : List String) : IO UInt32 := do
  match args with
  | [url] =>
    let response ← IO.Process.output { cmd := "curl", args := ApiCheck.requestArgs url }
    if response.exitCode != 0 then
      IO.eprintln s!"request failed: {response.stderr.trimAscii}"
      return 2
    match ApiCheck.parseStatus response.stdout with
    | none =>
      IO.eprintln "curl returned no readable HTTP status"
      return 2
    | some status =>
      let healthy := ApiCheck.isHealthy status
      IO.println s!"HTTP {status}; healthy={healthy}"
      return if healthy then 0 else 1
  | _ =>
    IO.eprintln "usage: api-check URL"
    return 64
