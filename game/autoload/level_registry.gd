extends Node
## Reads the small chapter index and loads chapter details only when shown.
const REGISTRY_PATH: String = "res://content/registry.json"
var chapters: Array[Dictionary] = []
var chapter_cache: Dictionary = {}
var metadata_load_count: int = 0
var last_loaded_chapter_id: String = ""

func _ready() -> void:
	load_registry()

func load_registry() -> void:
	chapters.clear()
	chapter_cache.clear()
	if not FileAccess.file_exists(REGISTRY_PATH):
		return
	var file: FileAccess = FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for chapter_value: Variant in parsed.get("chapters", []):
			if chapter_value is Dictionary:
				chapters.append(chapter_value)

func load_chapter(chapter_id: String) -> Dictionary:
	if chapter_cache.has(chapter_id):
		last_loaded_chapter_id = chapter_id
		return chapter_cache[chapter_id]
	for entry: Dictionary in chapters:
		if str(entry.get("id", "")) != chapter_id:
			continue
		var path: String = str(entry.get("path", ""))
		var prefix: String = "" if path.begins_with("res://") or path.begins_with("user://") else "res://"
		var chapter_path: String = prefix + path.trim_suffix("/") + "/chapter.json"
		if not FileAccess.file_exists(chapter_path):
			return {}
		var file: FileAccess = FileAccess.open(chapter_path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		if parsed is Dictionary:
			chapter_cache[chapter_id] = parsed
			metadata_load_count += 1
			last_loaded_chapter_id = chapter_id
			return parsed
	return {}

func total_level_count() -> int:
	var total: int = 0
	for chapter: Dictionary in chapters:
		total += int(chapter.get("level_count", 0))
	return total

func request_level(scene_path: String) -> Error:
	return ResourceLoader.load_threaded_request(scene_path)
