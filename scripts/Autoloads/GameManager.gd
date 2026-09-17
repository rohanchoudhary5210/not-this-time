extends Node

signal level_passed(body:Node2D)
signal level_update(new_level: int)

#-----------------------------------------
signal woman_pushed

var level_id:int=0
var active_rules:Array[String]=[]

func _ready() -> void:
	level_id = Prefs.get_int("level_id", 1)
	level_passed.connect(_on_level_completed)

func _on_level_completed(body:Node2D):
	level_id+=1
	Prefs.set_int("level_id",level_id)
	print(level_id)
	Prefs.save()
	level_update.emit(level_id)

func enable_rule(rule: String) -> void:
	if rule not in active_rules:
		active_rules.append(rule)

func clear_rules() -> void:
	active_rules.clear()

func has_rule(rule: String) -> bool:
	return rule in active_rules
