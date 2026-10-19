extends SceneTree
## The 512 x 512 Play Store icon from assets/icon.svg, as a full-bleed square:
## Play rounds the corners itself, so the tile's own rounding is dropped.
## Run: godot --headless --path . -s res://tools/render_icon.gd -- store/icon_512.png


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "store/icon_512.png"
	if out.is_relative_path():
		out = ProjectSettings.globalize_path("res://").path_join(out)
	var svg: String = FileAccess.get_file_as_string("res://assets/icon.svg").replace('rx="232"', 'rx="0"')
	var img: Image = Image.new()
	img.load_svg_from_string(svg, 0.5)
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out)
	print("icon ", img.get_size(), " -> ", out)
	quit()
