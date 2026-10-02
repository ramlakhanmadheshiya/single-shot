extends Node
## Simple full-screen fade navigation that frees the previous scene normally.
var _layer: CanvasLayer
var _shade: ColorRect
var _busy: bool = false

func _ready() -> void:
    _layer = CanvasLayer.new()
    _layer.layer = 100
    add_child(_layer)
    _shade = ColorRect.new()
    _shade.color = Color(0.04, 0.025, 0.08, 1.0)
    _shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _shade.modulate.a = 0.0
    _layer.add_child(_shade)

func go_to(path: String) -> void:
    if _busy or not ResourceLoader.exists(path):
        return
    _busy = true
    Events.scene_change_started.emit(path)
    var tween: Tween = create_tween()
    tween.tween_property(_shade, "modulate:a", 1.0, 0.18)
    await tween.finished
    var error: Error = get_tree().change_scene_to_file(path)
    if error != OK:
        push_error("Could not load scene: " + path)
    var fade_in: Tween = create_tween()
    fade_in.tween_property(_shade, "modulate:a", 0.0, 0.24)
    await fade_in.finished
    _busy = false
    Events.scene_change_finished.emit(path)
