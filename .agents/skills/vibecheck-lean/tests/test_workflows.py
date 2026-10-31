"""Behavior checks for setup planning and real chat-to-Lean execution."""
import importlib.util
from contextlib import redirect_stdout
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import chat
import doctor
import guard
import lesson

# Avoid a third-party module named setup when invoked by a test runner.
spec = importlib.util.spec_from_file_location("vibecheck_setup", SCRIPTS / "setup.py")
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)
profile_spec = importlib.util.spec_from_file_location("vibecheck_profile", SCRIPTS / "profile.py")
learner_profile = importlib.util.module_from_spec(profile_spec)
profile_spec.loader.exec_module(learner_profile)


@unittest.skipUnless(shutil.which("git"), "requires git")
class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        (self.source / "scripts").mkdir(parents=True)
        (self.source / "SKILL.md").write_text("test skill\n")
        (self.source / "scripts/chat.py").write_text("# installer fixture\n")
        for arguments in [["init", "-q"], ["add", "."],
                          ["-c", "user.name=Fixture", "-c", "user.email=fixture@localhost", "commit", "-qm", "Fixture"],
                          ["tag", "v0.2.1-event-preview"]]:
            subprocess.run(["git", *arguments], cwd=self.source, check=True, capture_output=True)
        self.home = self.root / "home with spaces"

    def install(self):
        return subprocess.run(["bash", str(SCRIPTS.parent / "install.sh"), "--home", str(self.home),
                               "--repo", str(self.source)], capture_output=True, text=True)

    def test_install_is_shared_and_keeps_local_changes_on_rerun(self):
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        target = self.home / ".agents/skills/vibecheck-lean"
        linked = self.home / ".claude/skills/vibecheck-lean"
        self.assertEqual(target.resolve(), linked.resolve())
        (target / "SKILL.md").write_text("learner's local changes\n")
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((target / "SKILL.md").read_text(), "learner's local changes\n")

    def test_conflicting_claude_installation_is_preserved_before_clone(self):
        conflict = self.home / ".claude/skills/vibecheck-lean"
        conflict.mkdir(parents=True)
        (conflict / "SKILL.md").write_text("existing skill\n")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((conflict / "SKILL.md").read_text(), "existing skill\n")
        self.assertFalse((self.home / ".agents/skills/vibecheck-lean").exists())


class ProfileTests(unittest.TestCase):
    def test_new_learners_default_to_a_project_without_marking_any_level_complete(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(learner_profile, "home", return_value=Path(directory)), \
                patch.object(sys, "argv", ["profile.py", "init", "--rung", "learn"]), \
                redirect_stdout(io.StringIO()):
            self.assertEqual(learner_profile.main(), 0)
            saved = learner_profile.load()
            self.assertEqual(saved["learning_track"], "api-check")
            self.assertEqual(saved["topics"], {})

    def test_returning_learners_keep_their_track_and_completed_work(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(learner_profile, "home", return_value=Path(directory)), \
                redirect_stdout(io.StringIO()):
            for arguments in [["init", "--rung", "learn", "--learning-track", "exercises"],
                              ["review", "L1", "--result", "pass"], ["init", "--rung", "learn"]]:
                with patch.object(sys, "argv", ["profile.py", *arguments]):
                    self.assertEqual(learner_profile.main(), 0)
            saved = learner_profile.load()
            self.assertEqual(saved["learning_track"], "exercises")
            self.assertEqual(saved["topics"]["L1"]["history"][-1]["result"], "pass")


class SetupTests(unittest.TestCase):
    def test_plan_orders_and_deduplicates_missing_requirements(self):
        report = {"checks": [
            {"key": key, "ok": False, "required": True, "fix": "bootstrap.sh " + step}
            for key, step in [("lake", "elan"), ("cargo-hax", "hax"), ("git", "prereqs"),
                              ("lean", "elan"), ("cargo", "rust"), ("uvx", "uv")]
        ]}
        self.assertEqual(setup.plan(report), (["prereqs", "elan", "uv", "rust", "hax"], []))

    def test_optional_missing_tools_do_not_trigger_installs(self):
        report = {"checks": [{"key": "editor", "ok": False, "required": False,
                              "fix": "bootstrap.sh vscode"}]}
        self.assertEqual(setup.plan(report), ([], []))

    def test_native_windows_blocks_application(self):
        report = {"checks": [{"key": "os", "ok": False, "required": True,
                              "fix": "Install WSL2", "detail": "native Windows"}]}
        self.assertEqual(setup.plan(report), ([], ["os: Install WSL2"]))

    def test_readiness_depends_on_functioning_lean_and_selected_mode(self):
        # Model installed executables with no GUI. A failed version probe must
        # still block setup even though the lean command exists on PATH.
        with patch.object(doctor, "tool_paths"), patch.object(doctor.shutil, "which", side_effect=lambda name: name), \
                patch.object(doctor.os.path, "samefile", return_value=False), \
                patch.object(doctor, "find_code", return_value=None), \
                patch.object(doctor, "run", side_effect=lambda cmd: None if cmd[0] == "lean" else "working"):
            report = doctor.inspect("chat")
        self.assertFalse(report["core_ready"])
        self.assertFalse(next(c for c in report["checks"] if c["key"] == "lean")["ok"])
        self.assertFalse(next(c for c in report["checks"] if c["key"] == "editor")["required"])

    def test_chat_can_be_ready_without_an_editor(self):
        with patch.object(doctor, "tool_paths"), patch.object(doctor.shutil, "which", return_value="/bin/sh"), \
                patch.object(doctor.os.path, "samefile", return_value=False), \
                patch.object(doctor, "find_code", return_value=None), \
                patch.object(doctor, "run", return_value="working"):
            self.assertTrue(doctor.inspect("chat")["core_ready"])
            self.assertFalse(doctor.inspect("editor")["core_ready"])

    def test_failed_installer_stops_before_later_steps(self):
        report = {"core_ready": False, "checks": [
            {"key": key, "ok": False, "required": True, "fix": "bootstrap.sh " + step}
            for key, step in [("git", "prereqs"), ("lean", "elan")]]}
        run = Mock(return_value=subprocess.CompletedProcess([], 7))
        with patch.object(sys, "argv", ["setup.py", "--apply"]), \
                patch.object(setup.doctor, "inspect", return_value=report), \
                patch.object(setup, "subprocess", SimpleNamespace(run=run)):
            self.assertEqual(setup.main(), 7)
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args[0][-1], "prereqs")


@unittest.skipUnless(shutil.which("lake") and shutil.which("lean"), "requires installed Lean and Lake")
class ChatIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        version = subprocess.check_output(["lean", "--version"], text=True)
        cls.toolchain = "leanprover/lean4:v" + re.search(r"version (\d+\.\d+\.\d+(?:-rc\d+)?)", version).group(1)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name)
        (self.project / "lakefile.toml").write_text('name = "chat-tests"\n')
        (self.project / "lean-toolchain").write_text(self.toolchain + "\n")

    def test_generated_project_has_portable_audit_and_ignores_private_runtime_files(self):
        result = subprocess.run([sys.executable, str(SCRIPTS / "new_project.py"), "release-example",
                                 "--dir", str(self.project)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        generated = self.project / "release-example"
        for name in ("README.md", "CLAUDE.md", "AGENTS.md"):
            content = (generated / name).read_text()
            self.assertNotIn(str(SCRIPTS.parent), content)
            self.assertNotIn(str(Path.home()), content)
            self.assertIn(".vibecheck/tools/audit.py", content)
        private = [".vibecheck/chat/example/output.txt", ".vibecheck/start.html",
                   ".vibecheck/progress.json", ".env"]
        ignored = subprocess.run(["git", "check-ignore", "--stdin"], cwd=generated,
                                 input="\n".join(private) + "\n", capture_output=True, text=True)
        self.assertEqual(set(ignored.stdout.splitlines()), set(private))
        retained = subprocess.run(["git", "check-ignore", ".vibecheck/tools/audit.py",
                                   ".vibecheck/spec.lock"], cwd=generated, capture_output=True, text=True)
        self.assertEqual(retained.returncode, 1)
        audited = subprocess.run([sys.executable, str(generated / ".vibecheck/tools/audit.py"),
                                  str(generated), "--json"], capture_output=True, text=True)
        self.assertEqual(audited.returncode, 0, audited.stdout + audited.stderr)
        self.assertTrue(json.loads(audited.stdout)["ok"])

    def test_eval_context_and_spooled_evidence(self):
        first = chat.execute(self.project, "def double (n : Nat) := n + n")
        self.assertEqual(first["status"], "checked")
        second = chat.execute(self.project, "#eval double 21")
        self.assertEqual(second["output"].strip(), "42")
        self.assertTrue(second["accepted"])
        self.assertTrue(second["replayed_context"])
        saved = json.loads((Path(second["request"]) / "result.json").read_text())
        self.assertEqual(saved, second)
        self.assertTrue((Path(first["request"]) / "input.lean").exists())
        third = chat.execute(self.project, "#eval double 4")
        self.assertEqual(third["output"].strip(), "8")
        self.assertNotIn("42", third["output"])

    def test_error_and_incomplete_proof_preserve_prior_context(self):
        chat.execute(self.project, "def x : Nat := 7")
        context = self.project / ".vibecheck/chat/default/Accepted.lean"
        before = context.read_text()
        error = chat.execute(self.project, "example : 1 = 2 := by rfl")
        self.assertEqual(error["status"], "error")
        self.assertIn("error", error["output"])
        incomplete = chat.execute(self.project, "example : 1 = 2 := by sorry")
        self.assertEqual(incomplete["status"], "incomplete")
        self.assertEqual(incomplete["exit_code"], 0)
        self.assertFalse(incomplete["accepted"])
        self.assertEqual(context.read_text(), before)

    def test_goal_output_and_complete_proof(self):
        result = chat.execute(self.project, "example (n : Nat) : n = n := by\n  trace_state")
        self.assertEqual(result["status"], "error")
        self.assertIn("⊢ n = n", result["output"])
        result = chat.execute(self.project, "example (n : Nat) : n = n := by\n  rfl")
        self.assertEqual(result["status"], "checked")

    def test_fresh_snippet_does_not_change_accepted_context(self):
        chat.execute(self.project, "def x : Nat := 7")
        context = self.project / ".vibecheck/chat/default/Accepted.lean"
        before = context.read_text()
        result = chat.execute(self.project, "def x : Nat := 9\n#eval x", fresh=True)
        self.assertEqual(result["status"], "checked")
        self.assertEqual(result["output"].strip(), "9")
        self.assertEqual(context.read_text(), before)

    def test_timeout_does_not_accept_snippet(self):
        result = chat.execute(self.project, "#eval IO.sleep 10000", timeout=0.1)
        self.assertEqual(result["status"], "timeout")
        self.assertFalse(result["accepted"])
        self.assertIsNotNone(result["exit_code"])
        self.assertFalse((self.project / ".vibecheck/chat/default/Accepted.lean").exists())

    def test_code_that_reaches_outside_lean_needs_allow_io(self):
        source = '#eval (IO.FS.writeFile "escaped.txt" "x" : IO Unit)'
        blocked = chat.execute(self.project, source)
        self.assertEqual(blocked["status"], "blocked")
        self.assertEqual(blocked["reaches"][0]["line"], 1)
        self.assertFalse((self.project / "escaped.txt").exists())
        self.assertIn("Not run: this code reaches outside Lean.", chat.render_chat(blocked))
        allowed = chat.execute(self.project, source, allow_io=True)
        self.assertEqual(allowed["status"], "checked", allowed["output"])
        self.assertTrue((self.project / "escaped.txt").exists())
        self.assertEqual(allowed["sandbox"], guard.available())

    def test_unsafe_session_path_is_rejected(self):
        with self.assertRaises(ValueError):
            chat.execute(self.project, "#eval 2", session="../../other")

    def test_reset_keeps_history_and_build_is_spooled(self):
        result = chat.execute(self.project, "def x : Nat := 7")
        reset = subprocess.run([sys.executable, str(SCRIPTS / "chat.py"), "--project", str(self.project),
                                "--reset"], capture_output=True, text=True)
        self.assertEqual(reset.returncode, 0)
        self.assertFalse((self.project / ".vibecheck/chat/default/Accepted.lean").exists())
        self.assertTrue(Path(result["request"]).exists())
        result = chat.execute(self.project, "", build=True)
        self.assertEqual(result["status"], "checked")
        self.assertFalse(result["accepted"])
        self.assertEqual(result["command"], ["lake", "build"])

    def test_chat_launch_copies_exercise_without_opening_windows(self):
        profile_home = self.project / "profile"
        profile_home.mkdir()
        (profile_home / "profile.json").write_text(json.dumps({"workspace_mode": "chat"}))
        result = subprocess.run([sys.executable, str(SCRIPTS / "launch.py"), "learn", "--project",
                                 str(self.project), "--level", "L1"], capture_output=True, text=True,
                                env=dict(os.environ, VIBECHECK_HOME=str(profile_home)))
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["mode"], "chat")
        self.assertNotIn("opened_editor", report)
        self.assertNotIn("opened_browser", report)
        self.assertTrue(Path(report["exercise"]).exists())
        self.assertIn("Paste Lean code", Path(report["start_page"]).read_text())
        self.assertTrue(report["lesson"].endswith("L1.md"))
        self.assertIn("Run one exercise now", Path(report["lesson_page"]).read_text())

    def test_context_file_uses_current_project_source_without_copying_it_into_history(self):
        lesson = self.project / "Lesson.lean"
        lesson.write_text("def configuredLimit : Nat := 3\n")
        first = chat.execute(self.project, "#eval configuredLimit", context_file=lesson)
        self.assertEqual(first["output"].strip(), "3")
        lesson.write_text("def configuredLimit : Nat := 4\n")
        second = chat.execute(self.project, "#eval configuredLimit", context_file=lesson)
        self.assertEqual(second["output"].strip(), "4")
        accepted = (self.project / ".vibecheck/chat/default/Accepted.lean").read_text()
        self.assertNotIn("def configuredLimit", accepted)
        self.assertIn("def configuredLimit : Nat := 4", (Path(second["request"]) / "Submission.lean").read_text())

    def test_compact_cli_works_from_a_relocated_skill_and_keeps_metadata_on_disk(self):
        installed = self.project / "installed skill" / "scripts"
        shutil.copytree(SCRIPTS, installed, ignore=shutil.ignore_patterns("__pycache__"))
        result = subprocess.run([sys.executable, str(installed / "chat.py"), "--project", str(self.project),
                                 "--code", '#eval "a; $(literal)"'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('"a; $(literal)"', result.stdout)
        self.assertNotIn('"accepted"', result.stdout)
        self.assertNotIn('"command"', result.stdout)
        records = list((self.project / ".vibecheck/chat/default").glob("*/result.json"))
        self.assertEqual(len(records), 1)
        self.assertEqual(json.loads(records[0].read_text())["exit_code"], 0)
        structured = subprocess.run([sys.executable, str(installed / "chat.py"), "--project", str(self.project),
                                     "--code", "#eval 7", "--format", "json"], capture_output=True, text=True)
        self.assertEqual(structured.returncode, 0, structured.stdout + structured.stderr)
        self.assertEqual(json.loads(structured.stdout)["output"].strip(), "7")

    def test_api_project_launch_preserves_the_learners_edits(self):
        command = [sys.executable, str(SCRIPTS / "launch.py"), "learn", "--project", str(self.project),
                   "--track", "api-check", "--mode", "chat"]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        lesson = Path(report["exercise"])
        edited = lesson.read_text() + "\n-- Learner's saved checkpoint\n"
        lesson.write_text(edited)
        result = subprocess.run(command + ["--level", "L2"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(lesson.read_text(), edited)
        self.assertNotIn("opened_browser", report)

    @unittest.skipUnless(shutil.which("curl"), "API adapter requires curl")
    def test_api_cli_runs_a_real_command_against_local_success_and_failure_fixtures(self):
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200 if self.path == "/healthy" else 503)
                self.end_headers()
                self.wfile.write(b"fixture response")

            def log_message(self, *args):
                pass

        server = HTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            source = (SCRIPTS.parent / "assets/project-ladder/ApiCheck.lean").read_text()
            root = f"http://127.0.0.1:{server.server_address[1]}"
            blocked = chat.execute(self.project, source, run_program=True, run_args=[root + "/healthy"])
            self.assertEqual(blocked["status"], "blocked")
            success = chat.execute(self.project, source, run_program=True, run_args=[root + "/healthy"],
                                   allow_io=True)
            self.assertEqual(success["exit_code"], 0, success["output"])
            self.assertIn("HTTP 200; healthy=true", success["output"])
            self.assertFalse(success["accepted"])
            failure = chat.execute(self.project, source, run_program=True, run_args=[root + "/error"],
                                   allow_io=True)
            self.assertEqual(failure["exit_code"], 1, failure["output"])
            self.assertIn("HTTP 503; healthy=false", failure["output"])
        finally:
            server.shutdown()
            thread.join(timeout=2)
            server.server_close()


class LessonTests(unittest.TestCase):
    def test_every_level_has_a_lesson_that_ends_on_a_real_exercise(self):
        for level in lesson.LEVELS:
            text = lesson.lesson_file(level).read_text()
            self.assertTrue(lesson.title_of(text).startswith(level), level)
            self.assertTrue(lesson.exercise_of(text).startswith("Exercise " + level[1]), level)

    def test_tree_branches_sit_under_their_pieces(self):
        code = "def double (n : Nat) : Nat := n + n"
        drawn = lesson.tree(code, [("def", "define"), ("(n : Nat)", "input"), ("n + n", "body")]).splitlines()
        self.assertEqual(drawn[0], code)
        self.assertEqual(lesson.tree_columns(drawn), [0, 11, 30])
        self.assertTrue(drawn[1].endswith("└─ body"))
        with self.assertRaises(ValueError):
            lesson.tree(code, [("n + n", "body"), ("def", "out of order")])

    def test_page_shows_progress_merges_one_liners_and_hides_answers(self):
        with tempfile.TemporaryDirectory() as directory:
            page = lesson.render("L2", Path(directory), {"topics": {"L1": {}}}).read_text()
        self.assertIn('class="chip done" href="L1.html">✓ L1', page)
        self.assertIn('class="chip here" href="L2.html">L2', page)
        self.assertIn("<details><summary>Answer</summary>", page)
        self.assertIn("✗ Lean rejects this", page)
        self.assertIn("<b>Lean says:</b> omega could not prove the goal", page)

    @unittest.skipUnless(lesson.lean_cmd(), "requires installed Lean")
    def test_every_example_does_what_its_lesson_says(self):
        for level in lesson.LEVELS:
            result = lesson.check(level)
            self.assertTrue(result["ok"], f"{level}: {result['problems']}")


class GuardTests(unittest.TestCase):
    def test_bundled_lessons_and_exercises_pass_the_gate(self):
        root = SCRIPTS.parent / "assets"
        for path in [*root.glob("exercises/**/*.lean"), root / "bridge/Bridge.lean"]:
            self.assertEqual(guard.reaches_outside(path.read_text()), [], path)
        for level in lesson.LEVELS:
            for block in lesson.blocks(lesson.lesson_file(level).read_text()):
                if block[0] == "fence" and block[1] == "lean":
                    self.assertEqual(guard.reaches_outside("\n".join(block[3])), [], level)
        flagged = guard.reaches_outside((root / "project-ladder/ApiCheck.lean").read_text())
        self.assertEqual([(item["line"], item["text"]) for item in flagged], [(27, "IO.Process")])

    def test_gate_sees_through_namespaces_and_ignores_comments(self):
        cases = {'open IO.Process in\n#eval run { cmd := "sh" }': "open IO.Process",
                 'open IO in\n#eval FS.readFile "x"': "FS.readFile",
                 "run_cmd pure ()": "run_cmd",
                 "#eval unsafeBaseIO (pure 1)": "unsafeBaseIO",
                 '@[extern "system"] opaque sys : Nat': "@[extern",
                 '#eval IO.getEnv "TOKEN"': "getEnv"}
        for source, text in cases.items():
            self.assertIn(text, [item["text"] for item in guard.reaches_outside(source)], source)
        self.assertEqual(guard.reaches_outside("-- IO.Process\n/- run_cmd -/\ndef unsafeTake := 1"), [])

    @unittest.skipUnless(guard.available(), "no OS sandbox on this machine")
    def test_sandbox_limits_writes_and_network(self):
        # A project outside the temp folder, so only .lake and the request stay writable.
        with tempfile.TemporaryDirectory(dir=Path.home(), prefix=".vibecheck-test-") as folder:
            project, request = Path(folder), Path(folder) / ".vibecheck/chat/x/1"
            (project / ".lake").mkdir()
            request.mkdir(parents=True)

            def run(script, allow_io=False):
                command, _ = guard.sandboxed(["sh", "-c", script], project, request, allow_io)
                return subprocess.run(command, cwd=project, capture_output=True).returncode

            self.assertNotEqual(run("echo x > Escaped.lean"), 0)
            self.assertEqual(run("echo x > .lake/ok && echo x > .vibecheck/chat/x/1/ok"), 0)
            self.assertEqual(run("echo x > Escaped.lean", allow_io=True), 0)
            server = HTTPServer(("127.0.0.1", 0), BaseHTTPRequestHandler)
            thread = threading.Thread(target=server.handle_request, daemon=True)
            thread.start()
            try:
                port = server.server_address[1]
                probe = f"exec 3<>/dev/tcp/127.0.0.1/{port}" if shutil.which("bash") else "false"
                fetch = lambda allow_io: run(f"bash -c '{probe}'", allow_io)
                self.assertNotEqual(fetch(False), 0)
                self.assertEqual(fetch(True), 0)
            finally:
                server.server_close()


if __name__ == "__main__":
    unittest.main()
