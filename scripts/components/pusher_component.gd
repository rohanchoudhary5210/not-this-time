class_name PusherComponent
extends Node

signal push_performed(target: Node, direction: Vector2, force: float)
signal enabled_changed(is_enabled: bool)

@export var default_force: float = 300.0

@export var is_enabled: bool = true:
	set(value):
		if is_enabled != value:
			is_enabled = value
			is_active = value
			enabled_changed.emit(is_enabled)

# Backward-compatible property alias
var is_active: bool = true:
	get:
		return is_enabled
	set(value):
		is_enabled = value


func enable() -> void:
	is_enabled = true


func disable() -> void:
	is_enabled = false


func set_enabled(value: bool) -> void:
	is_enabled = value


func push_target(target: Node, direction: Vector2, force: float = -1.0) -> bool:
	if not is_enabled or target == null:
		return false

	var final_force: float = default_force if force < 0.0 else force
	
	# 1. Find PushableComponent on target (by class type or node name)
	var pushable: PushableComponent = _find_pushable(target)
	if pushable != null:
		if not pushable.is_enabled:
			return false
		pushable.apply_push(direction, final_force)
		push_performed.emit(target, direction, final_force)
		return true
		
	# 2. Backward-compatible fallback if target uses legacy push method
	if target.has_method("push"):
		target.push(direction, final_force)
		push_performed.emit(target, direction, final_force)
		return true

	return false


func _find_pushable(target: Node) -> PushableComponent:
	if target is PushableComponent:
		return target as PushableComponent
	if target.has_node("PushableComponent"):
		return target.get_node("PushableComponent") as PushableComponent
	for child in target.get_children():
		if child is PushableComponent:
			return child as PushableComponent
	return null
