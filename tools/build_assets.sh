#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/generate_audio.py
godot --headless --path . --script tools/generate_themes.gd
