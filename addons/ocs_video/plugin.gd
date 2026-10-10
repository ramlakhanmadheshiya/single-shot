@tool
extends EditorPlugin
## Bundles the OCSVideo Android library (built by CI from plugins_src/ocs_video)
## into Android exports. Without the .aar the export still works; the game then
## reports that video saving isn't available.

var _export: AndroidExport


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport:
	extends EditorExportPlugin
	const AAR: String = "ocs_video/bin/ocs_video-release.aar"

	func _get_name() -> String:
		return "OCSVideo"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if FileAccess.file_exists("res://addons/" + AAR):
			return PackedStringArray([AAR])
		return PackedStringArray()
