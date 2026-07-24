class_name Minigame
extends Control

## Base contract every minigame scene implements.
## Host calls setup(params), listens for finished(result).

signal finished(result: Dictionary)


func setup(_params: Dictionary) -> void:
	pass


func _finish(score: float, skipped: bool = false) -> void:
	finished.emit({"score": clampf(score, 0.0, 1.0), "skipped": skipped})


func _finish_with(extra: Dictionary) -> void:
	var result := {"score": 1.0, "skipped": false}
	result.merge(extra, true)
	finished.emit(result)
