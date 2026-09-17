extends Area2D

signal body_died(body:Node2D)

func _ready() -> void:
	#body_entered.connect(_on_body_entered)
	body_died.connect(_on_death)

func _on_body_entered(body: Node2D) -> void:
	print("DeathZone hit by: ", body.name)
	body_died.emit(body)

func _on_death(body: Node2D) -> void:
	print("DeathZone caught: ", body.name)
	EventBus.entity_died.emit(body)
	GameManager.level_passed.emit(body)
	if body.is_in_group("player") or body.name == "Player":
		EventBus.level_restarted.emit()
		_restart_level()


func _restart_level() -> void:
	get_tree().reload_current_scene()
