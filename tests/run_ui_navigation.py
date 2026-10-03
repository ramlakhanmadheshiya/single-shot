#!/usr/bin/env python3
"""Run Foundation UI checks and fail on Godot runtime or script errors."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
headless = "--gui" not in sys.argv
scenes = ["tests/ui_navigation.tscn", "tests/level_select_scale.tscn"]
error_pattern = re.compile(r"(?:^|\n)(?:ERROR:|SCRIPT ERROR:|Parse Error:|Invalid assignment|Invalid access)", re.IGNORECASE)
failed = False
for scene in scenes:
    command = ["godot"] + (["--headless"] if headless else []) + ["--path", str(ROOT), "--quit-after", "3600", scene]
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=45)
    except subprocess.TimeoutExpired as error:
        print(f"UI test timed out: {scene}", file=sys.stderr)
        print((error.stdout or "").decode() if isinstance(error.stdout, bytes) else (error.stdout or ""), end="")
        failed = True
        continue
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode != 0 or error_pattern.search(output) or "PASS:" not in output:
        print(f"UI test failed: {scene} (exit {result.returncode}, headless={headless}).", file=sys.stderr)
        failed = True
if failed:
    sys.exit(1)
