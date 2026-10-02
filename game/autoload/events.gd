extends Node
## Typed, project-wide signals. UI and gameplay communicate through this bus.
signal theme_changed(mode: int)
signal scene_change_started(path: String)
signal scene_change_finished(path: String)
signal setting_changed(key: String, value: Variant)
signal level_won(level_id: String, stars: int, badge: bool)
signal level_failed(level_id: String)
signal sound_requested(sound_id: String)
