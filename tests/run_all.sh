#!/usr/bin/env bash
# Headless gate: import, simulation checks, level fairness, and the UI flow.
set -eo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1
godot --headless --path . -s res://tests/sim_smoke.gd 2>&1 | grep "SIM SMOKE"
godot --headless --path . -s res://tests/levels_test.gd 2>&1 | grep "LEVELS"
godot --headless --path . res://tests/ui_flow.tscn 2>&1 | grep "UI FLOW"
godot --headless --path . --quit-after 300 2>&1 | grep -E "SCRIPT ERROR" && exit 1
echo "ALL CHECKS PASSED"
