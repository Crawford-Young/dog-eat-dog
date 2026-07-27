class_name DressLogic
extends RefCounted

## Dressing order rules. Shoes after pants — the only hard dependency; the
## rest is fumble-under-clock pressure, which lives in the scene.

const ITEMS: Array[String] = ["shirt", "pants", "shoes", "collar"]
const REQUIRES := {"shoes": ["pants"]}

var worn: Array[String] = []


func can_wear(item: String) -> bool:
	if item in worn or item not in ITEMS:
		return false
	for req in REQUIRES.get(item, []):
		if req not in worn:
			return false
	return true


func wear(item: String) -> bool:
	if not can_wear(item):
		return false
	worn.append(item)
	return true


func is_dressed() -> bool:
	return worn.size() == ITEMS.size()
