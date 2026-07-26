class_name Wallet
extends RefCounted

## Int dollars only. Money never goes negative: spend() checks first and
## callers branch on the bool.

var savings: int = 0


func credit(amount: int) -> void:
	savings += maxi(amount, 0)


func spend(cost: int) -> bool:
	if cost < 0 or cost > savings:
		return false
	savings -= cost
	return true


func can_retire(target: int) -> bool:
	return savings >= target
