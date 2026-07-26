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


## Takes up to `cost` out of savings, clamping at zero — money never goes
## negative. Returns the amount actually taken, since callers (the day-end
## summary) need to report the real drain, not the requested one.
func drain(cost: int) -> int:
	var taken := mini(maxi(cost, 0), savings)
	savings -= taken
	return taken
