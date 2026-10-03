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
- Chapter 1 gameplay began after the UX checks passed.

### Input, hints, ads, and web groundwork

- Fixed Main Menu Settings input ordering above its full-screen layout container.
- How to play, Credits, and About now open small Pending sheets.
- Added three local-day free hints, saved bonus hints, and a clock-backward guard.
- Added a mock rewarded ad flow and the optional AdManager interface.
- Banner placeholders appear only on Main Menu and Level Select.
- Added a Web export preset, first-tap audio screen, and empty link settings.
- Added a plain release checklist in `docs/PUBLISHING.md`.
- Automated tests cover pointer activations, daily hints, rewards, banners, and window sizes.
- Screenshots cover the new sheets and hint states in both themes.
- No real ad SDK or store keys were added.

## Milestone 2: core gameplay

- Added Hazel, ghouls, crates, and walls with generated art and sounds.
- Added drag, keyboard, and gamepad aiming with CCD rigid shots and wall bounce.
- Added a dotted first-bounce guide, solving hints, hit effects, and settling states.
- Added win and try-again cards, stars, saved best shots, unlocks, and Play progress.
- Added one-time action tutorials for Levels 1, 2, and 3.
- Centralized physics tuning in `game/core/physics_tuning.tres`.
- Added a debug-only F1 panel with live physics sliders.
- Authored twenty Chapter 1 boards with stored solving shots.
- Added tests for every solving shot, misses, Undo, Restart, stars, hints, and tutorials.
- Gameplay, win, and try-again screenshots in Dark and Light are in `docs/screenshots/`.
- Headless and GUI runs of `python3 tests/run_ui_navigation.py` pass, including all 20 stored solutions, misses, Undo, Restart, stars, and hints.
- `godot --headless --path . --script res://tools/validate_levels.gd` passes for all five chapters. The gameplay solver test wins every Chapter 1 level within its shot count.
- GUI runs used Godot's OpenGL Compatibility renderer and reported no script, debugger, or resource errors.
- Milestone 3 has not started.
