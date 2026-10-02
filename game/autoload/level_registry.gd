extends Node
## Lazy metadata registry, ready for chapter JSON files and 500+ levels.
const REGISTRY_PATH: String = "res://content/registry.json"
var chapters: Array[Dictionary] = []

func _ready() -> void:
    load_registry()

func load_registry() -> void:
    chapters.clear()
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
    for entry: Dictionary in chapters:
        if str(entry.get("id", "")) == chapter_id:
            var chapter_path: String = "res://" + str(entry.get("path", "")) + "/chapter.json"
            if FileAccess.file_exists(chapter_path):
                var file: FileAccess = FileAccess.open(chapter_path, FileAccess.READ)
                var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
                return parsed if parsed is Dictionary else {}
    return {}

func request_level(scene_path: String) -> Error:
    return ResourceLoader.load_threaded_request(scene_path)
