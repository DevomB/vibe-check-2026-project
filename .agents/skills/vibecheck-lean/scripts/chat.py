#!/usr/bin/env python3
"""Spool and check Lean submitted in chat, keeping successful declarations.

chat.py --project DIR [--session NAME] [--file SOURCE | --code TEXT | < snippet.lean]
        [--context-file LESSON] [--fresh] [--reset] [--timeout SECONDS]
        [--run SOURCE --arg VALUE ... | --build] [--allow-io] [--format chat|json]

Each request saves source, compiler output and a result JSON under .vibecheck/chat/.
The agent reads the result and returns it in chat. No background service is needed.

Checking Lean runs it, so a submission that reaches outside Lean (commands, files,
environment, network) is refused unless --allow-io is given, and checks and runs
happen inside the OS sandbox where one is available (see guard.py).
"""
import argparse
import fcntl
import json
import os
import re
import signal
import subprocess
import sys
import time
import uuid
from pathlib import Path

from audit import CHEATS, strip_comments
from doctor import tool_paths
from guard import reaches_outside, sandboxed


def execute(project, source, session="default", fresh=False, timeout=30, build=False,
            run_program=False, run_args=(), context_file=None, allow_io=False):
    project = Path(project).expanduser().resolve()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", session):
        raise ValueError("session must contain only letters, digits, underscores or hyphens")
    if not (project / "lakefile.toml").exists() and not (project / "lakefile.lean").exists():
        raise ValueError("project must contain a lakefile.toml or lakefile.lean")
    if not source.strip() and not build:
        raise ValueError("submit a Lean snippet or use --reset")
    if timeout <= 0:
        raise ValueError("timeout must be positive")
    folder = project / ".vibecheck" / "chat" / session
    folder.mkdir(parents=True, exist_ok=True)
    context = folder / "Accepted.lean"
    with (folder / ".lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("this chat session is busy; wait for its current result") from None
        previous = context.read_text() if context.exists() and not fresh and not build and not run_program else ""
        base = ""
        if context_file is not None:
            context_file = Path(context_file).expanduser()
            if not context_file.is_absolute():
                context_file = project / context_file
            context_file = context_file.resolve()
            context_file.relative_to(project)
            base = context_file.read_text() + "\n"
        request = folder / (time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:12])
        request.mkdir()
        (request / "input.lean").write_text(source)
        prefix = base + previous + "\n"
        combined = prefix + source + "\n"
        first_line = prefix.count("\n") + 1
        submitted = request / "Submission.lean"
        submitted.write_text(combined)
        output_file = request / "output.txt"
        # Only the new source is checked: accepted context passed this check when it
        # was submitted, and a context file is the learner's own project file.
        reaches = [] if build or allow_io else reaches_outside(source)
        if reaches:
            result = {"status": "blocked", "accepted": False, "exit_code": None, "seconds": 0,
                      "command": None, "cwd": str(project), "request": str(request), "output": "",
                      "output_truncated": False, "shortcuts": [], "reaches": reaches, "sandbox": None,
                      "replayed_context": bool(previous), "fresh": fresh, "build": build,
                      "run": run_program, "context_file": str(context_file) if context_file else None}
            (request / "result.json").write_text(json.dumps(result, indent=2) + "\n")
            return result
        if build:
            command = ["lake", "build"]
        elif run_program:
            command = ["lake", "env", "lean", "--run", str(submitted), *run_args]
        else:
            command = ["lake", "env", "lean", "--json", str(submitted)]
        started = time.monotonic()
        tool_paths()
        launched, sandbox = command, None
        if not build:
            # Lake writes a missing manifest; create it before the sandbox closes the project.
            if not (project / "lake-manifest.json").exists():
                try:
                    subprocess.run(["lake", "env", "true"], cwd=project, capture_output=True, timeout=120)
                except (OSError, subprocess.TimeoutExpired):
                    pass
            launched, sandbox = sandboxed(command, project, request, allow_io)
        status, exit_code = "error", None
        with output_file.open("w") as output:
            try:
                process = subprocess.Popen(launched, cwd=project, stdout=output, stderr=subprocess.STDOUT,
                                           start_new_session=True)
                try:
                    exit_code = process.wait(timeout=timeout)
                    status = "checked" if exit_code == 0 else "error"
                except subprocess.TimeoutExpired:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    exit_code = process.wait()
                    status = "timeout"
            except OSError as error:
                output.write(str(error) + "\n")
        # A successful compiler exit alone does not establish a completed proof.
        clean = strip_comments(combined)
        shortcuts = [why for pattern, severity, why in CHEATS
                     if severity == "fail" and re.search(pattern, clean, re.MULTILINE)]
        if re.search(r"\b(?:admit|sorryAx)\b", clean):
            shortcuts.append("unfinished proof")
        # Preserve all compiler diagnostics on disk. Suppress only old informational
        # messages with a source position; never suppress warnings or errors.
        log, truncated, sorry_warning = "", False, False
        with output_file.open(errors="replace") as output:
            for line in output:
                sorry_warning |= bool(re.search(r"declaration uses ['`]sorry['`]", line))
                if (line.startswith("info: ") and
                        ("no previous manifest, creating one from scratch" in line or
                         line.strip() == "info: toolchain not updated; already up-to-date")):
                    continue
                rendered = line
                if not build and not run_program:
                    try:
                        message = json.loads(line)
                    except json.JSONDecodeError:
                        message = None
                    if isinstance(message, dict) and "severity" in message and "data" in message:
                        severity = message["severity"]
                        if severity == "information" and message.get("pos", {}).get("line", first_line) < first_line:
                            continue
                        rendered = ("" if severity == "information" else severity + ": ") + str(message["data"]) + "\n"
                truncated |= len(log) + len(rendered) > 16000
                log = (log + rendered)[-16000:]
        if status == "checked" and (shortcuts or sorry_warning):
            status = "incomplete"
        accepted = status == "checked" and not fresh and not build and not run_program
        if accepted:
            temporary = folder / "Accepted.tmp"
            temporary.write_text(previous + "\n" + source + "\n")
            temporary.replace(context)
        result = {"status": status, "accepted": accepted, "exit_code": exit_code,
                  "seconds": round(time.monotonic() - started, 3), "command": command,
                  "cwd": str(project), "request": str(request), "output": log,
                  "output_truncated": truncated, "shortcuts": shortcuts, "sandbox": sandbox,
                  "replayed_context": bool(previous), "fresh": fresh, "build": build,
                  "run": run_program, "context_file": str(context_file) if context_file else None}
        (request / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        return result


def render_chat(result):
    """Keep storage metadata out of the learner-facing command output."""
    if result["status"] == "reset":
        return "Lean context reset. Submission history kept."
    if result["status"] == "error" and "error" in result:
        return "Error: " + result["error"]
    if result["status"] == "blocked":
        lines = [f"  line {item['line']}: {item['reason']} ({item['text']})" for item in result["reaches"]]
        return ("Not run: this code reaches outside Lean.\n" + "\n".join(lines) +
                "\nRun it only if you wrote it or trust where it came from, with --allow-io.")
    if result["status"] == "timeout":
        heading = "Lean reached the execution time limit."
    elif result.get("run"):
        heading = f"Program exited with code {result['exit_code']}."
    else:
        heading = {"checked": "Lean checked and saved this snippet." if result.get("accepted") else "Lean checked this request.",
                   "incomplete": "Unfinished proof or proof shortcut detected.",
                   "error": "Lean reported an error.", "timeout": "Lean reached the execution time limit."}[result["status"]]
    output = result.get("output", "").strip()
    return heading + ("\n" + output if output else "")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--project", type=Path, required=True)
    ap.add_argument("--session", default="default")
    ap.add_argument("--file", type=Path, help="read the submitted Lean from a file instead of stdin")
    ap.add_argument("--code", help="submit a short Lean snippet directly")
    ap.add_argument("--context-file", type=Path, help="load the current project lesson before this snippet")
    ap.add_argument("--fresh", action="store_true", help="check a standalone snippet without changing accepted context")
    ap.add_argument("--reset", action="store_true", help="clear accepted context, keeping submission history")
    ap.add_argument("--build", action="store_true", help="spool lake build and its result instead of a snippet")
    ap.add_argument("--run", type=Path, help="run a Lean program file; never append it to accepted snippets")
    ap.add_argument("--arg", action="append", default=[], help="one program argument; may be repeated")
    ap.add_argument("--allow-io", action="store_true",
                    help="run code that reaches outside Lean; network and project writes allowed")
    ap.add_argument("--format", choices=("chat", "json"), default="chat")
    ap.add_argument("--timeout", type=float, default=30)
    args = ap.parse_args()
    try:
        project = args.project.expanduser().resolve()
        if args.reset:
            if args.file or args.code is not None or args.fresh or args.build or args.run or args.context_file or args.arg:
                raise ValueError("--reset cannot be combined with source, run or build options")
            if not re.fullmatch(r"[A-Za-z0-9_-]+", args.session):
                raise ValueError("invalid session name")
            folder = project / ".vibecheck" / "chat" / args.session
            folder.mkdir(parents=True, exist_ok=True)
            with (folder / ".lock").open("w") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                (folder / "Accepted.lean").unlink(missing_ok=True)
            result = {"status": "reset", "session": args.session}
            print(json.dumps(result) if args.format == "json" else render_chat(result))
            return 0
        if sum([args.file is not None, args.code is not None, args.run is not None, args.build]) > 1:
            raise ValueError("choose only one of --file, --code, --run or --build")
        if (args.build or args.run) and (args.fresh or args.context_file):
            raise ValueError("--run and --build cannot use --fresh or --context-file")
        if args.arg and not args.run:
            raise ValueError("--arg requires --run")
        if args.build:
            source = ""
        elif args.run or args.file:
            source_path = (args.run or args.file).expanduser()
            if not source_path.is_absolute():
                source_path = project / source_path
            source = source_path.read_text()
        else:
            source = args.code if args.code is not None else sys.stdin.read()
        result = execute(project, source, args.session, args.fresh, args.timeout, args.build,
                         bool(args.run), args.arg, args.context_file, args.allow_io)
    except (OSError, ValueError) as error:
        result = {"status": "error", "error": str(error)}
        print(json.dumps(result) if args.format == "json" else render_chat(result))
        return 1
    print(json.dumps(result, indent=2) if args.format == "json" else render_chat(result))
    return 0 if result["status"] == "checked" else 1


if __name__ == "__main__":
    sys.exit(main())
