#!/usr/bin/env python3
"""Run the UI click-through and fail on Godot runtime/script errors."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
headless = "--gui" not in sys.argv
command = ["godot"] + (["--headless"] if headless else []) + ["--path", str(ROOT), "tests/ui_navigation.tscn"]
result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=90)
output = result.stdout + result.stderr
print(output, end="")
error_pattern = re.compile(r"(?:^|\n)(?:ERROR:|SCRIPT ERROR:|Parse Error:|Invalid assignment|Invalid access)", re.IGNORECASE)
if result.returncode != 0 or error_pattern.search(output) or "PASS: UI navigation" not in output:
    print(f"UI navigation test failed (exit {result.returncode}, headless={headless}).", file=sys.stderr)
    sys.exit(1)
