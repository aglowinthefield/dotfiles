#!/usr/bin/env python3
"""Prove non-PR commands never launch the body validator."""
import io
import json
from pathlib import Path
import runpy
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent

class DispatchTests(unittest.TestCase):
    def dispatch(self, command, expected):
        with patch('sys.stdin', io.StringIO(json.dumps({'tool_input': {'command': command}}))), patch('subprocess.run', return_value=SimpleNamespace(returncode=0)) as launch:
            with self.assertRaises(SystemExit) as result:
                runpy.run_path(str(ROOT / 'dispatch-pr-body.py'), run_name='__main__')
            self.assertEqual(result.exception.code, 0)
            self.assertEqual(launch.call_count, expected)
    def test_unrelated_commands_skip_validator(self):
        for command in ['git status', 'gh pr view 1', 'gh pr list', 'gh pr checks 1', 'gh pr merge 1', 'gh pr edit 1 --title title', 'gh pr comment 1 --body "I leverage it"', 'gh issue comment 1 --body-file missing.md', 'echo "gh pr create --body text"', 'gh api repos/o/r/pulls', 'gh api -X GET repos/o/r/pulls/1 -f body=x', 'gh api graphql -f query="mutation { updatePullRequest(input:{title: \\\"x\\\"}) { id } }"']:
            with self.subTest(command=command): self.dispatch(command, 0)
    def test_pr_writes_launch_validator(self):
        for command in ['gh pr create --body text', 'gh pr edit 1 --body-file missing.md', 'gh pr create --fill', 'env FOO=1 gh pr create --body x', 'sh -c "gh pr edit 1 -b x"', 'gh api -X PATCH repos/o/r/pulls/1 -f body=x', 'gh api graphql -f query=\'mutation { updatePullRequest(input:{body:"x"}) { id } }\'']:
            with self.subTest(command=command): self.dispatch(command, 1)

if __name__ == '__main__': unittest.main()
