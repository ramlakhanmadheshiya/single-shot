@echo off
cd /d "%~dp0.."
python tools\generate_audio.py
 godot --headless --path . --script tools\generate_themes.gd
