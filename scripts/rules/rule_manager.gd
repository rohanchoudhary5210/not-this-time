class_name RuleManager
extends Node

var active_rules: Dictionary = {}

const RULE_REGISTRY: Dictionary = {
	"woman_push": preload("res://scripts/rules/woman_push_rule.gd"),
	"strong_push": preload("res://scripts/rules/strong_push_rule.gd"),
	"the_railing": preload("res://scripts/rules/the_railing_rule.gd")
}

func apply_rules(rules: Array, scene_root: Node2D) -> void:
	clear_rules()
	for rule_entry in rules:
		var rule_str: String = str(rule_entry).strip_edges()
		if rule_str.is_empty():
			continue
		activate_rule(rule_str, scene_root)

func activate_rule(rule_name: String, scene_root: Node2D) -> void:
	if has_rule(rule_name):
		return
		
	if RULE_REGISTRY.has(rule_name):
		var rule_class = RULE_REGISTRY[rule_name]
		var rule_instance: BaseRule = rule_class.new()
		active_rules[rule_name] = rule_instance
		GameManager.enable_rule(rule_name)
		EventBus.rule_activated.emit(rule_name)
		rule_instance.activate(scene_root)
	else:
		push_warning("Unknown rule requested: " + rule_name)

func has_rule(rule_name: String) -> bool:
	return active_rules.has(rule_name)

func clear_rules() -> void:
	for rule_name in active_rules:
		var rule_instance: BaseRule = active_rules[rule_name]
		if rule_instance != null:
			rule_instance.deactivate()
	active_rules.clear()
	GameManager.clear_rules()
