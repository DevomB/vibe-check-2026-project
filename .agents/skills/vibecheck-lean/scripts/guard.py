#!/usr/bin/env python3
"""Limit what submitted Lean can do while it is checked or run.

Lean executes code while it checks a file (`#eval`, `run_cmd`, `initialize`,
custom elaborators), so checking untrusted Lean means running it. Two layers:

- `reaches_outside(source)`: a text check for the ways a snippet reaches the
  system (processes, files, environment, network, metaprogramming that builds
  code from data). It stops accidents and simple injection, not a determined
  author, which is why the second layer exists.
- `sandboxed(command, ...)`: wrap the command in the operating system's
  sandbox when one is available (sandbox-exec on macOS, bubblewrap on Linux):
  no network, writes only to the build folder, the request folder and temp,
  and no reading of credential folders. `allow_io` opens the network and the
  project folder for programs the user wrote, such as the API checker.

python3 guard.py check FILE   report what a file reaches, exit 1 if anything
python3 guard.py status       name the sandbox available on this machine
"""
import functools
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from audit import strip_comments

REACHES = [
    (r"\bIO\.(?:Process|FS)\b|\b(?:Process|FS)\.[A-Za-z]\w*", "runs a command or touches files"),
    (r"\b(?:open|export)\b[^\n]*\b(?:Process|FS)\b", "opens the process or file namespace"),
    (r"\bgetEnv\b", "reads environment variables"),
    (r"\bStd\.(?:Net|Internal)\b|\b(?:Net|Internal)\.[A-Z]", "uses the network or runtime internals"),
    (r"\b(?:run_cmd|run_elab|run_meta|run_tac)\b", "runs metaprogram code while checking"),
    (r"\b(?:builtin_)?initialize\b", "runs code when the file is loaded"),
    (r"@\[[^\]]*\b(?:extern|implemented_by)\b", "replaces a definition with outside code"),
    (r"\bunsafe(?:IO|BaseIO|EIO|PerformIO|Cast)?\b", "skips Lean's safety checks"),
    (r"\b(?:evalConst\w*|runParserCategory|elabCommand\w*|evalTerm|evalExpr)\b",
     "builds and runs code from data"),
]

# Credential folders and files under the home folder that checked code never needs.
SECRETS = (".ssh", ".aws", ".gnupg", ".config/gh", ".config/gcloud", ".azure", ".kube",
           ".docker", ".netrc", ".git-credentials", ".npmrc", ".pypirc", "Library/Keychains")


def reaches_outside(source):
    """Return [{"line", "reason", "text"}] for each construct that reaches the system."""
    clean = strip_comments(source)
    found = []
    for pattern, reason in REACHES:
        for match in re.finditer(pattern, clean):
            line = clean.count("\n", 0, match.start()) + 1
            found.append({"line": line, "reason": reason, "text": match.group(0).strip()})
    return sorted(found, key=lambda item: item["line"])


@functools.lru_cache(maxsize=None)
def available():
    """The sandbox this machine supports, or None. Off when VIBECHECK_SANDBOX=off."""
    if os.environ.get("VIBECHECK_SANDBOX", "").lower() in ("off", "0", "no"):
        return None
    probes = {"sandbox-exec": ["sandbox-exec", "-p", "(version 1)(allow default)(deny network*)", "true"],
              "bwrap": ["bwrap", "--ro-bind", "/", "/", "--dev", "/dev", "--unshare-net", "true"]}
    for name, probe in probes.items():
        if shutil.which(name):
            try:
                if subprocess.run(probe, capture_output=True, timeout=10).returncode == 0:
                    return name
            except (OSError, subprocess.TimeoutExpired):
                pass
    return None


def _secrets():
    home = Path.home()
    return [home / name for name in SECRETS if (home / name).exists()]


def _quote(path):
    return '"' + str(path).replace("\\", "\\\\").replace('"', '\\"') + '"'


def sandboxed(command, project, request, allow_io=False):
    """Return (command wrapped in the sandbox, sandbox name or None)."""
    name = available()
    project, request = Path(project).resolve(), Path(request).resolve()
    writable = [project if allow_io else project / ".lake", request,
                Path(tempfile.gettempdir()).resolve(), Path("/tmp").resolve()]
    if name == "sandbox-exec":
        rules = ["(version 1)", "(allow default)", "(deny file-write*)",
                 "(allow file-write* (subpath \"/dev\") "
                 + " ".join(f"(subpath {_quote(path)})" for path in writable) + ")"]
        if not allow_io:
            rules.append("(deny network*)")
        rules += [f"(deny file-read* (subpath {_quote(path.resolve())}))" for path in _secrets()]
        return ["sandbox-exec", "-p", "\n".join(rules), *command], name
    if name == "bwrap":
        wrapped = ["bwrap", "--ro-bind", "/", "/", "--dev", "/dev", "--proc", "/proc", "--die-with-parent"]
        for path in dict.fromkeys(writable):
            if path.exists():
                wrapped += ["--bind", str(path), str(path)]
        if not allow_io:
            wrapped.append("--unshare-net")
        for path in _secrets():
            wrapped += ["--tmpfs", str(path)] if path.is_dir() else ["--ro-bind", "/dev/null", str(path)]
        return wrapped + ["--chdir", str(project), *command], name
    return list(command), None


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "status":
        print(json.dumps({"sandbox": available()}))
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == "check":
        found = reaches_outside(Path(sys.argv[2]).read_text())
        print(json.dumps(found, indent=2))
        return 1 if found else 0
    print("usage: guard.py check FILE | guard.py status", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
