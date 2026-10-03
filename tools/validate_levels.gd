extends SceneTree
## Checks that each registered chapter has exactly twenty unique level records.
const REGISTRY_PATH: String = "res://content/registry.json"
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var file: FileAccess = FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open chapter registry.")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Chapter registry is not valid JSON.")
		quit(1)
		return
	var ids: Dictionary = {}
	var chapter_entries: Array = parsed.get("chapters", [])
	var errors: int = 0
	for entry_value: Variant in chapter_entries:
		if not entry_value is Dictionary:
			push_error("Chapter entry must be an object.")
			errors += 1
			continue
		var entry: Dictionary = entry_value
		var chapter_id: String = str(entry.get("id", ""))
		if chapter_id.is_empty() or ids.has(chapter_id):
			push_error("Chapter ids must be present and unique: " + chapter_id)
			errors += 1
		ids[chapter_id] = true
		var folder: String = str(entry.get("path", ""))
		var prefix: String = "" if folder.begins_with("res://") else "res://"
		var chapter_path: String = prefix + folder.trim_suffix("/") + "/chapter.json"
		var chapter_file: FileAccess = FileAccess.open(chapter_path, FileAccess.READ)
		if chapter_file == null:
			push_error("Missing chapter data: " + chapter_path)
			errors += 1
			continue
		var chapter: Variant = JSON.parse_string(chapter_file.get_as_text())
		if not chapter is Dictionary:
			push_error("Invalid chapter JSON: " + chapter_path)
			errors += 1
			continue
		var levels: Array = chapter.get("levels", [])
		if int(chapter.get("level_count", 0)) != 20 or int(entry.get("level_count", 0)) != 20 or levels.size() != 20:
			push_error("Each chapter must list exactly twenty levels: " + chapter_id)
			errors += 1
		var level_ids: Dictionary = {}
		for level_value: Variant in levels:
			if not level_value is Dictionary:
				errors += 1
				continue
			var level_id: String = str(level_value.get("id", ""))
			if level_id.is_empty() or level_ids.has(level_id):
				push_error("Level ids must be present and unique in " + chapter_id)
				errors += 1
			level_ids[level_id] = true
	if errors > 0:
		quit(1)
	else:
		print("PASS: %d chapters; each has exactly twenty levels" % chapter_entries.size())
		quit(0)
