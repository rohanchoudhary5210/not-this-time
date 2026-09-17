@tool
class_name HealthReportView
extends ScrollContainer

## Project Health Dashboard displaying asset counts, unused assets, duplicates, circular dependency alerts, and export options.

signal inspect_asset_requested(path: String)
signal inspect_cycle_requested(cycle: Array)
signal export_graph_png_requested()
signal notification_requested(title: String, message: String, type: String, action_label: String, action_callable: Callable, sec_label: String, sec_callable: Callable)

var _service: AssetDependencyService
var _container: VBoxContainer

var _metrics_label: Label
var _categories_label: Label
var _heaviest_chain_label: Label
var _unused_tree: Tree
var _duplicates_tree: Tree
var _circular_tree: Tree
var _unused_filter_input: LineEdit
var _last_summary: Dictionary = {}

func set_service(service: AssetDependencyService) -> void:
	_service = service

func _enter_tree() -> void:
	_setup_ui()

func _setup_ui() -> void:
	if _container and is_instance_valid(_container):
		return

	for child in get_children():
		child.queue_free()

	_container = VBoxContainer.new()
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_container)

	# Export Action Buttons Bar
	var export_bar: HBoxContainer = HBoxContainer.new()
	_container.add_child(export_bar)

	var btn_json: Button = Button.new()
	btn_json.text = "Export JSON"
	btn_json.pressed.connect(_on_export_json)
	export_bar.add_child(btn_json)

	var btn_csv: Button = Button.new()
	btn_csv.text = "Export CSV"
	btn_csv.pressed.connect(_on_export_csv)
	export_bar.add_child(btn_csv)

	var btn_md: Button = Button.new()
	btn_md.text = "Export Markdown"
	btn_md.pressed.connect(_on_export_md)
	export_bar.add_child(btn_md)

	var btn_mmd: Button = Button.new()
	btn_mmd.text = "Export Mermaid (Flowchart)"
	btn_mmd.pressed.connect(_on_export_mermaid)
	export_bar.add_child(btn_mmd)

	var btn_uml: Button = Button.new()
	btn_uml.text = "Export Mermaid (UML)"
	btn_uml.pressed.connect(_on_export_mermaid_uml)
	export_bar.add_child(btn_uml)

	var btn_dot: Button = Button.new()
	btn_dot.text = "Export Graphviz (DOT)"
	btn_dot.pressed.connect(_on_export_dot)
	export_bar.add_child(btn_dot)

	var btn_png: Button = Button.new()
	btn_png.text = "📷 Export Graph Image (PNG)"
	btn_png.pressed.connect(_on_export_png)
	export_bar.add_child(btn_png)

	# Dashboard Metrics Summary
	var panel: PanelContainer = PanelContainer.new()
	var p_vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(p_vbox)
	_container.add_child(panel)

	_metrics_label = Label.new()
	_metrics_label.text = "Project Health Overview (Run scan to update)"
	p_vbox.add_child(_metrics_label)

	_categories_label = Label.new()
	_categories_label.text = "Asset Categories: -"
	p_vbox.add_child(_categories_label)

	_heaviest_chain_label = Label.new()
	_heaviest_chain_label.text = "Heaviest Chain: -"
	_heaviest_chain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_vbox.add_child(_heaviest_chain_label)

	# Section 1: Circular Dependencies
	var circ_header: Label = Label.new()
	circ_header.text = "⚠️ Circular Dependency Loops:"
	_container.add_child(circ_header)

	_circular_tree = Tree.new()
	_circular_tree.custom_minimum_size = Vector2(0, 100)
	_circular_tree.hide_root = true
	_circular_tree.item_selected.connect(_on_tree_item_selected.bind(_circular_tree))
	_circular_tree.item_activated.connect(_on_tree_item_activated.bind(_circular_tree))
	_container.add_child(_circular_tree)

	var btn_export_circular: Button = Button.new()
	btn_export_circular.text = "📥 Download Circular Dependencies (Text)"
	btn_export_circular.pressed.connect(_on_export_circular_dependencies)
	_container.add_child(btn_export_circular)

	# Section 2: Potentially Unused Assets
	var unused_header: Label = Label.new()
	unused_header.text = "🔍 Potentially Unused Assets (Click to select in FileSystem, Double-click to open):"
	_container.add_child(unused_header)

	# Folder Omit / Exclude Filter Bar
	var filter_hbox: HBoxContainer = HBoxContainer.new()
	filter_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.add_child(filter_hbox)

	var filter_lbl: Label = Label.new()
	filter_lbl.text = "📁 Omit Folders:"
	filter_lbl.tooltip_text = "Comma-separated folder names to exclude from Unused Assets (e.g. 'plugin_integration_pack, android, addons, my_folder')"
	filter_hbox.add_child(filter_lbl)

	_unused_filter_input = LineEdit.new()
	_unused_filter_input.placeholder_text = "addons, android, plugin_integration_pack, third_party..."
	_unused_filter_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unused_filter_input.text_submitted.connect(_on_apply_custom_exclusion_filter)
	filter_hbox.add_child(_unused_filter_input)

	var filter_btn: Button = Button.new()
	filter_btn.text = "Apply Omit Filter"
	filter_btn.tooltip_text = "Apply folder exclusions to Potentially Unused Assets"
	filter_btn.pressed.connect(func(): _on_apply_custom_exclusion_filter(_unused_filter_input.text))
	filter_hbox.add_child(filter_btn)

	_unused_tree = Tree.new()
	_unused_tree.custom_minimum_size = Vector2(0, 140)
	_unused_tree.hide_root = true
	_unused_tree.item_selected.connect(_on_tree_item_selected.bind(_unused_tree))
	_unused_tree.item_activated.connect(_on_tree_item_activated.bind(_unused_tree))
	_container.add_child(_unused_tree)

	var btn_export_unused: Button = Button.new()
	btn_export_unused.text = "📥 Download Potentially Unused Assets (Text)"
	btn_export_unused.pressed.connect(_on_export_unused_assets)
	_container.add_child(btn_export_unused)

	# Section 3: Duplicate Assets
	var dup_header: Label = Label.new()
	dup_header.text = "👯 Duplicate Content Groups (Identical File Hashes):"
	_container.add_child(dup_header)

	_duplicates_tree = Tree.new()
	_duplicates_tree.custom_minimum_size = Vector2(0, 140)
	_duplicates_tree.hide_root = true
	_duplicates_tree.item_selected.connect(_on_tree_item_selected.bind(_duplicates_tree))
	_duplicates_tree.item_activated.connect(_on_tree_item_activated.bind(_duplicates_tree))
	_container.add_child(_duplicates_tree)

	var btn_export_duplicates: Button = Button.new()
	btn_export_duplicates.text = "📥 Download Duplicate Groups (Text)"
	btn_export_duplicates.pressed.connect(_on_export_duplicates)
	_container.add_child(btn_export_duplicates)

func update_report(summary: Dictionary) -> void:
	if summary.is_empty():
		return
	if not _container or not is_instance_valid(_container):
		_setup_ui()
	_last_summary = summary

	_metrics_label.text = "Total Assets: %d | Total Edges: %d | Potentially Unused: %d | Duplicates: %d | Circular Loops: %d" % [
		summary.get("total_assets", 0),
		summary.get("total_edges", 0),
		summary.get("potentially_unused_count", 0),
		summary.get("duplicate_group_count", 0),
		summary.get("circular_dependencies_count", 0)
	]

	var cats: Dictionary = summary.get("category_counts", {})
	var cat_str_parts: Array[String] = []
	for k in cats.keys():
		cat_str_parts.append("%s: %d" % [k, cats[k]])
	_categories_label.text = "Categories: " + " | ".join(cat_str_parts)

	var h_chain: Dictionary = summary.get("heaviest_chain", {})
	if not h_chain.is_empty():
		var root_p: String = h_chain.get("root_path", "")
		var tot_kb: float = float(h_chain.get("total_transitive_bytes", 0)) / 1024.0
		_heaviest_chain_label.text = "🏋️ Heaviest Chain: %s (Total Transitive Weight: %.2f KB)" % [root_p, tot_kb]

	# Populate Circular Dependencies
	_circular_tree.clear()
	var root_circ: TreeItem = _circular_tree.create_item()
	var cycles: Array = summary.get("circular_dependencies", [])
	for cycle in cycles:
		var item: TreeItem = _circular_tree.create_item(root_circ)
		var names: Array = []
		for p in cycle:
			names.append(str(p).get_file())
		var loop_str: String = " ➔ ".join(names)
		if cycle.size() > 1:
			loop_str += " ➔ " + str(names[0])
		item.set_text(0, "⚠️ " + loop_str + "  (%d assets)" % cycle.size())
		item.set_metadata(0, cycle)
		item.set_tooltip_text(0, "Click to view this loop in the Visual Graph | Double-click to open in Editor\nFull Loop: " + " ➔ ".join(cycle))

	# Populate Unused Assets with Smart Categorization
	_unused_tree.clear()
	var root_unused: TreeItem = _unused_tree.create_item()

	var true_orphan_paths: Array = summary.get("true_orphan_paths", [])
	var root_scene_paths: Array = summary.get("root_scene_paths", [])

	# 1. True Dead / Orphan Assets (0 in, 0 out)
	if not true_orphan_paths.is_empty():
		var orphan_group: TreeItem = _unused_tree.create_item(root_unused)
		orphan_group.set_text(0, "🔴 Dead / Orphan Assets (%d) — [Safe to Delete: 0 In, 0 Out]" % true_orphan_paths.size())
		orphan_group.set_tooltip_text(0, "These assets have 0 incoming references and 0 outgoing dependencies. They are completely unreferenced.")
		for u_path in true_orphan_paths:
			var item: TreeItem = _unused_tree.create_item(orphan_group)
			item.set_text(0, "  🗑️ " + str(u_path))
			item.set_metadata(0, u_path)
			item.set_tooltip_text(0, "Click to highlight in FileSystem dock | Double-click to open in Editor")

	# 2. Standalone Root Scenes / Levels (0 in, >0 out)
	if not root_scene_paths.is_empty():
		var root_group: TreeItem = _unused_tree.create_item(root_unused)
		root_group.set_text(0, "🟡 Root Scenes / Levels (%d) — [Entry Points: 0 In, Has Internal Nodes]" % root_scene_paths.size())
		root_group.set_tooltip_text(0, "These scenes have no incoming references from other scenes, but contain internal nodes/scripts. They are likely playable levels, menus, or code-switched scenes.")
		for r_path in root_scene_paths:
			var item: TreeItem = _unused_tree.create_item(root_group)
			item.set_text(0, "  🎬 " + str(r_path))
			item.set_metadata(0, r_path)
			item.set_tooltip_text(0, "Click to view hierarchy in Visual Graph | Double-click to open Scene")

	# Fallback if both empty or legacy summary
	if true_orphan_paths.is_empty() and root_scene_paths.is_empty():
		var unused_paths: Array = summary.get("potentially_unused_paths", [])
		for u_path in unused_paths:
			var item: TreeItem = _unused_tree.create_item(root_unused)
			item.set_text(0, "📄 " + str(u_path))
			item.set_metadata(0, u_path)
			item.set_tooltip_text(0, "Click to highlight in FileSystem dock | Double-click to open in Editor")

	# Populate Duplicates
	_duplicates_tree.clear()
	var root_dup: TreeItem = _duplicates_tree.create_item()
	var dup_groups: Dictionary = summary.get("duplicate_groups", {})
	for hash_val in dup_groups.keys():
		var group_item: TreeItem = _duplicates_tree.create_item(root_dup)
		group_item.set_text(0, "Hash: " + hash_val.substr(0, 12) + "...")
		var paths: Array = dup_groups[hash_val]
		for p in paths:
			var sub_item: TreeItem = _duplicates_tree.create_item(group_item)
			sub_item.set_text(0, "  📄 " + str(p))
			sub_item.set_metadata(0, p)
			sub_item.set_tooltip_text(0, "Click to highlight in FileSystem dock | Double-click to open in Editor")

func _on_tree_item_selected(tree: Tree) -> void:
	var selected: TreeItem = tree.get_selected()
	if selected and selected.get_metadata(0) != null:
		var meta = selected.get_metadata(0)
		if meta is Array:
			inspect_cycle_requested.emit(meta)
		elif meta is String and not (meta as String).is_empty():
			var path: String = meta as String
			inspect_asset_requested.emit(path)
			if Engine.is_editor_hint():
				EditorInterface.select_file(path)

func _on_tree_item_activated(tree: Tree) -> void:
	var selected: TreeItem = tree.get_selected()
	if selected and selected.get_metadata(0) != null:
		var meta = selected.get_metadata(0)
		if meta is Array:
			inspect_cycle_requested.emit(meta)
			if meta.size() > 0:
				_open_file_in_editor(str(meta[0]))
		elif meta is String and not (meta as String).is_empty():
			var path: String = meta as String
			inspect_asset_requested.emit(path)
			_open_file_in_editor(path)

func _open_file_in_editor(path: String) -> void:
	if not Engine.is_editor_hint() or path.is_empty():
		return
	var ext: String = path.get_extension().to_lower()
	match ext:
		"tscn", "scn":
			EditorInterface.open_scene_from_path(path)
		"gd":
			var script_res = load(path)
			if script_res:
				EditorInterface.edit_script(script_res)
		"tres", "res", "material", "theme":
			var res = load(path)
			if res:
				EditorInterface.edit_resource(res)
		_:
			EditorInterface.select_file(path)

func _notify(title: String, message: String, type: String = "info", action_label: String = "", action_callable: Callable = Callable(), sec_label: String = "", sec_callable: Callable = Callable()) -> void:
	notification_requested.emit(title, message, type, action_label, action_callable, sec_label, sec_callable)

func _on_export_json() -> void:
	if not _service or not _service.get_graph() or _service.get_graph().get_node_count() == 0:
		_notify("Scan Required", "No dependency data to export. Run a scan first.", "warning", "🔄 Run Full Scan Now", func(): if _service: _service.run_full_scan())
		return
	var data: String = _service.export_report_json()
	_save_text_file("res://reports/asset_dependency_report.json", data, "JSON Dependency Report")

func _on_export_csv() -> void:
	if not _service or not _service.get_graph() or _service.get_graph().get_node_count() == 0:
		_notify("Scan Required", "No dependency data to export. Run a scan first.", "warning", "🔄 Run Full Scan Now", func(): if _service: _service.run_full_scan())
		return
	var data: String = _service.export_report_csv()
	_save_text_file("res://reports/asset_dependency_report.csv", data, "CSV Dependency Report")

func _on_export_md() -> void:
	if not _service or not _service.get_graph() or _service.get_graph().get_node_count() == 0:
		_notify("Scan Required", "No dependency data to export. Run a scan first.", "warning", "🔄 Run Full Scan Now", func(): if _service: _service.run_full_scan())
		return
	var data: String = _service.export_report_markdown()
	_save_text_file("res://reports/asset_dependency_report.md", data, "Markdown Project Report")

func _on_export_mermaid() -> void:
	if not _service or not _service.get_graph() or _service.get_graph().get_node_count() == 0:
		_notify("Scan Required", "No dependency data to export. Run a scan first.", "warning", "🔄 Run Full Scan Now", func(): if _service: _service.run_full_scan())
		return
	var data: String = _service.export_report_mermaid()
	_save_text_file("res://reports/asset_graph.mmd", data, "Mermaid Flowchart Diagram")

func _on_export_mermaid_uml() -> void:
	if not _service or not _service.get_graph() or _service.get_graph().get_node_count() == 0:
		_notify("Scan Required", "No dependency data to export. Run a scan first.", "warning", "🔄 Run Full Scan Now", func(): if _service: _service.run_full_scan())
		return
	var data: String = _service.export_report_mermaid_uml()
	_save_text_file("res://reports/asset_graph_uml.mmd", data, "Mermaid UML Class Diagram")

func _on_export_dot() -> void:
	if not _service or not _service.get_graph() or _service.get_graph().get_node_count() == 0:
		_notify("Scan Required", "No dependency data to export. Run a scan first.", "warning", "🔄 Run Full Scan Now", func(): if _service: _service.run_full_scan())
		return
	var data: String = _service.export_report_dot()
	_save_text_file("res://reports/asset_graph.dot", data, "Graphviz DOT Graph")

func _on_apply_custom_exclusion_filter(input_text: String) -> void:
	if not _service or not _service.get_graph():
		_notify("Scan Required", "Please run a scan first before applying filters.", "warning", "🔄 Run Full Scan Now", func(): if _service: _service.run_full_scan())
		return

	var raw_parts: PackedStringArray = input_text.split(",")
	var folders: Array[String] = []
	for p in raw_parts:
		var clean: String = p.strip_edges()
		if not clean.is_empty():
			folders.append(clean)

	_service.set_unused_excluded_folders(folders)

	if _service.analyzer and _service.get_graph():
		var summary: Dictionary = await _service.analyzer.generate_health_summary(_service.get_graph())
		update_report(summary)
		var display_str: String = ", ".join(folders) if not folders.is_empty() else "Defaults (addons, android, plugin_integration_pack, etc.)"
		_notify("Filter Applied", "Omitted folders from unused assets: %s" % display_str, "info")

func _on_export_png() -> void:
	if not _service or not _service.get_graph() or _service.get_graph().get_node_count() == 0:
		_notify("Scan Required", "No dependency data to export. Run a scan first.", "warning", "🔄 Run Full Scan Now", func(): if _service: _service.run_full_scan())
		return
	export_graph_png_requested.emit()

func _save_text_file(target_path: String, content: String, report_name: String = "Report") -> void:
	var dir_path: String = target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		_notify(
			"Report Saved Successfully",
			"Saved %s to:\n%s" % [report_name, target_path],
			"success",
			"🔍 Show in FileSystem",
			func(): if Engine.is_editor_hint(): EditorInterface.select_file(target_path)
		)
	else:
		_notify("Failed to Save File", "Could not write file to:\n%s" % target_path, "error")

func _on_export_circular_dependencies() -> void:
	if _last_summary.is_empty():
		_notify(
			"No Circular Dependency Data",
			"No circular dependency data to export. Run a scan first.",
			"warning",
			"🔄 Run Full Scan Now",
			func(): if _service: _service.run_full_scan()
		)
		return
	var cycles: Array = _last_summary.get("circular_dependencies", [])
	var lines: Array[String] = []
	lines.append("=== Circular Dependency Loops ===")
	lines.append("Total Loops: %d" % cycles.size())
	lines.append("")
	for i in range(cycles.size()):
		var cycle = cycles[i]
		lines.append("Loop %d:" % (i + 1))
		lines.append("  " + " -> ".join(cycle))
		lines.append("")
	var content: String = "\n".join(lines)
	_save_text_file("res://reports/circular_dependencies.txt", content, "Circular Dependencies Report")

func _on_export_unused_assets() -> void:
	if _last_summary.is_empty():
		_notify(
			"No Unused Assets Data",
			"No unused assets data to export. Run a scan first.",
			"warning",
			"🔄 Run Full Scan Now",
			func(): if _service: _service.run_full_scan()
		)
		return
	var true_orphans: Array = _last_summary.get("true_orphan_paths", [])
	var root_scenes: Array = _last_summary.get("root_scene_paths", [])
	var lines: Array[String] = []
	lines.append("=== Potentially Unused Assets & Entry Points ===")
	lines.append("Total Assets with 0 in-degree: %d" % (true_orphans.size() + root_scenes.size()))
	lines.append("")
	lines.append("--- 1. Dead / Orphan Assets (0 In, 0 Out - Safe to delete) [%d] ---" % true_orphans.size())
	for path in true_orphans:
		lines.append("  [DEAD] " + str(path))
	lines.append("")
	lines.append("--- 2. Standalone Root Scenes / Levels (0 In, Has Internal Nodes) [%d] ---" % root_scenes.size())
	for path in root_scenes:
		lines.append("  [ROOT_SCENE] " + str(path))
	var content: String = "\n".join(lines)
	_save_text_file("res://reports/unused_assets.txt", content, "Potentially Unused Assets List")

func _on_export_duplicates() -> void:
	if _last_summary.is_empty():
		_notify(
			"No Duplicate Group Data",
			"No duplicate content group data to export. Run a scan first.",
			"warning",
			"🔄 Run Full Scan Now",
			func(): if _service: _service.run_full_scan()
		)
		return
	var dup_groups: Dictionary = _last_summary.get("duplicate_groups", {})
	var lines: Array[String] = []
	lines.append("=== Duplicate Content Groups ===")
	lines.append("Total Duplicate Groups: %d" % dup_groups.size())
	lines.append("")
	for hash_val in dup_groups.keys():
		lines.append("Hash: %s" % hash_val)
		var paths: Array = dup_groups[hash_val]
		for p in paths:
			lines.append("  - %s" % str(p))
		lines.append("")
	var content: String = "\n".join(lines)
	_save_text_file("res://reports/duplicate_groups.txt", content, "Duplicate Content Groups List")
