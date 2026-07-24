class_name ChoiceCard
extends Minigame

## Generic choice screen: every Button child of %Choices carries its choice
## string in the button's name, lowercased (Cook -> "cook").


func _ready() -> void:
	for button in get_node("%Choices").get_children():
		if button is Button:
			button.pressed.connect(_on_choice.bind(button.name.to_lower()))


func _on_choice(choice: String) -> void:
	_finish_with({"score": 1.0, "skipped": false, "choice": choice})
