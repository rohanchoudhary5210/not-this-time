extends CharacterBody2D

@export var speed: float
@export var jump_velocity: float
@export var gravity: float

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pushable_component: PushableComponent = get_node_or_null("PushableComponent")
@onready var screen_wrap_component: ScreenWrapComponent = get_node_or_null("ScreenWrapComponent")

var can_move: bool = true


func _ready() -> void:
	add_to_group("player")
	if pushable_component == null:
		pushable_component = PushableComponent.new()
		pushable_component.name = "PushableComponent"
		add_child(pushable_component)
	if screen_wrap_component == null:
		screen_wrap_component = ScreenWrapComponent.new()
		screen_wrap_component.name = "ScreenWrapComponent"
		add_child(screen_wrap_component)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction := Input.get_axis("move_left", "move_right") if can_move else 0.0
	var push_vel := pushable_component.get_push_velocity() if pushable_component else Vector2.ZERO
	velocity.x = (direction * speed) + push_vel.x

	if direction != 0:
		animated_sprite.play("run")
		animated_sprite.flip_h = direction < 0
	elif abs(velocity.x) > 10.0:
		animated_sprite.play("run")
		animated_sprite.flip_h = velocity.x < 0
	else:
		animated_sprite.play("idle")

	if can_move and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()

	if screen_wrap_component:
		screen_wrap_component.wrap_body()


func push(direction: Vector2, force: float) -> void:
	if pushable_component:
		pushable_component.apply_push(direction, force)


func set_can_move(val: bool) -> void:
	can_move = val
