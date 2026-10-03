extends Node
## One place for optional ad placements and rewards.
signal rewarded_completed
signal rewarded_failed

const MOCK_PROVIDER_SCRIPT: Script = preload("res://game/ads/providers/mock_ad_provider.gd")
var provider: Node
var banner_visible: bool = false
var banner_placement: String = ""
var ads_enabled: bool = true
var _reward_callback: Callable

func _ready() -> void:
	ads_enabled = bool(SaveSystem.get_setting("ads_enabled", true))
	provider = MOCK_PROVIDER_SCRIPT.new()
	provider.name = "MockAdProvider"
	add_child(provider)
	provider.rewarded_completed.connect(_on_provider_completed)
	provider.rewarded_failed.connect(_on_provider_failed)

func set_ads_enabled(enabled: bool) -> void:
	ads_enabled = enabled
	if not enabled:
		hide_banner()

func show_banner(placement: String) -> void:
	banner_placement = placement
	banner_visible = ads_enabled and placement in ["main_menu", "level_select"]

func hide_banner() -> void:
	banner_visible = false
	banner_placement = ""

func is_rewarded_ready() -> bool:
	return ads_enabled and provider != null and provider.is_rewarded_ready()

func show_rewarded(callback: Callable = Callable()) -> void:
	if not is_rewarded_ready():
		rewarded_failed.emit()
		if callback.is_valid():
			callback.call(false)
		return
	_reward_callback = callback
	provider.show_rewarded()

func create_banner(parent: Control, label_text: String, surface: Color, border: Color, ink: Color) -> PanelContainer:
	return provider.create_banner(parent, label_text, surface, border, ink)

func _on_provider_completed() -> void:
	rewarded_completed.emit()
	if _reward_callback.is_valid():
		_reward_callback.call(true)
	_reward_callback = Callable()

func _on_provider_failed() -> void:
	rewarded_failed.emit()
	if _reward_callback.is_valid():
		_reward_callback.call(false)
	_reward_callback = Callable()
