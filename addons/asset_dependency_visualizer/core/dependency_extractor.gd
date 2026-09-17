@tool
class_name DependencyExtractor
extends RefCounted

## Extracts direct dependencies for assets using Godot Native APIs, deep text-based regex parsing, and global class_name indexing.

# Regex patterns for extracting references from text-based files
var _re_res_string: RegEx
var _re_uid_string: RegEx
var _re_class_def: RegEx
var _re_cs_class_def: RegEx
var _re_tool_script: RegEx

# Global class index: ClassName (String) -> file_path (String)
var _class_name_to_path: Dictionary = {}
var _class_name_regexes: Dictionary = {}
var _is_class_index_built: bool = false

const TEXT_PARSEABLE_EXTENSIONS: Array[String] = [
	"tscn", "scn", "tres", "res", "gd", "cs", "material", "shader", "gdshader", "theme", "anim", "json", "xml", "txt", "cfg"
]

func _init() -> void:
	# Matches any quoted string starting with res://
	_re_res_string = RegEx.create_from_string('["\'](res://[^"\'\\n\\r<>]+)["\']')
	# Matches any quoted or unquoted string starting with uid://
	_re_uid_string = RegEx.create_from_string('(?:["\']|\\b)(uid://[a-zA-Z0-9_]+)(?:["\']|\\b)')
	# Matches class_name declarations in GDScript
	_re_class_def = RegEx.create_from_string('(?m)^[ \\t]*class_name[ \\t]+([A-Za-z0-9_]+)')
	# Matches public class declarations in C#
	_re_cs_class_def = RegEx.create_from_string('(?m)public[ \\t]+(?:partial[ \\t]+)?class[ \\t]+([A-Za-z0-9_]+)')
	# Matches @tool in GDScript or [Tool] in C#
	_re_tool_script = RegEx.create_from_string('(?m)^[ \\t]*(?:@?tool\\b|\\[(?:Godot\\.)?Tool\\])')

## Builds a fast in-memory index of all class_name declarations across the project
func build_class_index(all_nodes: Dictionary) -> void:
	_class_name_to_path.clear()
	_class_name_regexes.clear()

	for p in all_nodes.keys():
		var ext: String = p.get_extension().to_lower()
		if ext == "gd" or ext == "cs":
			if not FileAccess.file_exists(p):
				continue
			var fa: FileAccess = FileAccess.open(p, FileAccess.READ)
			if not fa:
				continue
			var content: String = fa.get_as_text()
			fa.close()

			var target_node: AssetNode = all_nodes.get(p)
			if target_node and _re_tool_script.search(content):
				target_node.is_tool_script = true

			var cname: String = ""
			if ext == "gd":
				var m = _re_class_def.search(content)
				if m:
					cname = m.get_string(1)
			elif ext == "cs":
				var m = _re_cs_class_def.search(content)
				if m:
					cname = m.get_string(1)

			if not cname.is_empty():
				_class_name_to_path[cname] = p
				_class_name_regexes[cname] = RegEx.create_from_string('\\b' + cname + '\\b')

	# Also index Autoload singleton names (e.g. GameManager -> res://.../game_manager.gd)
	for prop in ProjectSettings.get_property_list():
		var prop_name: String = prop["name"]
		if prop_name.begins_with("autoload/"):
			var singleton_name: String = prop_name.trim_prefix("autoload/")
			var raw_path: String = str(ProjectSettings.get_setting(prop_name, ""))
			if raw_path.begins_with("*"):
				raw_path = raw_path.substr(1)
			if all_nodes.has(raw_path) and not singleton_name.is_empty():
				_class_name_to_path[singleton_name] = raw_path
				_class_name_regexes[singleton_name] = RegEx.create_from_string('\\b' + singleton_name + '\\b')

	if FileAccess.file_exists("res://project.godot"):
		var cf_al: ConfigFile = ConfigFile.new()
		if cf_al.load("res://project.godot") == OK and cf_al.has_section("autoload"):
			for s_name in cf_al.get_section_keys("autoload"):
				var raw_path: String = str(cf_al.get_value("autoload", s_name, ""))
				if raw_path.begins_with("*"):
					raw_path = raw_path.substr(1)
				if all_nodes.has(raw_path) and not s_name.is_empty():
					_class_name_to_path[s_name] = raw_path
					_class_name_regexes[s_name] = RegEx.create_from_string('\\b' + s_name + '\\b')

	_is_class_index_built = true

## Primary extraction method. Given a node dictionary (path -> AssetNode), populates dependencies.
func extract_dependencies_for_node(node: AssetNode, all_nodes: Dictionary) -> Array[String]:
	if not _is_class_index_built:
		build_class_index(all_nodes)

	var found_deps: Array[String] = []

	# Method A: Godot Native Engine API ResourceLoader.get_dependencies()
	var native_deps: PackedStringArray = ResourceLoader.get_dependencies(node.path)
	for dep_str in native_deps:
		var resolved: String = _resolve_dependency_string(dep_str)
		if not resolved.is_empty() and resolved != node.path and all_nodes.has(resolved):
			if not found_deps.has(resolved):
				found_deps.append(resolved)

	# Method B: Deep Text Parsing for scripts (.gd, .cs), scenes (.tscn), shaders, materials, and themes
	# This catches preload(), load(), string constants, variables, UIDs, class_name references, and dynamic code references.
	if TEXT_PARSEABLE_EXTENSIONS.has(node.extension):
		var text_deps: Array[String] = _extract_deps_via_text_parser(node.path)
		for dep_path in text_deps:
			if dep_path == node.path:
				continue
			if all_nodes.has(dep_path):
				if not found_deps.has(dep_path):
					found_deps.append(dep_path)
			elif dep_path.begins_with("res://"):
				# Dynamic directory reference or formatted string pattern (e.g. "res://Textures/Country Flags/Frame-%d.png" or "res://Textures/Country Flags/")
				var target_prefix: String = dep_path.trim_suffix("/")
				if target_prefix.contains("%"):
					target_prefix = target_prefix.get_base_dir()

				# Link all assets residing under this dynamic directory
				if not target_prefix.is_empty() and target_prefix != "res:":
					for existing_path in all_nodes.keys():
						if existing_path.begins_with(target_prefix + "/") and not found_deps.has(existing_path):
							found_deps.append(existing_path)

	return found_deps

func _resolve_dependency_string(dep_str: String) -> String:
	# Godot get_dependencies strings can be "uid://..." or "res://...::sub_resource" or "res://..."
	if dep_str.begins_with("uid://"):
		if ResourceUID.has_method("text_to_id") and ResourceUID.has_method("get_id_path"):
			var uid_val: int = ResourceUID.text_to_id(dep_str)
			if uid_val != ResourceUID.INVALID_ID and ResourceUID.has_id(uid_val):
				return ResourceUID.get_id_path(uid_val)
		return ""

	# Strip sub-resource identifiers like "res://scene.tscn::1"
	var clean_path: String = dep_str
	var sub_pos: int = clean_path.find("::")
	if sub_pos != -1:
		clean_path = clean_path.substr(0, sub_pos)

	return clean_path

func _extract_deps_via_text_parser(file_path: String) -> Array[String]:
	var deps: Array[String] = []
	if not FileAccess.file_exists(file_path):
		return deps

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return deps

	var text: String = file.get_as_text()
	file.close()

	# 1. Match all quoted "res://..." strings (covers load(), preload(), const paths, var paths, ext_resources)
	for match_res in _re_res_string.search_all(text):
		var p: String = match_res.get_string(1)
		# Strip any sub-resource reference
		var sub_idx: int = p.find("::")
		if sub_idx != -1:
			p = p.substr(0, sub_idx)
		if not deps.has(p):
			deps.append(p)

	# 2. Match all quoted and unquoted "uid://..." strings and resolve them to real paths
	for match_res in _re_uid_string.search_all(text):
		var uid_str: String = match_res.get_string(1)
		var resolved: String = _resolve_dependency_string(uid_str)
		if not resolved.is_empty() and not deps.has(resolved):
			deps.append(resolved)

	# 3. Match global class_name identifiers used in the script, scene, or resource
	for cname in _class_name_to_path.keys():
		var target_class_path: String = _class_name_to_path[cname]
		if target_class_path == file_path:
			continue # Do not add self-reference

		var regex: RegEx = _class_name_regexes.get(cname)
		if regex and regex.search(text):
			if not deps.has(target_class_path):
				deps.append(target_class_path)

	return deps
