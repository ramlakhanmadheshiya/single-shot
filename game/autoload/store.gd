extends Node
## The one in-app purchase: the Supporter Pack (no ads, unlimited hints).
## Uses the Google Play Billing plugin on Android; elsewhere purchases are unavailable,
## except debug desktop builds, which simulate them so the flow can be tested.

signal purchase_finished(ok: bool, message: String)
signal restore_finished(found: bool, message: String)
signal price_updated(price: String)

const PRODUCT_ID: String = "supporter_pack"
const FALLBACK_PRICE: String = "$2.99"

var price: String = FALLBACK_PRICE
var _billing: BillingClient = null
var _restoring: bool = false


func _ready() -> void:
	# Only create the client where the native plugin exists (Android builds).
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = BillingClient.new()
		add_child(_billing)
		_connect_billing()


func available() -> bool:
	return _billing != null or _simulated()


func _simulated() -> bool:
	return OS.is_debug_build() and not OS.has_feature("mobile") and not OS.has_feature("web")


func buy() -> void:
	if SaveSystem.is_supporter():
		purchase_finished.emit(true, "You're already a supporter. Thank you!")
		return
	if _billing != null:
		_billing_buy()
	elif _simulated():
		SaveSystem.set_supporter(true)
		purchase_finished.emit(true, "Thank you! (simulated purchase in a debug build)")
	else:
		purchase_finished.emit(false, "Purchases are available in the Android app.")


func restore() -> void:
	if _billing != null:
		_billing_restore()
	elif _simulated():
		restore_finished.emit(SaveSystem.is_supporter(), "Restored." if SaveSystem.is_supporter() else "No purchase found.")
	else:
		restore_finished.emit(false, "Restore is available in the Android app.")


# --- Google Play Billing -------------------------------------------------------

func _connect_billing() -> void:
	_billing.connected.connect(func() -> void:
		_billing.query_product_details(PackedStringArray([PRODUCT_ID]), BillingClient.ProductType.INAPP)
		# Silent restore on every launch keeps the entitlement in sync.
		_billing.query_purchases(BillingClient.ProductType.INAPP)
	)
	_billing.connect_error.connect(func(code: int, msg: String) -> void: push_warning("Billing %d %s" % [code, msg]))
	_billing.query_product_details_response.connect(func(res: Dictionary) -> void:
		if int(res.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
			return
		for p: Dictionary in res.get("product_details", []):
			var offers: Variant = p.get("one_time_purchase_offer_details_list")
			if str(p.get("product_id", "")) == PRODUCT_ID and offers is Array and not (offers as Array).is_empty():
				price = str(offers[0].get("formatted_price", FALLBACK_PRICE))
				price_updated.emit(price)
	)
	_billing.query_purchases_response.connect(_on_purchases)
	_billing.on_purchase_updated.connect(_on_purchases)
	_billing.start_connection()


func _billing_buy() -> void:
	if not _billing.is_ready():
		purchase_finished.emit(false, "Can't reach Google Play right now. Try again in a moment.")
		return
	var res: Dictionary = _billing.purchase(PRODUCT_ID)
	if int(res.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		purchase_finished.emit(false, "Purchase couldn't start (%s)." % str(res.get("debug_message", "unknown")))


func _billing_restore() -> void:
	if not _billing.is_ready():
		restore_finished.emit(false, "Can't reach Google Play right now. Try again in a moment.")
		return
	_restoring = true
	_billing.query_purchases(BillingClient.ProductType.INAPP)


func _on_purchases(res: Dictionary) -> void:
	var code: int = int(res.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		_restoring = true
		_billing.query_purchases(BillingClient.ProductType.INAPP)
		return
	if code != BillingClient.BillingResponseCode.OK:
		if code == BillingClient.BillingResponseCode.USER_CANCELED:
			purchase_finished.emit(false, "Purchase cancelled.")
		elif _restoring:
			_restoring = false
			restore_finished.emit(false, "Couldn't check purchases. Try again later.")
		return
	var owned: bool = false
	for p: Dictionary in res.get("purchases", []):
		if PRODUCT_ID in (p.get("product_ids", []) as Array) and int(p.get("purchase_state", 0)) == BillingClient.PurchaseState.PURCHASED:
			owned = true
			if not bool(p.get("is_acknowledged", false)):
				_billing.acknowledge_purchase(str(p["purchase_token"]))
	if owned and not SaveSystem.is_supporter():
		SaveSystem.set_supporter(true)
		purchase_finished.emit(true, "Thank you for supporting Carom!")
	if _restoring:
		_restoring = false
		restore_finished.emit(owned, "Supporter Pack restored." if owned else "No previous purchase found on this Google account.")
