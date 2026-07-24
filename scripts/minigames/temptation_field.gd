class_name TemptationField

## The mouse-fight: computes the per-frame pull dragging the cursor toward
## the "one more game" button.


static func pull_offset(cursor: Vector2, attractor: Vector2, strength: float, dt: float) -> Vector2:
	var dir := attractor - cursor
	if dir.length() < 1.0 or strength <= 0.0:
		return Vector2.ZERO
	return dir.normalized() * strength * dt
