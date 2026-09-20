extends CharacterBody2D

@export_group("Movement")
@export var speed: float = 0.0
@export var jump_velocity: float = 0.0
@export var gravity: float = 1000.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_pushing: bool = false


func _ready() -> void:
	add_to_group("enemy")
	# Legacy connection if GameManager signal is still emitted anywhere
	if GameManager.has_signal("woman_pushed"):
		GameManager.woman_pushed.connect(_on_woman_pushed)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Check pushable/pullable external velocities if those components are attached
	var pushable: PushableComponent = get_node_or_null("PushableComponent") as PushableComponent
	var pullable: PullableComponent = get_node_or_null("PullableComponent") as PullableComponent
	
	var push_vel: Vector2 = pushable.get_push_velocity() if (pushable and pushable.is_enabled) else Vector2.ZERO
	var pull_vel: Vector2 = pullable.get_pull_velocity() if (pullable and pullable.is_enabled) else Vector2.ZERO
	if push_vel != Vector2.ZERO or pull_vel != Vector2.ZERO:
		velocity.x += push_vel.x + pull_vel.x
		velocity.y += push_vel.y + pull_vel.y

	if is_pushing:
		velocity.x = speed

	move_and_slide()

	if velocity.x != 0:
		if animated_sprite:
			animated_sprite.play("run")
			animated_sprite.flip_h = velocity.x < 0
	else:
		if animated_sprite:
			animated_sprite.play("idle")

	# Pushing logic only when actively pushing and pusher component is attached & enabled
	var pusher: PusherComponent = get_node_or_null("PusherComponent") as PusherComponent
	if is_pushing and pusher != null and pusher.is_enabled:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			
			if collider is CharacterBody2D:
				var push_dir := Vector2.RIGHT
				if velocity.x != 0:
					push_dir = Vector2(sign(velocity.x), 0)
				pusher.push_target(collider, push_dir, speed if speed > 0 else 300.0)
				stop_push_action()
				break


# Component Getters
func get_pusher() -> PusherComponent:
	return get_node_or_null("PusherComponent") as PusherComponent


func get_pushable() -> PushableComponent:
	return get_node_or_null("PushableComponent") as PushableComponent


func get_pullable() -> PullableComponent:
	return get_node_or_null("PullableComponent") as PullableComponent


# Action Methods
func start_push_action(push_speed: float = 300.0) -> void:
	is_pushing = true
	speed = push_speed
	velocity.x = 1.0 * speed


func stop_push_action() -> void:
	is_pushing = false
	velocity.x = 0.0


func _on_woman_pushed() -> void:
	start_push_action(300.0)


# Push/Pull receivers
func push(direction: Vector2, force: float) -> void:
	var pushable: PushableComponent = get_pushable()
	if pushable and pushable.is_enabled:
		pushable.apply_push(direction, force)
	else:
		velocity.x = direction.x * force


func pull(direction: Vector2, force: float) -> void:
	var pullable: PullableComponent = get_pullable()
	if pullable and pullable.is_enabled:
		pullable.apply_pull(direction, force)
