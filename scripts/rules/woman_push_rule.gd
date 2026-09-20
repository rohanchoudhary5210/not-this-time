class_name WomanPushRule
extends BaseRule

@export var push_delay: float = 2.0
@export var survive_check_time: float = 3.5
var player_died: bool = false
var _player:CharacterBody2D=null
var _enemy:CharacterBody2D=null

func _init() -> void:
	rule_name = "woman_push"


func activate(root: Node2D, params: Dictionary = {}) -> void:
	super.activate(root, params)
	player_died = false

	# 1. Listen for player death
	if not EventBus.entity_died.is_connected(_on_entity_died):
		EventBus.entity_died.connect(_on_entity_died)

	if not _is_scene_valid():
		return

	# 2. Get Enemy and Player
	_enemy = scene_root.get_node_or_null("Women") as CharacterBody2D
	if _enemy == null:
		_enemy = scene_root.get_tree().get_first_node_in_group("enemy") as CharacterBody2D

	_player = scene_root.get_node_or_null("Player") as CharacterBody2D
	if _player == null:
		_player = scene_root.get_tree().get_first_node_in_group("player") as CharacterBody2D

	# Modular: Ensure components are present if not manually added in scene dock
	if _enemy != null and not _enemy.has_node("PusherComponent"):
		var pusher := PusherComponent.new()
		pusher.name = "PusherComponent"
		_enemy.add_child(pusher)

	if _player != null and not _player.has_node("PushableComponent"):
		var pushable := PushableComponent.new()
		pushable.name = "PushableComponent"
		_player.add_child(pushable)

	# 3. Wait initial delay before pushing
	var timer := scene_root.get_tree().create_timer(push_delay)
	await timer.timeout
	if not _is_scene_valid():
		return
	
	if _player != null and is_instance_valid(_player):
		_player.can_move = false

	# 4. Start push action
	if _enemy != null and is_instance_valid(_enemy):
		if _enemy.has_method("start_push_action"):
			_enemy.start_push_action(300.0)
		elif _enemy.has_method("_on_woman_pushed"):
			_enemy._on_woman_pushed()

	EventBus.rule_action_triggered.emit("woman_push", {"source": _enemy})

	# 5. Wait to check if player died or survived
	var result_timer := scene_root.get_tree().create_timer(survive_check_time)
	await result_timer.timeout
	if not _is_scene_valid():
		return

	# 6. If player did not die -> LEVEL FAILURE!
	if not player_died:
		_trigger_level_failure()


func _on_entity_died(entity: Node2D) -> void:
	if entity.is_in_group("player") or entity.name == "Player":
		player_died = true


func _trigger_level_failure() -> void:
	print("[WomanPushRule] Level Failed: Player survived the push!")
	EventBus.level_restarted.emit()
	if _is_scene_valid():
		scene_root.get_tree().reload_current_scene()


func _is_scene_valid() -> bool:
	return scene_root != null and is_instance_valid(scene_root) and scene_root.is_inside_tree()


func deactivate() -> void:
	if _player != null and is_instance_valid(_player):
		_player.can_move = true
		
	if EventBus.entity_died.is_connected(_on_entity_died):
		EventBus.entity_died.disconnect(_on_entity_died)
	super.deactivate()
