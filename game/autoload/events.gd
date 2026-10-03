extends Node
## Project-wide signals so UI and gameplay stay decoupled.
signal setting_changed(key: String, value: Variant)
signal level_completed(level_id: String, stars: int)
signal hints_changed(count: int)
