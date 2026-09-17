@tool
class_name ProjectScanner
extends RefCounted

## Discovers relevant asset files in the project filesystem without loading full resource objects.

const AssetNodeScript = preload("res://addons/asset_dependency_visualizer/core/asset_node.gd")

const DEFAULT_EXTENSIONS: Array[String] = [
	"tscn", "scn", "gd", "cs", "tres", "res", "theme",
	"png", "jpg", "jpeg", "webp", "svg", "tga", "hdr", "exr",
	"wav", "ogg", "mp3", "flac",
	"glb", "gltf", "obj", "blend", "fbx", "dae",
	"ttf", "otf", "woff", "woff2", "fontdata",
	"anim", "animation",
	"material", "shader", "gdshader"
]

const IGNORED_PREFIXES: Array[String] = [
	"res://.godot",
	"res://.git",
	"res://addons/asset_dependency_visualizer", # Prevent self-scanning loop unless configured
	"res://reports" # Output directory for exported reports and snapshots
]

var supported_extensions: Array[String] = []
var _re_tool_script: RegEx

func _init(p_custom_extensions: Array[String] = []) -> void:
	_re_tool_script = RegEx.create_from_string('(?m)^[ \\t]*(?:@?tool\\b|\\[(?:Godot\\.)?Tool\\])')
	if p_custom_extensions.size() > 0:
		supported_extensions = p_custom_extensions
	else:
		supported_extensions = DEFAULT_EXTENSIONS.duplicate()

## Scans the project directory and returns a dictionary mapping asset path -> AssetNode
func scan_project(root_path: String = "res://") -> Dictionary:
	var nodes: Dictionary = {}
	_scan_dir_recursive(root_path, nodes)
	_detect_project_entry_points(nodes)
	return nodes

func _scan_dir_recursive(dir_path: String, out_nodes: Dictionary) -> void:
	for prefix in IGNORED_PREFIXES:
		if dir_path.begins_with(prefix):
			return

	var dir: DirAccess = DirAccess.open(dir_path)
	if not dir:
		push_warning("AssetDependencyVisualizer: Cannot open directory " + dir_path)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while not file_name.is_empty():
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path: String = dir_path.path_join(file_name)

		if dir.current_is_dir():
			_scan_dir_recursive(full_path, out_nodes)
		else:
			var ext: String = file_name.get_extension().to_lower()
			if supported_extensions.has(ext):
				var node: AssetNode = _create_asset_node(full_path)
				if node:
					out_nodes[full_path] = node

		file_name = dir.get_next()
	dir.list_dir_end()

func _create_asset_node(file_path: String) -> AssetNode:
	var node: AssetNode = AssetNodeScript.new(file_path)
	
	# Extract metadata safely
	if FileAccess.file_exists(file_path):
		var fa: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if fa:
			node.size_bytes = fa.get_length()
			if node.type == AssetNode.Category.SCRIPT:
				var lines_read: int = 0
				while not fa.eof_reached() and lines_read < 30:
					var line: String = fa.get_line()
					lines_read += 1
					if _re_tool_script and _re_tool_script.search(line):
						node.is_tool_script = true
						break
			fa.close()
		node.modified_time = FileAccess.get_modified_time(file_path)
	
	# Attempt UID discovery if Godot 4 ResourceUID is active
	if ResourceLoader.has_method("get_resource_uid"):
		var uid_val: int = ResourceLoader.get_resource_uid(file_path)
		if uid_val != ResourceUID.INVALID_ID:
			node.uid = ResourceUID.id_to_text(uid_val)
			
	return node

func _detect_project_entry_points(nodes: Dictionary) -> void:
	# 1. Main scene entry point
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if not main_scene.is_empty() and nodes.has(main_scene):
		var n: AssetNode = nodes[main_scene]
		n.is_main_scene = true

	# 2. Autoload entry points (Godot 4 compatible)
	for p in ProjectSettings.get_property_list():
		var prop_name: String = p["name"]
		if prop_name.begins_with("autoload/"):
			var raw_path: String = str(ProjectSettings.get_setting(prop_name, ""))
			if raw_path.begins_with("*"):
				raw_path = raw_path.substr(1)
			if nodes.has(raw_path):
				var n: AssetNode = nodes[raw_path]
				n.is_autoload = true

	# Also check project.godot [autoload] section directly
	if FileAccess.file_exists("res://project.godot"):
		var cf_autoload: ConfigFile = ConfigFile.new()
		if cf_autoload.load("res://project.godot") == OK and cf_autoload.has_section("autoload"):
			for key in cf_autoload.get_section_keys("autoload"):
				var raw_path: String = str(cf_autoload.get_value("autoload", key, ""))
				if raw_path.begins_with("*"):
					raw_path = raw_path.substr(1)
				if nodes.has(raw_path):
					var n: AssetNode = nodes[raw_path]
					n.is_autoload = true

	# 3. Project Settings Assets (icon, splash screen, default theme, custom cursor, bus layouts)
	var settings_keys: Array[String] = [
		"application/config/icon",
		"application/boot_splash/image",
		"gui/theme/custom",
		"gui/theme/custom_font",
		"audio/default_bus_layout",
		"rendering/environment/defaults/default_environment",
		"display/mouse_cursor/custom_image"
	]
	for k in settings_keys:
		if ProjectSettings.has_setting(k):
			var val: String = str(ProjectSettings.get_setting(k))
			if not val.is_empty() and nodes.has(val):
				var n: AssetNode = nodes[val]
				n.is_exported = true

	# 4. Check export_presets.cfg for explicitly included files
	if FileAccess.file_exists("res://export_presets.cfg"):
		var cf: ConfigFile = ConfigFile.new()
		if cf.load("res://export_presets.cfg") == OK:
			for section in cf.get_sections():
				if cf.has_section_key(section, "include_filter"):
					var inc_files: String = str(cf.get_value(section, "include_filter", ""))
					for inc in inc_files.split(","):
						var clean_inc: String = inc.strip_edges()
						if not clean_inc.is_empty() and nodes.has(clean_inc):
							var n: AssetNode = nodes[clean_inc]
							n.is_exported = true
