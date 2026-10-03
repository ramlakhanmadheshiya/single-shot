extends Node
## All ad decisions live here so ads stay polite:
## - a small banner at the very bottom of every screen, with layout space reserved
##   so it never covers buttons;
## - an interstitial only between levels: never in the first 5 clears, at most once
##   every 3 clears and 3 minutes, and never after a failed attempt;
## - a rewarded ad only when the player asks for +1 hint.
## Supporters see no banners and no interstitials.
## Providers: AdMob on Android (plugin), a visible mock on debug desktop builds,
## and nothing at all elsewhere (web, release desktop).

signal rewarded_finished(ok: bool)

## Loaded lazily: it references plugin classes that only matter on Android.
const ADMOB_PROVIDER_PATH: String = "res://game/ads/providers/admob_provider.gd"
const MockProvider: GDScript = preload("res://game/ads/providers/mock_ad_provider.gd")

const INTERSTITIAL_EVERY: int = 3
const INTERSTITIAL_MIN_SECONDS: float = 180.0
const INTERSTITIAL_AFTER_CLEARS: int = 5

var provider: Node = null
var banner_height: float = 0.0
var _clears_since_ad: int = 0
var _last_interstitial_msec: int = -1000000
var _banner_on: bool = false


func _ready() -> void:
	if Engine.has_singleton("PoingGodotAdMob"):
		provider = (load(ADMOB_PROVIDER_PATH) as GDScript).new()
	elif OS.is_debug_build() and not OS.has_feature("mobile") and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		provider = MockProvider.new()
	if provider != null:
		provider.name = "AdProvider"
		add_child(provider)
		provider.banner_resized.connect(_on_banner_resized)
	Events.supporter_changed.connect(func(_on: bool) -> void: refresh_banner())
	Events.level_completed.connect(func(_id: String, _stars: int) -> void: _clears_since_ad += 1)


func ads_enabled() -> bool:
	return provider != null and not SaveSystem.is_supporter()


## Shows the bottom banner unless the player is a supporter.
func refresh_banner() -> void:
	var want: bool = ads_enabled()
	if want == _banner_on:
		return
	_banner_on = want
	if provider == null:
		return
	if want:
		provider.show_banner()
	else:
		provider.hide_banner()
		_on_banner_resized(0.0)


func _on_banner_resized(height_px: float) -> void:
	# Convert device pixels to viewport units so layouts can reserve the space.
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var vp: Vector2 = get_viewport().get_visible_rect().size
	banner_height = height_px * (vp.y / maxf(1.0, win.y)) if height_px > 0.0 else 0.0
	Events.banner_changed.emit(banner_height)


## Called when the player leaves a cleared level. Runs `then` after any ad closes.
func between_levels(then: Callable) -> void:
	var now: int = Time.get_ticks_msec()
	var due: bool = ads_enabled() \
		and _clears_since_ad >= INTERSTITIAL_EVERY \
		and Levels.total_cleared() >= INTERSTITIAL_AFTER_CLEARS \
		and float(now - _last_interstitial_msec) / 1000.0 >= INTERSTITIAL_MIN_SECONDS \
		and provider.interstitial_ready()
	if not due:
		then.call()
		return
	_clears_since_ad = 0
	_last_interstitial_msec = now
	provider.show_interstitial(func() -> void: then.call())


func rewarded_ready() -> bool:
	return provider != null and provider.rewarded_ready()


## Plays a rewarded ad; callback(ok) is true only if the reward was earned.
func show_rewarded(callback: Callable) -> void:
	if not rewarded_ready():
		callback.call(false)
		return
	provider.show_rewarded(func(ok: bool) -> void:
		rewarded_finished.emit(ok)
		callback.call(ok)
	)
