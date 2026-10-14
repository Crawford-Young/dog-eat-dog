class_name ChoiceCard
extends Minigame

## Generic choice screen: every Button child of %Choices carries its choice
## string in the button's name, lowercased (Cook -> "cook"). If the scene marks
## a %Prompt label, its authored copy types itself out when setup() runs.
## params["disabled_choices"] greys those choices out (what the dog can't pay
## for at the coffee cart).

var _prompt_text: String = ""

@onready var _typer := TypewriterLabel.new()


func _ready() -> void:
	add_child(_typer)
	var prompt := get_node_or_null("%Prompt") as Control
	if prompt != null:
		_prompt_text = str(prompt.get("text"))
		prompt.set("text", "")
		_typer.bind(prompt)
	for button in get_node("%Choices").get_children():
		if button is Button:
			button.pressed.connect(_on_choice.bind(button.name.to_lower()))


func setup(params: Dictionary) -> void:
	var disabled: Array = params.get("disabled_choices", [])
	for button in get_node("%Choices").get_children():
		if button is Button:
			button.disabled = button.name.to_lower() in disabled
	_typer.play(_prompt_text, params.get("text_speed", Typewriter.DEFAULT_CHARS_PER_SEC))


func _on_choice(choice: String) -> void:
	_finish_with({"score": 1.0, "skipped": false, "choice": choice})
