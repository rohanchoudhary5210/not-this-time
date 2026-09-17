@tool
class_name AssetDependencyService
extends RefCounted

## Central Facade Service coordinating ProjectScanner, DependencyExtractor, DependencyGraph, and AssetAnalyzer.

signal scan_started
signal scan_status_changed(status_text: String)
signal scan_progress(current: int, total: int)
signal scan_completed(graph: DependencyGraph, health_summary: Dictionary)

const ProjectScannerScript = preload("res://addons/asset_dependency_visualizer/core/project_scanner.gd")
const DependencyExtractorScript = preload("res://addons/asset_dependency_visualizer/core/dependency_extractor.gd")
const DependencyGraphScript = preload("res://addons/asset_dependency_visualizer/core/dependency_graph.gd")
const AssetAnalyzerScript = preload("res://addons/asset_dependency_visualizer/core/asset_analyzer.gd")
const ReportGeneratorScript = preload("res://addons/asset_dependency_visualizer/core/report_generator.gd")

var scanner: RefCounted
var extractor: RefCounted
var graph: RefCounted
var analyzer: RefCounted

var _cached_timestamps: Dictionary = {} # path -> modified_time
var _cached_hashes: Dictionary = {} # path -> sha256_hash
var _last_health_summary: Dictionary = {}

func _init() -> void:
	scanner = ProjectScannerScript.new()
	extractor = DependencyExtractorScript.new()
	graph = DependencyGraphScript.new()
	analyzer = AssetAnalyzerScript.new()

## Perform a full project scan
func run_full_scan(root_path: String = "res://") -> void:
	scan_started.emit()
	scan_status_changed.emit("Discovering project files...")

	# Yield immediately if main loop exists to let the UI update and show the loading overlay
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame

	# 1. File Discovery & AssetNode creation
	var raw_nodes: Dictionary = scanner.scan_project(root_path)

	graph.clear()

	var total_files: int = raw_nodes.size()
	var current_idx: int = 0

	# Add nodes to graph
	for path in raw_nodes.keys():
		var node: AssetNode = raw_nodes[path]
		graph.add_node(node)
		
		# Restore cached hash if modified time hasn't changed
		var last_time: int = _cached_timestamps.get(path, -1)
		if last_time == node.modified_time and _cached_hashes.has(path):
			node.sha256_hash = _cached_hashes[path]
			
		_cached_timestamps[path] = node.modified_time

	var last_yield: int = Time.get_ticks_msec()

	# 2. Extract dependencies for each node and create edges
	scan_status_changed.emit("Indexing class names & extracting dependencies...")
	extractor.build_class_index(raw_nodes)
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame

	for path in raw_nodes.keys():
		current_idx += 1
		scan_progress.emit(current_idx, total_files)

		var node: AssetNode = raw_nodes[path]
		var dep_paths: Array[String] = extractor.extract_dependencies_for_node(node, raw_nodes)

		for dep in dep_paths:
			graph.add_edge(node.path, dep)

		if Time.get_ticks_msec() - last_yield > 16:
			if Engine.get_main_loop():
				await Engine.get_main_loop().process_frame
			last_yield = Time.get_ticks_msec()

	# 3. Analyze graph and compile health report
	_last_health_summary = await analyzer.generate_health_summary(graph, func(status): scan_status_changed.emit(status))

	# Update cached hashes from nodes
	for path in graph.nodes.keys():
		var node: AssetNode = graph.nodes[path]
		if not node.sha256_hash.is_empty():
			_cached_hashes[path] = node.sha256_hash

	scan_completed.emit(graph, _last_health_summary)

## Perform an incremental scan (scans only dirty/modified assets)
func run_incremental_scan(root_path: String = "res://") -> void:
	scan_started.emit()
	scan_status_changed.emit("Discovering project files...")

	# Yield immediately if main loop exists to let the UI update and show the loading overlay
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame

	var raw_nodes: Dictionary = scanner.scan_project(root_path)
	var dirty_paths: Array[String] = []

	# Check for new or modified files
	for path in raw_nodes.keys():
		var node: AssetNode = raw_nodes[path]
		var last_time: int = _cached_timestamps.get(path, -1)

		if last_time != node.modified_time or not graph.has_node(path):
			dirty_paths.append(path)
			_cached_timestamps[path] = node.modified_time
			graph.add_node(node)

	var total_dirty: int = dirty_paths.size()
	var current_idx: int = 0
	var last_yield: int = Time.get_ticks_msec()

	# Re-extract dependencies only for dirty nodes
	scan_status_changed.emit("Indexing class names & extracting updated dependencies...")
	extractor.build_class_index(raw_nodes)
	for dirty in dirty_paths:
		current_idx += 1
		scan_progress.emit(current_idx, total_dirty)

		var node: AssetNode = graph.get_node(dirty)
		if node:
			# Cleanly remove old outgoing edges and reverse dependents
			graph.remove_outgoing_edges(dirty)
			var new_deps: Array[String] = extractor.extract_dependencies_for_node(node, raw_nodes)
			for dep in new_deps:
				graph.add_edge(node.path, dep)

		if Time.get_ticks_msec() - last_yield > 16:
			if Engine.get_main_loop():
				await Engine.get_main_loop().process_frame
			last_yield = Time.get_ticks_msec()

	_last_health_summary = await analyzer.generate_health_summary(graph, func(status): scan_status_changed.emit(status))

	# Update cached hashes from nodes
	for path in graph.nodes.keys():
		var node: AssetNode = graph.nodes[path]
		if not node.sha256_hash.is_empty():
			_cached_hashes[path] = node.sha256_hash

	scan_completed.emit(graph, _last_health_summary)

func get_graph() -> DependencyGraph:
	return graph

func get_last_health_summary() -> Dictionary:
	return _last_health_summary

func export_report_json() -> String:
	return ReportGeneratorScript.export_to_json(graph, _last_health_summary)

func export_report_csv() -> String:
	return ReportGeneratorScript.export_to_csv(graph)

func export_report_markdown() -> String:
	return ReportGeneratorScript.export_to_markdown(graph, _last_health_summary)

func export_report_mermaid() -> String:
	return ReportGeneratorScript.export_to_mermaid(graph)

func export_report_mermaid_uml() -> String:
	return ReportGeneratorScript.export_to_mermaid_uml(graph)

func export_subgraph_mermaid(paths: Array) -> String:
	return ReportGeneratorScript.export_subgraph_to_mermaid(graph, paths)

func export_subgraph_mermaid_uml(paths: Array) -> String:
	return ReportGeneratorScript.export_subgraph_to_mermaid_uml(graph, paths)

func export_report_dot() -> String:
	return ReportGeneratorScript.export_to_dot(graph)

func set_unused_excluded_folders(folders: Array) -> void:
	if analyzer:
		analyzer.custom_excluded_folders = folders

func add_unused_excluded_folder(folder: String) -> void:
	if analyzer and not analyzer.custom_excluded_folders.has(folder):
		analyzer.custom_excluded_folders.append(folder)

func get_unused_excluded_folders() -> Array[String]:
	if analyzer:
		return analyzer.custom_excluded_folders
	return []

