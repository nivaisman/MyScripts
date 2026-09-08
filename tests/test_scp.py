"""Exercise the complete interactive wrapper with a no-network fake scp."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "Shell-scripts" / "scp.sh"


class TransferTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "scp-arguments.jsonl"
        self.local = self.root / "report.txt"
        self.local.write_text("LOCAL_ORIGINAL\n", encoding="utf-8")
        fake_scp = self.bin / "scp"
        fake_scp.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "with open(os.environ['SCP_LOG'], 'a', encoding='utf-8') as log:\n"
            "    log.write(json.dumps(sys.argv[1:]) + '\\n')\n"
            "# Emulate writes only to the explicit disposable test destination.\n"
            "target = os.environ.get('MOCK_DOWNLOAD_TARGET')\n"
            "if target and sys.argv[-1] == target:\n"
            "    with open(target, 'w', encoding='utf-8') as output:\n"
            "        output.write('REMOTE_REPLACEMENT\\n')\n"
            "sys.exit(int(os.environ.get('SCP_STATUS', '0')))\n",
            encoding="utf-8",
        )
        fake_scp.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update(
            PATH=f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            SCP_LOG=str(self.log),
            SCP_STATUS="0",
            MOCK_DOWNLOAD_TARGET="",
        )

    def inputs(self, direction="Upload", answer="y", local=None,
               remote="/remote/report.txt", user="reviewer",
               host="example.invalid", remote_os="2", local_os="2"):
        local = str(self.local) if local is None else str(local)
        paths = [remote, local] if direction == "Download" else [local, remote]
        return [
            local_os, remote_os, "1" if direction == "Download" else "2",
            *paths, user, host, answer,
        ]

    def run_script(self, lines, **env):
        self.log.unlink(missing_ok=True)
        return subprocess.run(
            ["bash", str(SCRIPT)],
            input="\n".join(lines) + ("\n" if lines else ""),
            text=True,
            capture_output=True,
            env={**self.env, **env},
            timeout=5,
            check=False,
        )

    def calls(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def assert_rejected(self, lines):
        result = self.run_script(lines)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls(), [], result.stdout + result.stderr)

    def test_confirmation_direction_matrix(self):
        for direction in ("Download", "Upload"):
            for answer in ("y", "Y", "n", "N"):
                with self.subTest(direction=direction, answer=answer):
                    result = self.run_script(self.inputs(direction, answer))
                    self.assertEqual(result.returncode, 0, result.stderr)
                    if answer.lower() == "n":
                        self.assertEqual(self.calls(), [])
                        continue
                    remote = "reviewer@example.invalid:/remote/report.txt"
                    operands = [remote, str(self.local)]
                    if direction == "Upload":
                        operands.reverse()
                    self.assertEqual(self.calls(), [["-s", "--", *operands]])

    def test_uppercase_upload_never_overwrites_local_source(self):
        result = self.run_script(
            self.inputs(answer="Y"), MOCK_DOWNLOAD_TARGET=str(self.local)
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.local.read_text(), "LOCAL_ORIGINAL\n")
        self.assertEqual(self.calls()[0][2], str(self.local))

    def test_invalid_confirmation_never_transfers(self):
        for answer in ("", "yes", "invalid", " y", "y ", "y\t"):
            with self.subTest(answer=answer):
                self.assert_rejected(self.inputs(answer=answer))

    def test_eof_at_every_prompt_never_transfers(self):
        values = self.inputs()
        for length in range(len(values)):
            with self.subTest(prompt=length):
                self.assert_rejected(values[:length])

    def test_invalid_menu_choices_never_transfer(self):
        for position in range(3):
            for choice in ("", "0", "3", "-1", "2x"):
                values = self.inputs()
                values[position] = choice
                with self.subTest(position=position, choice=choice):
                    self.assert_rejected(values)

    def test_ambiguous_local_paths_are_rejected_in_both_directions(self):
        for direction in ("Download", "Upload"):
            for local in (
                "collector@host.invalid:/drop/report.txt",
                "host.invalid:/drop/report.txt", "scp://host.invalid/report",
                "sftp://host.invalid/report", "C:/Users/me/report.txt",
                "C:\\Users\\me\\report.txt", "-oProxyCommand=anything",
                "relative/report.txt", "./relative.txt", "~/report.txt", "",
            ):
                with self.subTest(direction=direction, local=local):
                    self.assert_rejected(self.inputs(direction, local=local))

    def test_control_characters_are_rejected(self):
        for field in ("local", "remote", "user", "host"):
            for control in ("\t", "\r", "\x1b", "\x7f"):
                value = {
                    "local": str(self.local), "remote": "/remote/file",
                    "user": "reviewer", "host": "example.invalid",
                }[field] + control
                with self.subTest(field=field, control=repr(control)):
                    self.assert_rejected(self.inputs(**{field: value}))

    def test_user_and_host_delimiters_are_rejected(self):
        for user in ("", "-user", "user@other", "user/name", "user name",
                     "user;cmd", "DOMAIN\\user", "user:22"):
            with self.subTest(user=user):
                self.assert_rejected(self.inputs(user=user))
        for host in ("", "-host", "user@host", "host/path", "host:22",
                     "host;cmd", "host name", "::1", "[::1]:22",
                     "$(anything)"):
            with self.subTest(host=host):
                    self.assert_rejected(self.inputs(host=host))

    def test_validator_rejects_embedded_newlines_in_a_single_value(self):
        # Interactive newlines delimit answers; test a newline inside an
        # already-captured value at the validator boundary instead.
        result = subprocess.run(
            [
                "bash", "-c",
                'source "$1"; validate_text "Host" "$2"',
                "test", str(SCRIPT), "host\nY",
            ],
            text=True, capture_output=True, env=self.env,
            timeout=5, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_simple_hosts_and_bracketed_ipv6_are_preserved(self):
        for host in ("192.0.2.1", "server-dev", "server_alias",
                     "example.invalid.", "[::1]", "[2001:db8::1]"):
            with self.subTest(host=host):
                result = self.run_script(self.inputs(host=host))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    self.calls()[0][-1], f"reviewer@{host}:/remote/report.txt"
                )

    def test_remote_paths_require_explicit_absolute_syntax(self):
        for remote in ("", "relative.txt", "~/.ssh/key", "-file", "host:/file"):
            for remote_os in ("1", "2"):
                with self.subTest(remote=remote, remote_os=remote_os):
                    self.assert_rejected(
                        self.inputs(remote=remote, remote_os=remote_os)
                    )
        self.assert_rejected(self.inputs(remote="C:/file.txt", remote_os="2"))

    def test_remote_windows_paths_are_preserved(self):
        remote = "C:/Users/reviewer/My Documents/report.txt"
        for direction in ("Upload", "Download"):
            with self.subTest(direction=direction):
                result = self.run_script(
                    self.inputs(direction, remote=remote, remote_os="1")
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"reviewer@example.invalid:{remote}", self.calls()[0])

    def test_remote_globs_and_backslashes_are_rejected(self):
        for remote in ("/tmp/*", "/tmp/a?", "/tmp/[ab]", "/tmp/a]",
                       "/tmp/a\\b", "C:/folder\\file"):
            with self.subTest(remote=remote):
                self.assert_rejected(self.inputs(remote=remote))

    def test_download_source_must_name_a_file(self):
        for remote in ("/", "/remote/", "/remote/.", "/remote/.."):
            with self.subTest(remote=remote):
                self.assert_rejected(self.inputs("Download", remote=remote))

    def test_upload_source_must_be_an_existing_file(self):
        for local in (self.root / "missing.txt", self.root):
            with self.subTest(local=local):
                self.assert_rejected(self.inputs(local=local))

    def test_download_destination_parent_must_exist(self):
        self.assert_rejected(
            self.inputs("Download", local=self.root / "missing" / "file.txt")
        )
        self.assert_rejected(
            self.inputs("Download", local=str(self.root / "missing") + "/")
        )

    def test_download_accepts_a_new_file_or_existing_directory(self):
        for local in (self.root / "new report.txt", self.root):
            with self.subTest(local=local):
                result = self.run_script(self.inputs("Download", local=local))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls()[0][-1], str(local))

    def test_local_spaces_colons_and_metacharacters_stay_literal(self):
        local = self.root / "report: $(echo NO); 'quoted' [1].txt"
        local.write_text("literal filename\n")
        result = self.run_script(self.inputs(local=local))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[0][2], str(local))

    def test_remote_shell_metacharacters_stay_one_sftp_operand(self):
        marker = self.root / "MUST_NOT_EXIST"
        remote = f"/tmp/report;touch {marker};$(echo NO)"
        result = self.run_script(self.inputs(remote=remote))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[0], [
            "-s", "--", str(self.local), f"reviewer@example.invalid:{remote}"
        ])
        self.assertFalse(marker.exists())

    def test_spaces_and_trailing_spaces_are_preserved(self):
        local = self.root / "report with spaces.txt "
        local.write_text("literal\n")
        remote = "/remote/My Documents/report.txt "
        result = self.run_script(self.inputs(local=local, remote=remote))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[0][2:], [
            str(local), f"reviewer@example.invalid:{remote}"
        ])

    def test_summary_labels_both_endpoints_before_transfer(self):
        for direction in ("Download", "Upload"):
            with self.subTest(direction=direction):
                result = self.run_script(self.inputs(direction))
                self.assertIn(f"Operation: {direction} (SFTP only)", result.stdout)
                source = "local" if direction == "Upload" else "remote"
                target = "remote" if direction == "Upload" else "local"
                self.assertIn(f"Source ({source}):", result.stdout)
                self.assertIn(f"Destination ({target}):", result.stdout)
                self.assertIn("may be overwritten", result.stdout)
                self.assertLess(
                    result.stdout.index("Destination"),
                    result.stdout.index("Starting SFTP transfer"),
                )

    def test_scp_errors_propagate_without_retry_or_legacy_fallback(self):
        for status in (1, 23, 255):
            with self.subTest(status=status):
                result = self.run_script(self.inputs(), SCP_STATUS=str(status))
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertEqual(len(self.calls()), 1)
                self.assertEqual(self.calls()[0][:2], ["-s", "--"])
                self.assertNotIn("-O", self.calls()[0])

    def test_unsupported_runtime_fails_before_any_transfer(self):
        uname = self.bin / "uname"
        uname.write_text("#!/bin/sh\nprintf 'MINGW64_NT\\n'\n")
        uname.chmod(0o755)
        self.assert_rejected(self.inputs())

    def test_sourcing_does_not_prompt_or_transfer(self):
        result = subprocess.run(
            ["bash", "-c", 'source "$1"', "test", str(SCRIPT)],
            input="", text=True, capture_output=True,
            env=self.env, timeout=5, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
