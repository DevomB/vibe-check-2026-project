#!/usr/bin/env python3
"""Plan missing dependencies; --apply installs them and checks readiness again."""
import argparse
import json
import subprocess
import sys
from pathlib import Path

import doctor


def plan(report):
    steps, blocked = [], []
    for check in report["checks"]:
        if check["ok"] or not check["required"]:
            continue
        fix = check.get("fix") or ""
        if fix.startswith("bootstrap.sh "):
            step = fix.split()[1]
            if step not in steps:
                steps.append(step)
        else:
            blocked.append(f"{check['key']}: {fix or check['detail']}")
    order = ("prereqs", "elan", "vscode", "uv", "rust", "hax", "node")
    return [step for step in order if step in steps], blocked


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--rung", choices=("learn", "refresh", "build-app", "spec-existing"), default="learn")
    ap.add_argument("--mode", choices=("chat", "editor"), default="chat")
    ap.add_argument("--rust", action="store_true")
    ap.add_argument("--node", action="store_true")
    ap.add_argument("--apply", action="store_true", help="execute the authorized installation plan")
    args = ap.parse_args()
    report = doctor.inspect(args.mode, args.rung, args.rust, args.node)
    steps, blocked = plan(report)
    print(json.dumps({"mode": args.mode, "rung": args.rung, "steps": steps,
                      "blocked": blocked, "ready": report["core_ready"]}), flush=True)
    if not args.apply:
        return 0
    if blocked:
        return 1
    bootstrap = Path(__file__).with_name("bootstrap.sh")
    for step in steps:
        result = subprocess.run(["bash", str(bootstrap), step])
        if result.returncode:
            return result.returncode
        doctor.tool_paths()
    report = doctor.inspect(args.mode, args.rung, args.rust, args.node)
    print(json.dumps({"ready": report["core_ready"], "remaining": [c for c in report["checks"]
                                                                    if c["required"] and not c["ok"]]}))
    return 0 if report["core_ready"] else 1


if __name__ == "__main__":
    sys.exit(main())
