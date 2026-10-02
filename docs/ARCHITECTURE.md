# Architecture

- `game/autoload/Events`: typed signal bus to keep screen and gameplay references loose.
- `GameState`: transient level selection and state machine data.
- `SaveSystem`: versioned `user://save.json`; progress is keyed by string level ids and has a migration entry point.
- `LevelRegistry`: reads a tiny ordered registry, loads chapter JSON on demand, and exposes threaded scene requests.
- `AudioManager`: named Music/SFX/UI buses, an 8-player SFX pool and independent music player.
- `SceneRouter`: fades before replacing a scene, releasing the old scene tree.
- `ThemeManager`: DARK/LIGHT/SYSTEM choice, persisted through SaveSystem, with semantic palettes generated from one token source.
- `game/ui/app.gd`: responsive Control-based menu/settings shell. Level content is metadata-driven and should be kept out of the screen code.

The 1920×1080 canvas uses `canvas_items` scaling and GL Compatibility for broad desktop/mobile support. Levels are loaded lazily; registry size does not imply that scenes are resident in memory.
