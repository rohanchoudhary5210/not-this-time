@tool
extends EditorPlugin

## Entry point for Asset Dependency Visualizer Godot Editor Plugin.

const MainDockScript = preload("res://addons/asset_dependency_visualizer/ui/main_dock.gd")

const DOCK_NAME: String = "Asset Dependency Visualizer"
const MENU_ITEM_NAME: String = "Asset Dependency Visualizer"

var dock_instance: Control
var floating_window: Window

func _enter_tree() -> void:
	# 1. Register dock tab on right panel
	dock_instance = MainDockScript.new()
	dock_instance.name = DOCK_NAME
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_instance)

	# 2. Register entry under Godot's top menu "Project -> Tools"
	add_tool_menu_item(MENU_ITEM_NAME, _open_floating_window)

	print("AssetDependencyVisualizer: Plugin initialized and registered under Tools menu.")

func _exit_tree() -> void:
	# Remove menu item
	remove_tool_menu_item(MENU_ITEM_NAME)

	# Remove dock
	if dock_instance:
		remove_control_from_docks(dock_instance)
		dock_instance.free()

	# Close floating window if open
	if floating_window and is_instance_valid(floating_window):
		floating_window.queue_free()
		floating_window = null

	print("AssetDependencyVisualizer: Plugin unloaded.")

func _open_floating_window() -> void:
	if floating_window and is_instance_valid(floating_window):
		floating_window.grab_focus()
		return

	floating_window = Window.new()
	floating_window.title = "Asset Dependency Visualizer — Floating Window"
	floating_window.size = Vector2i(1100, 750)
	floating_window.close_requested.connect(func():
		if floating_window and is_instance_valid(floating_window):
			floating_window.queue_free()
			floating_window = null
	)

	var dock_ui: Control = MainDockScript.new()
	dock_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	floating_window.add_child(dock_ui)

	if Engine.is_editor_hint():
		EditorInterface.get_base_control().add_child(floating_window)
		floating_window.popup_centered()

func _has_main_screen() -> bool:
	return false

func _get_plugin_name() -> String:
	return DOCK_NAME

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons") if Engine.is_editor_hint() else null
