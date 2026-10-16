extends Node

## Implement this boundary with AdMob/UMP and Google Play Billing.
## Emit purchase_verified only after authenticated server verification.
signal availability_changed
signal reward_earned(request_id: String)
signal reward_closed(request_id: String)
signal purchase_verified(product_id: String)
signal purchase_finished(product_id: String, status: String)
signal entitlements_restored(product_ids: Array)

func can_request_ads() -> bool:
	return false

func is_rewarded_ready() -> bool:
	return false

func show_rewarded(_request_id: String) -> void:
	pass

func is_billing_ready() -> bool:
	return false

func get_price(_product_id: String) -> String:
	return ""

func purchase(_product_id: String) -> void:
	pass

func restore() -> void:
	pass

func show_privacy_options() -> void:
	pass
