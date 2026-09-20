class_name PullableComponent
extends Node

signal pulled(direction: Vector2, force: float)
signal enabled_changed(is_enabled: bool)

@export var is_enabled: bool = true:
	set(value):
		if is_enabled != value:
			is_enabled = value
			if not is_enabled:
				pull_velocity = Vector2.ZERO
			enabled_changed.emit(is_enabled)

@export var decay_speed: float = 600.0
@export var pull_resistance: float = 1.0
@export var max_pull_speed: float = 2000.0
@export var allow_vertical: bool = false

var pull_velocity: Vector2 = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if pull_velocity != Vector2.ZERO:
		pull_velocity = pull_velocity.move_toward(Vector2.ZERO, decay_speed * delta)


func apply_pull(direction: Vector2, force: float) -> void:
	if not is_enabled:
		return

	if direction == Vector2.ZERO or force <= 0.0:
		return

	var effective_resistance: float = maxf(pull_resistance, 0.01)
	var final_force: float = force / effective_resistance
	var dir_norm: Vector2 = direction.normalized()

	if not allow_vertical:
		dir_norm.y = 0.0
		if dir_norm != Vector2.ZERO:
			dir_norm = dir_norm.normalized()

	var added_velocity: Vector2 = dir_norm * final_force
	pull_velocity = (pull_velocity + added_velocity).limit_length(max_pull_speed)
	pulled.emit(dir_norm, final_force)


func apply_pull_towards(origin_position: Vector2, target_position: Vector2, force: float) -> void:
	var dir: Vector2 = target_position - origin_position
	if dir != Vector2.ZERO:
		apply_pull(dir.normalized(), force)


func get_pull_velocity() -> Vector2:
	if not is_enabled:
		return Vector2.ZERO
	return pull_velocity


func is_being_pulled() -> bool:
	return is_enabled and pull_velocity.length_squared() > 100.0


func clear_pull() -> void:
	pull_velocity = Vector2.ZERO


func enable() -> void:
	is_enabled = true


func disable() -> void:
	is_enabled = false


func set_enabled(value: bool) -> void:
	is_enabled = value


func toggle_enabled() -> bool:
	is_enabled = not is_enabled
	return is_enabled
