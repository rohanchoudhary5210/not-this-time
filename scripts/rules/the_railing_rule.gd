class_name TheRailingRule
extends BaseRule

var _railing_block:StaticBody2D=null
var player_died: bool = false

func _init() -> void:
	rule_name = "the_railing"

func activate(root: Node2D, params: Dictionary = {}) -> void:
	super.activate(root, params)
	
	if not EventBus.entity_died.is_connected(_on_entity_died):
		EventBus.entity_died.connect(_on_entity_died)
	
	if not _is_scene_valid():
		return
	
	_railing_block=scene_root.get_node_or_null("Gameplay/Railing") as StaticBody2D
	if _railing_block==null:
		_railing_block = scene_root.find_child("Railing", true, false) as StaticBody2D
	activate_railing()

	EventBus.rule_action_triggered.emit("the_railing", {"source": _railing_block})

func deactivate() -> void:
	deactivate_railing()
	if EventBus.entity_died.is_connected(_on_entity_died):
		EventBus.entity_died.disconnect(_on_entity_died)
	super.deactivate()

func _is_scene_valid() -> bool:
	return scene_root != null and is_instance_valid(scene_root) and scene_root.is_inside_tree()

func _on_entity_died(entity: Node2D) -> void:
	if entity.is_in_group("player") or entity.name == "Player":
		player_died = true
		
func activate_railing():
	if _railing_block!=null:
		_railing_block.visible=true
		_railing_block.process_mode=Node.PROCESS_MODE_INHERIT
		_railing_block.set_collision_layer_value(1,true)
		var col = _railing_block.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col:
			col.disabled = false

func deactivate_railing():
	if _railing_block!=null:
		_railing_block.visible=false
		_railing_block.process_mode=Node.PROCESS_MODE_DISABLED
		_railing_block.set_collision_layer_value(1,false)
		var col = _railing_block.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col:
			col.disabled = true
