class_name StrongPushRule
extends BaseRule

func _init() -> void:
	rule_name = "strong_push"

func activate(root: Node2D, params: Dictionary = {}) -> void:
	super.activate(root, params)
	print("[StrongPushRule] Active")
