extends Node
## The one in-app purchase: the Supporter Pack (no ads, unlimited hints).
## Uses the Google Play Billing plugin on Android; elsewhere purchases are unavailable,
## except debug desktop builds, which simulate them so the flow can be tested.

signal purchase_finished(ok: bool, message: String)
signal restore_finished(found: bool, message: String)
signal price_updated(price: String)

const PRODUCT_ID: String = "supporter_pack"
const FALLBACK_PRICE: String = "$2.99"
## Shown until Google Play reports the real, localised price (or where Play isn't
## available). Picked from the device's region setting — no permissions needed.
## Keep these in line with the prices set in the Play Console.
const REGIONAL_PRICES: Dictionary = {
	"IN": "₹249", "US": "$2.99", "GB": "£2.49", "CA": "CA$3.99", "AU": "A$4.49", "NZ": "NZ$4.99",
	"DE": "€2.99", "FR": "€2.99", "IT": "€2.99", "ES": "€2.99", "NL": "€2.99", "BE": "€2.99",
	"AT": "€2.99", "IE": "€2.99", "PT": "€2.99", "FI": "€2.99", "GR": "€2.99", "SK": "€2.99",
	"JP": "¥450", "KR": "₩3,900", "CN": "¥19", "BR": "R$14,90", "MX": "MX$59", "AR": "ARS 2.999",
	"ID": "Rp 45.000", "PK": "Rs 799", "BD": "৳299", "NP": "Rs 399", "LK": "Rs 899", "NG": "₦2,500",
	"PH": "₱149", "TR": "₺99,99", "RU": "249 ₽", "ZA": "R54,99", "AE": "AED 10.99", "SA": "SAR 10.99",
	"VN": "69.000 ₫", "TH": "฿99", "MY": "RM12.90", "SG": "S$3.98", "EG": "EGP 149", "KE": "KSh 399",
	"PL": "13,99 zł", "SE": "35 kr", "NO": "35 kr", "DK": "22 kr", "CH": "CHF 3.00", "IL": "₪11.90",
}

var price: String = regional_price()
var _billing: BillingClient = null
var _restoring: bool = false


func _ready() -> void:
	# Only create the client where the native plugin exists (Android builds).
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = BillingClient.new()
		add_child(_billing)
		_connect_billing()


## Best-guess local price from the device locale, e.g. "en_IN" -> "₹249".
static func regional_price() -> String:
	var parts: PackedStringArray = OS.get_locale().replace("-", "_").split("_")
	for i: int in range(parts.size() - 1, 0, -1):
		var region: String = parts[i].to_upper()
		if REGIONAL_PRICES.has(region):
			return REGIONAL_PRICES[region]
	return FALLBACK_PRICE


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
		purchase_finished.emit(true, "Thank you for supporting One Clean Shot!")
	if _restoring:
		_restoring = false
		restore_finished.emit(owned, "Supporter Pack restored." if owned else "No previous purchase found on this Google account.")
