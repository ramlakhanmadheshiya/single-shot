extends Overlay
## Share your shot: a preview of the picture, then Share (the picture), Save (a
## video of the shot: the game's opening, your shot, the result and an invite to
## play) and Copy link.

var info: Dictionary = {}
var _image: Image
var _preview: TextureRect
var _status: Label
var _bar: _Bar
var _video: PromoVideo
var _share_video: Button


func build() -> void:
	name = "Share"
	add_title("Share your shot")
	var body: VBoxContainer = card_body()
	body.add_theme_constant_override("separation", 16)
	var holder: CenterContainer = CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 560)
	body.add_child(holder)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(432, 540)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(_preview)
	_preview.pivot_offset = Vector2(216, 270)
	_preview.rotation = deg_to_rad(-2.5)
	_status = UIKit.label("Making your card…", 20, pal["muted"], 500)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	body.add_child(row)
	row.add_child(_action("share-2", "SHARE", "ShareNow", func() -> void: ShareService.share(_image, info)))
	row.add_child(_action("download", "SAVE VIDEO", "Save", _save_video))
	row.add_child(_action("link", "COPY LINK", "CopyLink", func() -> void: ShareService.copy_link(info)))
	_bar = _Bar.new()
	_bar.pal = pal
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.visible = false
	body.add_child(_bar)
	_share_video = UIKit.pill("Share video", pal, "accent", Vector2(0, 84), 26)
	_share_video.name = "ShareVideo"
	_share_video.visible = false
	_share_video.pressed.connect(func() -> void:
		if not _video.share(ShareService.message_for(info)):
			_status.text = "Couldn't open sharing."
	)
	body.add_child(_share_video)
	ShareService.finished.connect(func(_ok: bool, msg: String) -> void:
		if is_inside_tree() and not msg.is_empty():
			_status.text = msg
	)
	ShareCard.render(self, info, func(img: Image) -> void:
		if not is_inside_tree():
			return
		_image = img
		if img != null:
			_preview.texture = ImageTexture.create_from_image(img)
			_status.text = "Can your friends match it?"
		else:
			_status.text = "Share the link with your friends."
	)


## Makes the video and saves it to the gallery, with progress.
func _save_video() -> void:
	if _video != null and _bar.visible:
		return
	if not PromoVideo.available():
		_status.text = "Saving the video works in the Android app. Here's the picture instead."
		ShareService.save(_image, info)
		return
	if _video == null:
		_video = PromoVideo.new()
		add_child(_video)
		_video.progress.connect(func(f: float) -> void:
			_bar.value = f
			_bar.queue_redraw()
			_status.text = "Making your video…  %d%%" % int(f * 100.0)
		)
		_video.done.connect(func(ok: bool, msg: String) -> void:
			_bar.visible = false
			_status.text = msg
			if ok:
				AudioManager.play("unlock", 1.0, -6.0)
				_share_video.visible = Engine.has_singleton("OCSVideo")
		)
	_bar.visible = true
	_bar.value = 0.0
	_status.text = "Making your video…"
	_video.make(info)


func _action(icon_name: String, caption: String, node_name: String, cb: Callable) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var b: Button = UIKit.icon_button(icon_name, pal, 84.0)
	b.name = node_name
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.label(caption, 16, pal["muted"], 600))
	if _first_focus == null:
		_first_focus = b
	return box


## A thin progress bar.
class _Bar:
	extends Control
	var pal: Dictionary
	var value: float = 0.0

	func _draw() -> void:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(5)
		sb.bg_color = Color(pal["ink"], 0.1)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		sb.bg_color = pal["accent"]
		draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * value), size.y)))
