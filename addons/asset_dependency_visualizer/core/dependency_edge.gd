@tool
class_name DependencyEdge
extends RefCounted

## Represents a directed edge in the dependency graph (from_path -> to_path).
## Interpretation: from_path DEPENDS ON to_path (from_path calls/instantiates/references to_path).

enum RelationType {
	HARD_REFERENCE, # Scene subnode, script load/preload, resource property
	SOFT_REFERENCE, # Dynamic path, string reference
	SUB_SCENE,      # PackedScene instantiation inside scene tree
	SCRIPT_EXTENDS, # GDScript class inheritance
	RESOURCE_ATTACH # Texture/Audio attached to Node property
}

var from_path: String = ""
var to_path: String = ""
var relation_type: RelationType = RelationType.HARD_REFERENCE

func _init(p_from: String = "", p_to: String = "", p_type: RelationType = RelationType.HARD_REFERENCE) -> void:
	from_path = p_from
	to_path = p_to
	relation_type = p_type

func get_id() -> String:
	return "%s->%s" % [from_path, to_path]

func to_dict() -> Dictionary:
	return {
		"from": from_path,
		"to": to_path,
		"type": relation_type
	}
