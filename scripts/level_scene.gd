extends Node2D

@onready var rule_manager: RuleManager = get_node_or_null("RuleManager")
@onready var camera:Camera2D=get_node_or_null("LevelCamera")
@onready var ground_left:StaticBody2D=get_node_or_null("Gameplay/GroundLeft")
@onready var ground_right:StaticBody2D=get_node_or_null("Gameplay/GroundRight")
@onready var railing:StaticBody2D=get_node_or_null("Gameplay/Railing")
@onready var death_zone:Area2D=get_node_or_null("Gameplay/DeathZone")

func _ready() -> void:
	if rule_manager == null:
		rule_manager = RuleManager.new()
		rule_manager.name = "RuleManager"
		add_child(rule_manager)

	var level: Dictionary = LevelManager.get_current_level()
	var level_id: int = int(level.get("id", 1))

	print("Level ID: ", level_id)
	print("Level Name: ", level.get("name"))
	print("Rules: ", level.get("rules"))

	EventBus.level_started.emit(level_id, level)

	var rules: Array = level.get("rules", [])
	rule_manager.apply_rules(rules, self)
	_centralise_camera()
	_platform_setup()


func _centralise_camera():
	if camera != null:
		var viewport_size := get_viewport_rect().size
		camera.global_position = viewport_size / 2.0

func _platform_setup():
	var viewport_width := get_viewport_rect().size.x
	var viewport_height := get_viewport_rect().size.y
	if ground_left!=null:
		var left_size = ground_left.get_node("CollisionShape2D")
		var expected_pos_x:float=(left_size.shape.size.x)/2
		var expected_pos_y:float=(viewport_height)/2 + 50.0
		ground_left.global_position=Vector2(expected_pos_x,expected_pos_y)

	if ground_right!=null:
		var right_size = ground_right.get_node("CollisionShape2D")
		var expected_pos_x:float=viewport_width-((right_size.shape.size.x/2))
		var expected_pos_y:float=(viewport_height)/2 + 50.0
		ground_right.global_position=Vector2(expected_pos_x,expected_pos_y)
		print(ground_right.global_position)

	if death_zone!=null:
		var death_size=viewport_width-(
			ground_left.get_node("CollisionShape2D").shape.size.x +
			ground_right.get_node("CollisionShape2D").shape.size.x 
		)
		death_zone.get_node("CollisionShape2D").shape.size.x == death_size
		death_zone.global_position=Vector2(
				viewport_width/2,
				viewport_height
		)