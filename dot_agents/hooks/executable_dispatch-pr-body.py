#!/usr/bin/env python3
"""Cheap command selection; launch the body validator only for PR body writes."""
import importlib.util
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys

sys.dont_write_bytecode = True

root = Path(__file__).resolve().parent
raw = sys.stdin.read()
try:
    payload = json.loads(raw)
    cmd = payload.get("tool_input", {}).get("command") or ""
    if isinstance(cmd, list):
        cmd = shlex.join(cmd)
    if not isinstance(cmd, str) or "gh" not in cmd:
        sys.exit(0)
except (ValueError, AttributeError):
    sys.exit(0)
spec = importlib.util.spec_from_file_location("pr_body", root / "pr-body-humanized.py")
hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hook)
try:
    selected = bool(hook.check(cmd, hook.Context(cmd, payload.get("cwd") or str(Path.cwd())), select_only=True))
except ValueError:
    selected = bool(re.search(r"\bgh\b.*\b(pr\s+(create|edit)|api)\b.*\bbody", cmd))
if not selected:
    sys.exit(0)
sys.exit(subprocess.run([sys.executable, str(root / "pr-body-humanized.py")], input=raw, text=True).returncode)
