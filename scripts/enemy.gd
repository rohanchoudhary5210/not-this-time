extends CharacterBody2D

@export var speed: float
@export var jump_velocity:float
@export var gravity:float

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pusher_component: PusherComponent = get_node_or_null("PusherComponent")

var is_pushing: bool = false


func _ready() -> void:
	add_to_group("enemy")
	if pusher_component == null:
		pusher_component = PusherComponent.new()
		pusher_component.name = "PusherComponent"
		add_child(pusher_component)
	# Legacy connection if GameManager signal is still emitted anywhere
	if GameManager.has_signal("woman_pushed"):
		GameManager.woman_pushed.connect(_on_woman_pushed)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()

	if velocity.x != 0:
		if animated_sprite:
			animated_sprite.play("run")
			animated_sprite.flip_h = velocity.x < 0
	else:
		if animated_sprite:
			animated_sprite.play("idle")

	# Pushing logic only when actively pushing
	if is_pushing:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			
			if collider is CharacterBody2D and pusher_component != null:
				var push_dir := Vector2.RIGHT
				if velocity.x != 0:
					push_dir = Vector2(sign(velocity.x), 0)
				pusher_component.push_target(collider, push_dir, speed if speed > 0 else 300.0)


func start_push_action(push_speed: float = 300.0) -> void:
	is_pushing = true
	speed = push_speed
	velocity.x = 1 * speed


func _on_woman_pushed() -> void:
	start_push_action(300.0)


func push(direction: Vector2, force: float) -> void:
	velocity.x = direction.x * force
