@tool
class_name AssetNode
extends RefCounted

## Pure data model representing a single project asset file and its graph state.

enum Category {
	SCENE,
	SCRIPT,
	TEXTURE,
	AUDIO,
	MATERIAL,
	SHADER,
	RESOURCE,
	MODEL_3D,
	FONT,
	ANIMATION,
	OTHER
}

var path: String = ""
var uid: String = ""
var type: Category = Category.OTHER
var extension: String = ""
var size_bytes: int = 0
var modified_time: int = 0
var sha256_hash: String = ""

# Adjacency representations (stores paths of direct connections)
var dependencies: Array[String] = []
var dependents: Array[String] = []

# Special asset flags (for heuristics and classification)
var is_main_scene: bool = false
var is_autoload: bool = false
var is_exported: bool = false
var is_tool_script: bool = false

func _init(p_path: String = "") -> void:
	path = p_path
	if not p_path.is_empty():
		extension = p_path.get_extension().to_lower()
		type = classify_extension(extension)

static func classify_extension(ext: String) -> Category:
	match ext:
		"tscn", "scn":
			return Category.SCENE
		"gd", "cs":
			return Category.SCRIPT
		"png", "jpg", "jpeg", "webp", "svg", "tga", "hdr", "exr":
			return Category.TEXTURE
		"wav", "ogg", "mp3", "flac":
			return Category.AUDIO
		"glb", "gltf", "obj", "blend", "fbx", "dae":
			return Category.MODEL_3D
		"ttf", "otf", "woff", "woff2", "fontdata":
			return Category.FONT
		"anim", "animation":
			return Category.ANIMATION
		"material", "tresmaterial":
			return Category.MATERIAL
		"shader", "gdshader":
			return Category.SHADER
		"tres", "res", "theme":
			return Category.RESOURCE
		_:
			return Category.OTHER

static func category_to_string(cat: Category) -> String:
	match cat:
		Category.SCENE: return "Scene"
		Category.SCRIPT: return "Script"
		Category.TEXTURE: return "Texture"
		Category.AUDIO: return "Audio"
		Category.RESOURCE: return "Resource"
		Category.MATERIAL: return "Material"
		Category.SHADER: return "Shader"
		Category.MODEL_3D: return "3D Model"
		Category.FONT: return "Font"
		Category.ANIMATION: return "Animation"
		_: return "Other"

func add_dependency(target_path: String) -> void:
	if target_path != path and not dependencies.has(target_path):
		dependencies.append(target_path)

func add_dependent(source_path: String) -> void:
	if source_path != path and not dependents.has(source_path):
		dependents.append(source_path)

func remove_dependency(target_path: String) -> void:
	dependencies.erase(target_path)

func remove_dependent(source_path: String) -> void:
	dependents.erase(source_path)

func get_in_degree() -> int:
	return dependents.size()

func get_out_degree() -> int:
	return dependencies.size()

func is_orphan() -> bool:
	return dependents.is_empty() and not is_main_scene and not is_autoload and not is_exported and not is_tool_script

## True Dead / Orphan Asset: 0 incoming dependents AND 0 outgoing dependencies (Safe to delete)
func is_true_orphan() -> bool:
	return is_orphan() and dependencies.is_empty()

## Root Scene / Standalone Level: 0 incoming dependents BUT has internal child nodes/dependencies
func is_root_scene() -> bool:
	return is_orphan() and not dependencies.is_empty() and type == Category.SCENE

func to_dict() -> Dictionary:
	return {
		"path": path,
		"uid": uid,
		"type": category_to_string(type),
		"extension": extension,
		"size_bytes": size_bytes,
		"modified_time": modified_time,
		"sha256_hash": sha256_hash,
		"dependencies_count": dependencies.size(),
		"dependents_count": dependents.size(),
		"is_main_scene": is_main_scene,
		"is_autoload": is_autoload,
		"is_exported": is_exported,
		"is_tool_script": is_tool_script
	}
