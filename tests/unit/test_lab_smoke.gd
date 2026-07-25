extends GutTest

## Scene glue only — smoke-level per games TDD scope; no coverage gate on
## scenes. Confirms the dev playtest lab instantiates and _ready() runs clean.


func test_lab_scene_instantiates() -> void:
	var node = load("res://scenes/dev/lab.tscn").instantiate()
	add_child_autofree(node)
	assert_not_null(node)
