class_name WomanPushRule
extends BaseRule

func _init() -> void:
	rule_name = "woman_push"

func activate(root: Node2D, params: Dictionary = {}) -> void:
	super.activate(root, params)
	
	if scene_root != null and scene_root.is_inside_tree():
		var timer := scene_root.get_tree().create_timer(2.0)
		await timer.timeout
		
		# If scene was destroyed while waiting, abort safely
		if scene_root == null or not is_instance_valid(scene_root):
			return

		var enemy = scene_root.get_node_or_null("Women")
		if enemy == null:
			enemy = scene_root.get_tree().get_first_node_in_group("enemy")

		if enemy != null and is_instance_valid(enemy):
			if enemy.has_method("start_push_action"):
				enemy.start_push_action(300.0)
			elif enemy.has_method("_on_woman_pushed"):
				enemy._on_woman_pushed()

		EventBus.rule_action_triggered.emit("woman_push", {"source": enemy})
