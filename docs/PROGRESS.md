# Progress

## Milestone 1 — Foundation (2026-10-03)

**Status: complete.** Created the Godot 4.7.2 project, folder layout, input/display/render settings, four-bus audio layout, Events, GameState, versioned SaveSystem, AudioManager, SceneRouter, LevelRegistry, ThemeManager, semantic palette tokens, dark/light themes, and a responsive main menu with Play, Settings, Credits, and Quit. Settings persist audio levels, shake, aim assist, fullscreen, and theme choice. Generated original UI sounds and a 48-second synthesized menu loop. Added architecture, GDD, asset inventory, and reproducible tools.

**Verification:** `godot --headless --path . --editor --quit` completed; `godot --headless --path . --quit-after 3` completed with no errors or warnings after correcting theme resource declaration order.

**Assumptions:** This milestone concentrates on a stable foundation and menu flow; Play currently opens a chapter landing page and points to the gameplay slice in Milestone 2. Google Fonts were not needed because the default Godot font is used for now. User save files use Godot's normal per-project `user://` location.

## Next
Milestone 2 will add Hazel, aim/trajectory, pellet physics, enemy/crate interactions, a HUD, and three playable test rooms.


## Milestone 1 navigation fix (2026-10-03)

The first Foundation report missed a runtime issue: the title node was a child of the container cleared during screen changes. Moved it into the persistent panel shell, kept only temporary widgets in the cleared VBox, and explicitly null transient Settings references before freeing their nodes. Increased panel/control dimensions and title typography, added viewport-aware panel sizing, and set stretch aspect to `expand`.

Added an automated click-through at `tests/ui_navigation.gd` with a log-checking runner at `tests/run_ui_navigation.py`. It covers Main Menu, Chapters, Settings, Credits and Chapter I, exercises all sliders and toggles, cycles Dark/Light/System, checks the persistent title and reference lifetimes, and visits every screen in Dark and Light modes.

**Verification:** `python3 tests/run_ui_navigation.py` passed headlessly. `python3 tests/run_ui_navigation.py --gui` passed through the normal OpenGL Compatibility renderer. Both runs completed without script errors, debugger errors or warnings. Milestone 2 has not started.

**Process update:** Future milestones must include a screen click-through test and remain incomplete until it passes.
