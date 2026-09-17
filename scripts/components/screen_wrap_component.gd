class_name ScreenWrapComponent
extends Node

@export var body: CharacterBody2D

func _ready() -> void:
	if body == null and get_parent() is CharacterBody2D:
		body = get_parent() as CharacterBody2D

func wrap_body() -> void:
	if body == null:
		return

	# Dynamically look for camera via group, viewport, or fallback name
	var camera: Camera2D = body.get_tree().get_first_node_in_group("camera") as Camera2D
	if camera == null:
		camera = body.get_viewport().get_camera_2d()
	if camera == null and body.get_parent() != null:
		camera = body.get_parent().get_node_or_null("LevelCamera") as Camera2D
	
	if camera != null:
		var half_width: float = body.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
		var left_edge: float = camera.global_position.x - half_width
		var right_edge: float = camera.global_position.x + half_width
		
		if body.global_position.x < left_edge:
			body.global_position.x = right_edge
		elif body.global_position.x > right_edge:
			body.global_position.x = left_edge
	else:
		# Fallback to viewport width if no camera is available
		var viewport_width: float = body.get_viewport_rect().size.x
		if body.global_position.x < 0.0:
			body.global_position.x = viewport_width
		elif body.global_position.x > viewport_width:
			body.global_position.x = 0.0
