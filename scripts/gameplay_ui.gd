extends CanvasLayer

@onready var level: Label = $Control/Level
@onready var instruction: Label = $Control/Instruction

func _ready() -> void:
	GameManager.level_update.connect(_level_text_update)
	_level_text_update(GameManager.level_id)

func _level_text_update(_level_id:int):
	level.text=str(_level_id)
	instruction.text=LevelManager.get_current_name()

func _on_right_button_down() -> void:
	Input.action_press("move_right")

func _on_right_button_up() -> void:
	Input.action_release("move_right")

func _on_left_button_down() -> void:
	Input.action_press("move_left")

func _on_left_button_up() -> void:
	Input.action_release("move_left")
