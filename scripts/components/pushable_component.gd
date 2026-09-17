class_name PushableComponent
extends Node

signal pushed(direction: Vector2, force: float)

@export var decay_speed: float = 600.0
var push_velocity: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	push_velocity = push_velocity.move_toward(Vector2.ZERO, decay_speed * delta)

func apply_push(direction: Vector2, force: float) -> void:
	push_velocity = direction.normalized() * force
	pushed.emit(direction, force)

func get_push_velocity() -> Vector2:
	return push_velocity

func is_being_pushed() -> bool:
	return push_velocity.length_squared() > 100.0
