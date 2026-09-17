@tool
class_name AssetAnalyzer
extends RefCounted

## Analyzes a DependencyGraph to produce health metrics, unused asset detection, duplicate content detection, and deletion impact assessments.

## Default folder substrings/prefixes excluded from Unused Assets detection
const DEFAULT_UNUSED_EXCLUDED_FOLDERS: Array[String] = [
	"addons",
	"android",
	"ios",
	"plugin_integration_pack",
	"plugins",
	"third_party",
	"vendor",
	"reports"
]

var custom_excluded_folders: Array = []

## Checks whether a file path falls within an excluded folder (addons, android, plugin_integration_pack, etc.)
func is_path_excluded_from_unused(file_path: String) -> bool:
	var lower_path: String = file_path.to_lower()

	# 1. Check ProjectSettings configured exclusions if set
	if ProjectSettings.has_setting("asset_dependency_visualizer/unused_assets/exclude_folders"):
		var settings_exclusions = ProjectSettings.get_setting("asset_dependency_visualizer/unused_assets/exclude_folders")
		var folder_list: Array = []
		if settings_exclusions is PackedStringArray or settings_exclusions is Array:
			folder_list = Array(settings_exclusions)
		elif settings_exclusions is String:
			folder_list = Array(settings_exclusions.split(","))

		for folder in folder_list:
			var f_clean: String = str(folder).strip_edges().to_lower().trim_prefix("res://").trim_prefix("/").trim_suffix("/")
			if not f_clean.is_empty() and (lower_path.contains("/" + f_clean + "/") or lower_path.begins_with("res://" + f_clean + "/") or lower_path == "res://" + f_clean):
				return true

	# 2. Check custom in-memory excluded folders
	for folder in custom_excluded_folders:
		var f_clean: String = folder.strip_edges().to_lower().trim_prefix("res://").trim_prefix("/").trim_suffix("/")
		if not f_clean.is_empty() and (lower_path.contains("/" + f_clean + "/") or lower_path.begins_with("res://" + f_clean + "/") or lower_path == "res://" + f_clean):
			return true

	# 3. Check default built-in exclusions
	for folder in DEFAULT_UNUSED_EXCLUDED_FOLDERS:
		var f_clean: String = folder.to_lower()
		if lower_path.contains("/" + f_clean + "/") or lower_path.begins_with("res://" + f_clean + "/") or lower_path == "res://" + f_clean:
			return true

	return false

## Finds all unreferenced assets (0 in-degree) that are not project entry points and not in excluded folders
func find_potentially_unused_assets(graph: DependencyGraph) -> Array[AssetNode]:
	var unused: Array[AssetNode] = []
	for node_path in graph.nodes.keys():
		var node: AssetNode = graph.nodes[node_path]
		if node.is_orphan() and not is_path_excluded_from_unused(node.path):
			unused.append(node)
	return unused

## Finds true dead / orphan assets: 0 incoming references AND 0 outgoing dependencies (Safe to delete)
func find_true_orphans(graph: DependencyGraph) -> Array[AssetNode]:
	var orphans: Array[AssetNode] = []
	for node_path in graph.nodes.keys():
		var node: AssetNode = graph.nodes[node_path]
		if node.is_true_orphan() and not is_path_excluded_from_unused(node.path):
			orphans.append(node)
	return orphans

## Finds standalone root scenes / levels: 0 incoming references BUT has active dependencies (Entry Points)
func find_root_scenes(graph: DependencyGraph) -> Array[AssetNode]:
	var roots: Array[AssetNode] = []
	for node_path in graph.nodes.keys():
		var node: AssetNode = graph.nodes[node_path]
		if node.is_root_scene() and not is_path_excluded_from_unused(node.path):
			roots.append(node)
	return roots

## Computes SHA-256 hashes for all files in graph and returns groups of duplicate paths
func find_duplicate_content_assets(graph: DependencyGraph) -> Dictionary:
	# Dictionary of sha256 -> Array[String] (paths)
	var hash_map: Dictionary = {}
	var last_yield: int = Time.get_ticks_msec()

	for node_path in graph.nodes.keys():
		var node: AssetNode = graph.nodes[node_path]
		if node.size_bytes > 0:
			if node.sha256_hash.is_empty() and FileAccess.file_exists(node_path):
				node.sha256_hash = FileAccess.get_sha256(node_path)

			if not node.sha256_hash.is_empty():
				if not hash_map.has(node.sha256_hash):
					hash_map[node.sha256_hash] = []
				hash_map[node.sha256_hash].append(node_path)

		if Time.get_ticks_msec() - last_yield > 16:
			await Engine.get_main_loop().process_frame
			last_yield = Time.get_ticks_msec()

	# Filter out unique files (only return hashes with > 1 file)
	var duplicates: Dictionary = {}
	for hash_val in hash_map.keys():
		var paths: Array = hash_map[hash_val]
		if paths.size() > 1:
			duplicates[hash_val] = paths

	return duplicates

## Analyzes the impact of deleting a specific asset (returns direct and indirect broken dependents)
func analyze_deletion_impact(graph: DependencyGraph, target_path: String) -> Dictionary:
	var node: AssetNode = graph.get_node(target_path)
	if not node:
		return {}

	var direct_dependents: Array[String] = node.dependents.duplicate()
	var transitive_dependents: Array[String] = graph.get_transitive_dependents(target_path)

	return {
		"target_path": target_path,
		"direct_broken_count": direct_dependents.size(),
		"direct_broken_paths": direct_dependents,
		"total_broken_count": transitive_dependents.size(),
		"total_broken_paths": transitive_dependents,
		"is_critical_hub": transitive_dependents.size() >= 5
	}

## Generates full project health metrics summary
func generate_health_summary(graph: DependencyGraph, status_callback: Callable = Callable()) -> Dictionary:
	var total_assets: int = graph.get_node_count()
	var category_counts: Dictionary = {
		"Scene": 0,
		"Script": 0,
		"Texture": 0,
		"Audio": 0,
		"3D Model": 0,
		"Font": 0,
		"Animation": 0,
		"Material": 0,
		"Shader": 0,
		"Resource": 0,
		"Other": 0
	}

	var all_nodes: Array = graph.nodes.values()

	for n in all_nodes:
		var node: AssetNode = n
		var cat_str: String = AssetNode.category_to_string(node.type)
		category_counts[cat_str] = category_counts.get(cat_str, 0) + 1

	var unused: Array[AssetNode] = find_potentially_unused_assets(graph)
	var true_orphans: Array[AssetNode] = find_true_orphans(graph)
	var root_scenes: Array[AssetNode] = find_root_scenes(graph)

	if status_callback.is_valid():
		status_callback.call("Calculating duplicate content hashes...")
	var duplicates: Dictionary = await find_duplicate_content_assets(graph)

	if status_callback.is_valid():
		status_callback.call("Detecting circular dependency loops...")
	var cycles: Array[Array] = graph.detect_circular_dependencies()

	# Sort assets by size to find top 10 largest
	var sorted_by_size: Array = all_nodes.duplicate()
	sorted_by_size.sort_custom(func(a: AssetNode, b: AssetNode): return a.size_bytes > b.size_bytes)
	var heavy_assets: Array[Dictionary] = []
	var limit: int = mini(10, sorted_by_size.size())
	for i in range(limit):
		var heavy_node: AssetNode = sorted_by_size[i]
		heavy_assets.append({
			"path": heavy_node.path,
			"size_bytes": heavy_node.size_bytes,
			"type": AssetNode.category_to_string(heavy_node.type)
		})

	if status_callback.is_valid():
		status_callback.call("Calculating heaviest dependency chains...")
	var heaviest_chain_info: Dictionary = await graph.find_heaviest_dependency_chain()

	return {
		"total_assets": total_assets,
		"total_edges": graph.get_edge_count(),
		"category_counts": category_counts,
		"potentially_unused_count": unused.size(),
		"potentially_unused_paths": unused.map(func(an: AssetNode): return an.path),
		"true_orphan_count": true_orphans.size(),
		"true_orphan_paths": true_orphans.map(func(an: AssetNode): return an.path),
		"root_scene_count": root_scenes.size(),
		"root_scene_paths": root_scenes.map(func(an: AssetNode): return an.path),
		"duplicate_group_count": duplicates.size(),
		"duplicate_groups": duplicates,
		"circular_dependencies_count": cycles.size(),
		"circular_dependencies": cycles,
		"heavy_assets": heavy_assets,
		"heaviest_chain": heaviest_chain_info
	}
