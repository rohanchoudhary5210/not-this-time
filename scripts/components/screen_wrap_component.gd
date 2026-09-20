class_name ScreenWrapComponent
extends Node

signal wrapped(new_position: Vector2)
signal enabled_changed(is_enabled: bool)

@export var is_enabled: bool = true:
	set(value):
		if is_enabled != value:
			is_enabled = value
			enabled_changed.emit(is_enabled)

@export var body: Node2D
@export var margin: float = 0.0
@export var wrap_horizontal: bool = true
@export var wrap_vertical: bool = false
@export var auto_process_wrap: bool = false


func _ready() -> void:
	if body == null and get_parent() is Node2D:
		body = get_parent() as Node2D


func _physics_process(_delta: float) -> void:
	if auto_process_wrap and is_enabled:
		wrap_body()


func wrap_body() -> void:
	if not is_enabled or body == null or not body.is_inside_tree():
		return

	var original_pos: Vector2 = body.global_position
	var new_pos: Vector2 = original_pos

	# Dynamically look for camera via group, viewport, or fallback name
	var camera: Camera2D = body.get_tree().get_first_node_in_group("camera") as Camera2D
	if camera == null:
		camera = body.get_viewport().get_camera_2d()
	if camera == null and body.get_parent() != null:
		camera = body.get_parent().get_node_or_null("LevelCamera") as Camera2D

	if camera != null:
		var half_width: float = body.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
		var left_edge: float = camera.global_position.x - half_width - margin
		var right_edge: float = camera.global_position.x + half_width + margin

		if wrap_horizontal:
			if body.global_position.x < left_edge:
				new_pos.x = right_edge
			elif body.global_position.x > right_edge:
				new_pos.x = left_edge

		if wrap_vertical:
			var half_height: float = body.get_viewport_rect().size.y / (2.0 * camera.zoom.y)
			var top_edge: float = camera.global_position.y - half_height - margin
			var bottom_edge: float = camera.global_position.y + half_height + margin
			if body.global_position.y < top_edge:
				new_pos.y = bottom_edge
			elif body.global_position.y > bottom_edge:
				new_pos.y = top_edge
	else:
		# Fallback to viewport rect if no camera is available
		var viewport_size: Vector2 = body.get_viewport_rect().size
		if wrap_horizontal:
			if body.global_position.x < -margin:
				new_pos.x = viewport_size.x + margin
			elif body.global_position.x > viewport_size.x + margin:
				new_pos.x = -margin

		if wrap_vertical:
			if body.global_position.y < -margin:
				new_pos.y = viewport_size.y + margin
			elif body.global_position.y > viewport_size.y + margin:
				new_pos.y = -margin

	if new_pos != original_pos:
		body.global_position = new_pos
		wrapped.emit(new_pos)


func enable() -> void:
	is_enabled = true


func disable() -> void:
	is_enabled = false


func set_enabled(value: bool) -> void:
	is_enabled = value


func toggle_enabled() -> bool:
	is_enabled = not is_enabled
	return is_enabled
