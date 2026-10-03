# Progress

## Foundation UX revision (2026-10-03)

**Status: complete after automated UI checks.** Added five chapter pages, each with twenty numbered levels, star marks, locks, and a highlighted next level. Pages support arrows, touch swipes, a five-dot window, and a chapter jump box. Levels opens at the current chapter.

Settings now slides up from the Main Menu or level screen. It has sound and music switches, mobile vibration, three themes, aim guide, screen shake, sound sliders, How to play, Credits, About, and Reset progress. Help pages open above Settings. Reset asks before clearing stars.

Added the pre-game screen with shots used, a three-star goal, Hint, Undo, Restart, and Settings. First play shows a drag tutorial once. The English words live in `game/ui/strings.gd` and use Godot's TranslationServer.

Added five chapter JSON files with exactly twenty level records each. Level metadata loads only when its page appears. Added a 30-chapter test with 600 level records. Added `tools/validate_levels.gd` for the twenty-level rule.

**Checks passed:**

- `python3 tests/run_ui_navigation.py` — Main Menu, pages, settings, themes, reset, help, and in-level controls.
- `python3 tests/run_ui_navigation.py --gui` — same flow through the OpenGL Compatibility renderer.
- Both runs build a temporary 30-chapter registry, check 600 levels, jump to page 30, and confirm only visible levels are built.
- The GUI check resizes through 1280×720, 1920×1080, 720×1280, and 2560×1440.
- `godot --headless --path . --script tools/validate_levels.gd` — all five chapter files pass.

No errors or warnings appeared in the checked Godot output. The 20 level scenes and game physics are not part of this UX update. The next work waits for the user's approval.
### Menu and tutorial follow-up

- Play now continues to the first unfinished unlocked level and shows its number.
- Levels opens the current chapter. Level Back follows the path used to enter.
- The tutorial uses a spotlight, action prompt, moving hand, and ghost aim line.
- The first tutorial step waits for a drag inside the highlighted play area.
- Locked level tiles show a clear lock icon without a word or star row.
- Saved current level lookup uses the registry index without reading every chapter.
- Dark and Light menu, level, locked chapter, and settings screenshots are in `docs/screenshots/`.
- Headless and GUI click-through suites cover new and continuing players.
- Milestone 2 has not started.
