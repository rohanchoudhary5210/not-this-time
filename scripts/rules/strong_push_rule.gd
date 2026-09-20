class_name StrongPushRule
extends BaseRule

@export var strong_force: float = 600.0
var _original_force: float = 300.0
var _target_pusher: PusherComponent = null


func _init() -> void:
	rule_name = "strong_push"


func activate(root: Node2D, params: Dictionary = {}) -> void:
	super.activate(root, params)
	print("[StrongPushRule] Active")
	
	var enemy: Node = root.get_node_or_null("Women")
	if enemy == null:
		enemy = root.get_tree().get_first_node_in_group("enemy")

	if enemy != null:
		_target_pusher = enemy.get_node_or_null("PusherComponent") as PusherComponent
		if _target_pusher != null:
			_original_force = _target_pusher.default_force
			_target_pusher.default_force = strong_force


func deactivate() -> void:
	if _target_pusher != null and is_instance_valid(_target_pusher):
		_target_pusher.default_force = _original_force
		_target_pusher = null
	super.deactivate()
