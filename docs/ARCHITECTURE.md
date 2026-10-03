# Architecture

- `Events` carries typed signals between screens and game systems.
- `Strings` registers the shared English text with Godot's TranslationServer.
- `GameState` holds temporary level data.
- `SaveSystem` stores settings, stars, and tutorial progress in `user://save.json`.
- `LevelRegistry` reads the small ordered chapter list and loads chapter details on demand.
- `AudioManager` owns the Music, SFX, and UI buses.
- `SceneRouter` handles faded scene changes.
- `ThemeManager` stores Auto, Light, or Dark mode and updates the root theme.
- `game/ui/app.gd` builds the menu, chapter pages, sheets, tutorial, and pre-game screen.
- `VolumeSlider`, `LockIcon`, `LightBulbIcon`, and `AimHint` draw small controls in Godot.

Each chapter has twenty metadata records. The Level Select screen builds only the current page. Scene paths are loaded later by the game flow when gameplay scenes are added.
