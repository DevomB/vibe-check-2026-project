#!/usr/bin/env python3
"""The learner's profile: where they are on the ladder, what they have done, what is due for review.

Stored at $VIBECHECK_HOME/profile.json (default ~/.vibecheck/profile.json), so it follows the
person across projects and sessions.

Usage:
  profile.py show [--json]                 summary, plus what is due for review today
  profile.py init --rung RUNG [--experience none|some|fluent] [--languages python,ts]
                  [--goal TEXT] [--cadence DAYS] [--project PATH]
  profile.py set KEY VALUE                 rung, experience, goal, cadence, project, minutes
  profile.py review TOPIC --result pass|struggled|fail
                                           record a drill or level; schedules the next review
  profile.py weak add|remove TOPIC         topics to bring back more often
  profile.py log MODE SUMMARY              one line per session
  profile.py due [--json]                  topics due for review today, most overdue first

Rungs: spec-existing, build-app, learn, refresh.
Topics are exercise levels (L1..L8) or free-form concept names ("induction generalizing").
"""
import argparse
import json
import os
import sys
from datetime import date, timedelta
from pathlib import Path

RUNGS = ("spec-existing", "build-app", "learn", "refresh")
EXPERIENCE = ("none", "some", "fluent")
# Review intervals in days. A pass moves one step out; struggling steps back; a fail restarts.
INTERVALS = [1, 3, 7, 14, 30, 60]


def home() -> Path:
    return Path(os.environ.get("VIBECHECK_HOME", Path.home() / ".vibecheck"))


def path() -> Path:
    return home() / "profile.json"


def load():
    p = path()
    if not p.exists():
        return None
    return json.loads(p.read_text())


def save(prof) -> None:
    p = path()
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(prof, indent=2) + "\n")


def today() -> str:
    return date.today().isoformat()


def need():
    prof = load()
    if prof is None:
        sys.exit("no profile yet: run `profile.py init --rung ...` after asking the user where they are")
    return prof


def due_list(prof):
    t = date.today()
    out = []
    for topic, rec in prof.get("topics", {}).items():
        d = date.fromisoformat(rec["next_due"])
        if d <= t:
            out.append({"topic": topic, "overdue_days": (t - d).days, "step": rec["step"],
                        "last_result": rec["history"][-1]["result"] if rec["history"] else None,
                        "weak": topic in prof.get("weak_spots", [])})
    out.sort(key=lambda x: (not x["weak"], -x["overdue_days"]))
    return out


def summary(prof):
    days_away = None
    if prof.get("last_session"):
        days_away = (date.today() - date.fromisoformat(prof["last_session"])).days
    done = sorted(t for t in prof.get("topics", {}) if t.startswith("L") and t[1:].isdigit())
    concepts = sorted(t for t in prof.get("topics", {}) if t not in done)
    week = (date.today() + timedelta(days=7)).isoformat()
    upcoming = sorted((rec["next_due"], t) for t, rec in prof.get("topics", {}).items()
                      if today() < rec["next_due"] <= week)
    return {
        "rung": prof.get("rung"),
        "experience": prof.get("experience"),
        "languages": prof.get("languages", []),
        "goal": prof.get("goal"),
        "project": prof.get("project"),
        "cadence_days": prof.get("cadence"),
        "minutes_per_session": prof.get("minutes"),
        "workspace_mode": prof.get("workspace_mode", "editor"),
        "learning_track": prof.get("learning_track", "exercises"),
        "project_level": prof.get("project_level"),
        "learning_file": prof.get("learning_file"),
        "last_session": prof.get("last_session"),
        "days_since_last_session": days_away,
        "levels_seen": done,
        "concepts_seen": concepts,
        "coming_up": [{"topic": t, "due": d} for d, t in upcoming],
        "lean_version": prof.get("lean_version"),
        "weak_spots": prof.get("weak_spots", []),
        "due": due_list(prof),
        "recent_sessions": prof.get("sessions", [])[-3:],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("show"); s.add_argument("--json", action="store_true")
    i = sub.add_parser("init")
    i.add_argument("--rung", required=True, choices=RUNGS)
    i.add_argument("--experience", choices=EXPERIENCE)
    i.add_argument("--languages", default="")
    i.add_argument("--goal")
    i.add_argument("--cadence", type=int)
    i.add_argument("--minutes", type=int)
    i.add_argument("--project")
    i.add_argument("--learning-track", choices=("api-check", "exercises"))
    st = sub.add_parser("set"); st.add_argument("key"); st.add_argument("value")
    r = sub.add_parser("review"); r.add_argument("topic")
    r.add_argument("--result", required=True, choices=("pass", "struggled", "fail"))
    w = sub.add_parser("weak"); w.add_argument("action", choices=("add", "remove")); w.add_argument("topic")
    lg = sub.add_parser("log"); lg.add_argument("mode"); lg.add_argument("summary")
    d = sub.add_parser("due"); d.add_argument("--json", action="store_true")
    a = ap.parse_args()

    if a.cmd == "init":
        prof = load() or {"version": 1, "created": today(), "topics": {}, "weak_spots": [], "sessions": []}
        prof.update({"rung": a.rung, "last_session": prof.get("last_session")})
        for k in ("experience", "goal", "cadence", "minutes", "project"):
            v = getattr(a, k)
            if v is not None:
                prof[k] = str(Path(v).expanduser().resolve()) if k == "project" else v
        if a.languages:
            prof["languages"] = [x.strip() for x in a.languages.split(",") if x.strip()]
        if a.learning_track:
            prof["learning_track"] = a.learning_track
        elif a.rung == "learn":
            prof.setdefault("learning_track", "api-check")
        save(prof)
        print(json.dumps(summary(prof), indent=2))
        return 0

    if a.cmd == "show":
        prof = load()
        if prof is None:
            print(json.dumps({"profile": None, "path": str(path())}) if a.json else
                  f"no profile at {path()}: ask the placement question, then `profile.py init`")
            return 0
        sm = summary(prof)
        if a.json:
            print(json.dumps(sm, indent=2))
            return 0
        print(f"rung: {sm['rung']}   experience: {sm['experience']}   languages: {', '.join(sm['languages']) or '-'}")
        pace = [f"{sm['minutes_per_session']} min sessions" if sm["minutes_per_session"] else "",
                f"every {sm['cadence_days']} days" if sm["cadence_days"] else "",
                f"Lean {sm['lean_version']}" if sm["lean_version"] else ""]
        if any(pace):
            print("   ".join(x for x in pace if x))
        if sm["goal"]:
            print(f"goal: {sm['goal']}")
        if sm["project"]:
            print(f"project: {sm['project']}")
        if sm["last_session"]:
            print(f"last session: {sm['last_session']} ({sm['days_since_last_session']} days ago)")
        if sm["levels_seen"]:
            print(f"levels seen: {', '.join(sm['levels_seen'])}")
        if sm["concepts_seen"]:
            print(f"concepts seen: {', '.join(sm['concepts_seen'])}")
        if sm["weak_spots"]:
            print(f"weak spots: {', '.join(sm['weak_spots'])}")
        if sm["due"]:
            print("due for review: " + ", ".join(
                f"{x['topic']}{' (weak)' if x['weak'] else ''}" for x in sm["due"]))
        if sm["coming_up"]:
            print("coming up this week: " + ", ".join(f"{x['topic']} ({x['due']})" for x in sm["coming_up"]))
        for s_ in sm["recent_sessions"]:
            print(f"  {s_['date']} [{s_['mode']}] {s_['summary']}")
        return 0

    prof = need()
    if a.cmd == "set":
        v = a.value
        if a.key in ("cadence", "minutes"):
            v = int(v)
        elif a.key == "rung" and v not in RUNGS:
            sys.exit(f"rung must be one of {RUNGS}")
        elif a.key == "experience" and v not in EXPERIENCE:
            sys.exit(f"experience must be one of {EXPERIENCE}")
        elif a.key == "project":
            v = str(Path(v).expanduser().resolve())
        elif a.key == "workspace_mode" and v not in ("chat", "editor"):
            sys.exit("workspace_mode must be chat or editor")
        elif a.key == "learning_track" and v not in ("api-check", "exercises"):
            sys.exit("learning_track must be api-check or exercises")
        elif a.key == "languages":
            v = [x.strip() for x in v.split(",") if x.strip()]
        prof[a.key] = v
    elif a.cmd == "review":
        rec = prof.setdefault("topics", {}).setdefault(a.topic, {"step": -1, "history": [], "next_due": today()})
        if a.result == "pass":
            rec["step"] = min(rec["step"] + 1, len(INTERVALS) - 1)
        elif a.result == "struggled":
            rec["step"] = max(rec["step"] - 1, 0)
        else:
            rec["step"] = 0
        rec["history"].append({"date": today(), "result": a.result})
        rec["next_due"] = (date.today() + timedelta(days=INTERVALS[rec["step"]])).isoformat()
        weak = prof.setdefault("weak_spots", [])
        if a.result != "pass" and a.topic not in weak:
            weak.append(a.topic)
        if a.result == "pass" and rec["step"] >= 3 and a.topic in weak:
            weak.remove(a.topic)
        prof["last_session"] = today()
        print(f"{a.topic}: {a.result}; next review {rec['next_due']}")
    elif a.cmd == "weak":
        weak = prof.setdefault("weak_spots", [])
        if a.action == "add" and a.topic not in weak:
            weak.append(a.topic)
        if a.action == "remove" and a.topic in weak:
            weak.remove(a.topic)
    elif a.cmd == "log":
        prof.setdefault("sessions", []).append({"date": today(), "mode": a.mode, "summary": a.summary})
        prof["last_session"] = today()
    elif a.cmd == "due":
        dl = due_list(prof)
        if a.json:
            print(json.dumps(dl, indent=2))
        else:
            print("\n".join(f"{x['topic']}  overdue {x['overdue_days']}d{'  weak' if x['weak'] else ''}"
                            for x in dl) or "nothing due")
        return 0
    save(prof)
    return 0


if __name__ == "__main__":
    sys.exit(main())
