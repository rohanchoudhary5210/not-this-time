class_name PushableComponent
extends Node

signal pushed(direction: Vector2, force: float)
signal enabled_changed(is_enabled: bool)

@export var is_enabled: bool = true:
	set(value):
		if is_enabled != value:
			is_enabled = value
			if not is_enabled:
				push_velocity = Vector2.ZERO
			enabled_changed.emit(is_enabled)

@export var decay_speed: float = 600.0
@export var mass_multiplier: float = 1.0
@export var max_push_speed: float = 2000.0
@export var allow_vertical: bool = false

var push_velocity: Vector2 = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if push_velocity != Vector2.ZERO:
		push_velocity = push_velocity.move_toward(Vector2.ZERO, decay_speed * delta)


func apply_push(direction: Vector2, force: float) -> void:
	if not is_enabled:
		return

	if direction == Vector2.ZERO or force <= 0.0:
		return

	var effective_mass: float = maxf(mass_multiplier, 0.01)
	var final_force: float = force / effective_mass
	var dir_norm: Vector2 = direction.normalized()
	
	if not allow_vertical:
		dir_norm.y = 0.0
		if dir_norm != Vector2.ZERO:
			dir_norm = dir_norm.normalized()

	var added_velocity: Vector2 = dir_norm * final_force
	push_velocity = (push_velocity + added_velocity).limit_length(max_push_speed)
	pushed.emit(dir_norm, final_force)


func get_push_velocity() -> Vector2:
	if not is_enabled:
		return Vector2.ZERO
	return push_velocity


func is_being_pushed() -> bool:
	return is_enabled and push_velocity.length_squared() > 100.0


func clear_push() -> void:
	push_velocity = Vector2.ZERO


func enable() -> void:
	is_enabled = true


func disable() -> void:
	is_enabled = false


func set_enabled(value: bool) -> void:
	is_enabled = value


func toggle_enabled() -> bool:
	is_enabled = not is_enabled
	return is_enabled
