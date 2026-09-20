class_name PullerComponent
extends Node

signal pull_performed(target: Node, direction: Vector2, force: float)
signal enabled_changed(is_enabled: bool)

@export var default_force: float = 300.0

@export var is_enabled: bool = true:
	set(value):
		if is_enabled != value:
			is_enabled = value
			enabled_changed.emit(is_enabled)


func enable() -> void:
	is_enabled = true


func disable() -> void:
	is_enabled = false


func set_enabled(value: bool) -> void:
	is_enabled = value


func pull_target(target: Node, direction: Vector2, force: float = -1.0) -> bool:
	if not is_enabled or target == null:
		return false

	var final_force: float = default_force if force < 0.0 else force

	# 1. Find PullableComponent on target (by class type or node name)
	var pullable: PullableComponent = _find_pullable(target)
	if pullable != null:
		if not pullable.is_enabled:
			return false
		pullable.apply_pull(direction, final_force)
		pull_performed.emit(target, direction, final_force)
		return true

	# 2. Backward-compatible fallback if target uses legacy pull method
	if target.has_method("pull"):
		target.pull(direction, final_force)
		pull_performed.emit(target, direction, final_force)
		return true

	return false


func pull_target_towards(target: Node, puller_global_pos: Vector2, force: float = -1.0) -> bool:
	if not is_enabled or target == null:
		return false

	var target_pos: Vector2 = Vector2.ZERO
	if target is Node2D:
		target_pos = target.global_position
	elif target.get_parent() is Node2D:
		target_pos = target.get_parent().global_position
	else:
		return false

	var direction: Vector2 = (puller_global_pos - target_pos).normalized()
	return pull_target(target, direction, force)


func _find_pullable(target: Node) -> PullableComponent:
	if target is PullableComponent:
		return target as PullableComponent
	if target.has_node("PullableComponent"):
		return target.get_node("PullableComponent") as PullableComponent
	for child in target.get_children():
		if child is PullableComponent:
			return child as PullableComponent
	return null
