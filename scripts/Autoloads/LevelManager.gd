#class_name LevelManager
extends Node

const LEVEL_DATA_PATH ="res://data/levels.json"

var level_data:Dictionary={}
var current_level_id:int=1

func _ready() -> void:
	load_level_data()
	current_level_id=Prefs.get_int("level_id",1)

func load_level_data():
	var file:=FileAccess.open(LEVEL_DATA_PATH,FileAccess.READ)
	
	if file==null:
		push_error("No level file available")
		return
	
	var data=JSON.parse_string(file.get_as_text())
	
	if data==null:
		push_error("No data available")
		return
	
	level_data=data

func get_level(level_id: int)->Dictionary:
	for level in level_data.get("levels",[]):
		if level.get("id")== level_id:
			return level
	
	return {}

func get_current_level()->Dictionary:
	current_level_id = Prefs.get_int("level_id", 1)
	var lvl = get_level(current_level_id)
	#if lvl.is_empty():
		#return get_level(1)
	return lvl


func get_current_rules()->Array:
	var level:=get_current_level()
	if level.is_empty():
		return []
	
	return level.get("rules",[])

func get_current_name()->String:
	var level:=get_current_level()
	if level.is_empty():
		return "NOT THIS TIME"
	
	return level.get("name","NOT THIS TIME")

func start_level(level_id: int) -> void:
	var level := get_level(level_id)
	if level.is_empty():
		push_error("Level not found: " + str(level_id))
		return
	current_level_id = level_id
	var scene_path: String = level_data["defaults"]["scene"]
	get_tree().change_scene_to_file(scene_path)
