class_name BaseRule
extends RefCounted

var rule_name: String = ""
var scene_root: Node2D = null

func activate(root: Node2D, _params: Dictionary = {}) -> void:
	scene_root = root

func deactivate() -> void:
	scene_root = null
