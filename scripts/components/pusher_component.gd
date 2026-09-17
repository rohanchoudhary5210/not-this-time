class_name PusherComponent
extends Node

@export var default_force: float = 300.0
@export var is_active: bool = true

func push_target(target: Node, direction: Vector2, force: float = -1.0) -> bool:
	if not is_active or target == null:
		return false

	var final_force: float = default_force if force < 0.0 else force
	
	# Look for PushableComponent on target or as child
	var pushable: PushableComponent = null
	if target is PushableComponent:
		pushable = target
	elif target.has_node("PushableComponent"):
		pushable = target.get_node("PushableComponent") as PushableComponent
	else:
		pushable = target.find_child("PushableComponent", true, false) as PushableComponent
		
	if pushable != null:
		pushable.apply_push(direction, final_force)
		return true
		
	# Backward-compatible fallback if target uses legacy push method
	if target.has_method("push"):
		target.push(direction, final_force)
		return true

	return false
