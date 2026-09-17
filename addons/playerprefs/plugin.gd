@tool
extends EditorPlugin

func _enter_tree():
	add_autoload_singleton("Prefs", "res://addons/playerprefs/prefs.gd")

func _exit_tree():
	remove_autoload_singleton("Prefs")
