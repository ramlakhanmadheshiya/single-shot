class_name ChapterIntro
extends Control
## The first time a chapter's opening room is played: a floating card explains the
## chapter's new idea with a live diagram, then the new element is spotlit in the
## room with a short caption until the player starts aiming.

signal done

const LESSONS: Dictionary = {
	"ch1": ["Bank shots", "Drag to aim, release to shoot. Your orb banks off walls; pop every target in one shot."],
	"ch2": ["Glass breaks", "Glass bounces your orb once, then shatters. Later in the same shot, the orb flies straight through the gap."],
	"ch3": ["Dark and round", "Dark blocks swallow the orb. Round bumpers bounce it away at a new angle."],
	"ch4": ["Portals", "Fly into one portal and come out of its twin, still heading the same way."],
	"ch5": ["Prisms split", "A prism splits your orb in two. Each half keeps the bounces you have left."],
	"ch6": ["Switch and gates", "Fly through the switch and every dashed gate dissolves for the rest of the shot."],
	"ch7": ["Sparks", "Fly through a spark to earn one extra bounce. Some rooms start with none."],
	"ch8": ["Pivot walls", "A pivot wall turns 90° every time it's hit. Plan for where it will be next."],
	"ch9": ["Moving platforms", "Platforms never stop sliding along their rails. Watch the rhythm, then release at the right moment. The aim line shows where they'll be when your orb arrives."],
}
const CAPTIONS: Dictionary = {
	"ch2": "This glass breaks after one bounce",
	"ch3": "Bumpers bounce  ·  dark blocks swallow",
	"ch4": "In one portal, out the other",
	"ch5": "The prism splits your orb",
	"ch6": "The switch opens the gate",
	"ch7": "A spark gives one more bounce",
	"ch8": "This wall turns when hit",
	"ch9": "Time your release to the platform",
}

var chapter_id: String = "ch2"
var pal: Dictionary
var board: Board
var _card_root: Control
var _bubble: PanelContainer
var _spotlight: bool = false
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_card()
	board.aim_started.connect(func() -> void:
		if _spotlight:
			_finish()
	)


func _build_card() -> void:
	_card_root = Control.new()
	_card_root.add_to_group("modal")
	_card_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card_root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(pal["bottom"], 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_root.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.card_style(pal))
	panel.custom_minimum_size = Vector2(580, 0)
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var lesson: Array = LESSONS.get(chapter_id, LESSONS["ch1"])
	col.add_child(UIKit.caption("New in %s" % pal["name"], {"muted": pal["accent"]}, 18, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.label(str(lesson[0]), 46, pal["ink"], 500))
	var art: ChapterArt = ChapterArt.new()
	art.chapter_id = chapter_id
	art.pal = pal
	art.custom_minimum_size = Vector2(0, 250)
	col.add_child(art)
	var text: Label = UIKit.label(str(lesson[1]), 25, pal["ink"], 400)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	var ok: Button = UIKit.pill("Got it", pal, "primary", Vector2(0, 88), 30)
	ok.name = "GotIt"
	ok.pressed.connect(dismiss)
	col.add_child(ok)
	panel.modulate.a = 0.0
	(func() -> void:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.9, 0.9)
		var tw: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "modulate:a", 1.0, 0.25)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.4)
	).call_deferred()
	ok.grab_focus.call_deferred()


## Closes the card and spotlights the new element in the room.
func dismiss() -> void:
	if _card_root == null:
		_finish()
		return
	var root: Control = _card_root
	_card_root = null
	var tw: Tween = create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(root.queue_free)
	_spotlight = true
	_bubble = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = pal["ink"]
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(UIKit.label(str(CAPTIONS.get(chapter_id, "Follow the dotted path")), 24, pal["top"], 600))
	add_child(_bubble)
	done.emit()


func _finish() -> void:
	_spotlight = false
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	if _bubble != null:
		var top: Vector2 = board.global_position - global_position + board.to_screen(Vector2(RicochetSim.ARENA.x * 0.5, 0))
		_bubble.position = Vector2(top.x - _bubble.size.x * 0.5, top.y + 20)
	if _spotlight:
		queue_redraw()


## Where the chapter's new element sits, in arena units.
func _spots() -> Array:
	var lv: Dictionary = board.level
	var out: Array = []
	var keys: Dictionary = {"ch3": ["bumpers"], "ch4": ["portals"], "ch5": ["prisms"], "ch6": ["switches"], "ch7": ["sparks"]}
	for key: String in keys.get(chapter_id, []):
		for q: Array in lv.get(key, []):
			out.append(Vector2(float(q[0]), float(q[1])))
			if key == "portals":
				out.append(Vector2(float(q[2]), float(q[3])))
	for w: Array in lv.get("walls", []):
		var kind: String = RicochetSim.wall_kind(w)
		var hit: bool = (chapter_id == "ch2" and kind == "glass") or (chapter_id == "ch3" and kind == "void") \
			or (chapter_id == "ch6" and kind == "gate") or (chapter_id == "ch8" and kind == "pivot") \
			or (chapter_id == "ch9" and RicochetSim.is_moving(w))
		if hit:
			out.append(Vector2(float(w[0]), float(w[1])))
	return out


func _draw() -> void:
	if not _spotlight or board == null:
		return
	var origin: Vector2 = board.global_position - global_position
	var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)
	for p: Vector2 in _spots():
		var c: Vector2 = origin + board.to_screen(p)
		var r: float = board.view_scale * (54.0 + 10.0 * pulse)
		draw_arc(c, r, 0.0, TAU, 56, Color(pal["accent"], 0.45 + 0.4 * pulse), 4.0, true)
		draw_arc(c, r + 12.0, 0.0, TAU, 56, Color(pal["accent"], 0.2 * pulse), 2.0, true)
