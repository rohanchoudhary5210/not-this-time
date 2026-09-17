class_name GrabRailingRule
extends BaseRule

func _init() -> void:
	rule_name = "grab_railing"

func activate(root: Node2D, params: Dictionary = {}) -> void:
	super.activate(root, params)
	print("[GrabRailingRule] Active")
