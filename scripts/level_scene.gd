extends Node2D

@onready var rule_manager: RuleManager = get_node_or_null("RuleManager")


func _ready() -> void:
	if rule_manager == null:
		rule_manager = RuleManager.new()
		rule_manager.name = "RuleManager"
		add_child(rule_manager)

	var level: Dictionary = LevelManager.get_current_level()
	var level_id: int = int(level.get("id", 1))

	print("Level ID: ", level_id)
	print("Level Name: ", level.get("name"))
	print("Rules: ", level.get("rules"))

	EventBus.level_started.emit(level_id, level)

	var rules: Array = level.get("rules", [])
	rule_manager.apply_rules(rules, self)
