@tool
class_name InspectorPanel
extends ScrollContainer

## UI Inspector Panel detailing target asset dependencies, dependents, size, and deletion impact.

signal asset_selected(path: String)

var _service: AssetDependencyService
var _container: VBoxContainer
var _title_label: Label
var _type_label: Label
var _size_label: Label
var _uid_label: Label
var _deps_tree: Tree
var _dependents_tree: Tree
var _deletion_impact_label: Label

func set_service(service: AssetDependencyService) -> void:
	_service = service

func _enter_tree() -> void:
	_setup_ui()

func _setup_ui() -> void:
	for child in get_children():
		child.queue_free()

	_container = VBoxContainer.new()
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_container)

	# Header / Asset Info Box
	var info_box: PanelContainer = PanelContainer.new()
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_box.add_child(info_vbox)
	_container.add_child(info_box)

	_title_label = Label.new()
	_title_label.text = "Select an asset to view details"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(_title_label)

	_type_label = Label.new()
	_type_label.text = "Type: -"
	info_vbox.add_child(_type_label)

	_size_label = Label.new()
	_size_label.text = "Size: -"
	info_vbox.add_child(_size_label)

	_uid_label = Label.new()
	_uid_label.text = "UID: -"
	info_vbox.add_child(_uid_label)

	_deletion_impact_label = Label.new()
	_deletion_impact_label.text = "Deletion Impact: Select an asset"
	_deletion_impact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(_deletion_impact_label)

	# Action Buttons (Open in Editor & Navigate in FileSystem)
	var btn_hbox: HBoxContainer = HBoxContainer.new()
	info_vbox.add_child(btn_hbox)

	var btn_open: Button = Button.new()
	btn_open.text = "📂 Open in Editor"
	btn_open.pressed.connect(_on_open_in_editor)
	btn_hbox.add_child(btn_open)

	var btn_show_fs: Button = Button.new()
	btn_show_fs.text = "🔍 Show in FileSystem"
	btn_show_fs.pressed.connect(_on_show_in_filesystem)
	btn_hbox.add_child(btn_show_fs)

	# Section 1: Dependencies (What this asset depends on)
	var dep_header: Label = Label.new()
	dep_header.text = "Dependencies (This asset references):"
	_container.add_child(dep_header)

	_deps_tree = Tree.new()
	_deps_tree.custom_minimum_size = Vector2(0, 140)
	_deps_tree.hide_root = true
	_deps_tree.item_activated.connect(_on_dep_item_activated)
	_container.add_child(_deps_tree)

	# Section 2: Dependents (Which assets reference this asset)
	var ref_header: Label = Label.new()
	ref_header.text = "Referenced By (Assets depending on this):"
	_container.add_child(ref_header)

	_dependents_tree = Tree.new()
	_dependents_tree.custom_minimum_size = Vector2(0, 140)
	_dependents_tree.hide_root = true
	_dependents_tree.item_activated.connect(_on_dependent_item_activated)
	_container.add_child(_dependents_tree)

var _current_inspected_path: String = ""

func inspect_asset(path: String) -> void:
	_current_inspected_path = path
	if not _service or not _service.get_graph().has_node(path):
		_title_label.text = "Asset not found: " + path
		return

	var graph: DependencyGraph = _service.get_graph()
	var node: AssetNode = graph.get_node(path)

	_title_label.text = node.path.get_file() + "\n(" + node.path + ")"
	_type_label.text = "Type: " + AssetNode.category_to_string(node.type)
	_size_label.text = "Size: %.2f KB (Transitive: %.2f KB)" % [
		float(node.size_bytes) / 1024.0,
		float(graph.get_transitive_size_bytes(path)) / 1024.0
	]
	_uid_label.text = "UID: " + (node.uid if not node.uid.is_empty() else "N/A")

	# Deletion Impact Analysis
	var impact: Dictionary = _service.analyzer.analyze_deletion_impact(graph, path)
	var impact_text: String = "Deletion Impact: If deleted, %d assets will break (%d direct dependents)." % [
		impact.get("total_broken_count", 0),
		impact.get("direct_broken_count", 0)
	]
	if impact.get("is_critical_hub", false):
		impact_text += " [CRITICAL HUB]"
	_deletion_impact_label.text = impact_text

	# Populate Dependencies Tree
	_deps_tree.clear()
	var root_dep: TreeItem = _deps_tree.create_item()
	for dep_path in node.dependencies:
		var item: TreeItem = _deps_tree.create_item(root_dep)
		item.set_text(0, dep_path)
		item.set_metadata(0, dep_path)

	# Populate Dependents Tree
	_dependents_tree.clear()
	var root_ref: TreeItem = _dependents_tree.create_item()
	for ref_path in node.dependents:
		var item: TreeItem = _dependents_tree.create_item(root_ref)
		item.set_text(0, ref_path)
		item.set_metadata(0, ref_path)

func _on_dep_item_activated() -> void:
	var selected: TreeItem = _deps_tree.get_selected()
	if selected:
		var path: String = selected.get_metadata(0)
		asset_selected.emit(path)

func _on_dependent_item_activated() -> void:
	var selected: TreeItem = _dependents_tree.get_selected()
	if selected:
		var path: String = selected.get_metadata(0)
		asset_selected.emit(path)

func _on_open_in_editor() -> void:
	if _current_inspected_path.is_empty() or not Engine.is_editor_hint():
		return

	var ext: String = _current_inspected_path.get_extension().to_lower()
	match ext:
		"tscn", "scn":
			EditorInterface.open_scene_from_path(_current_inspected_path)
		"gd":
			var script_res = load(_current_inspected_path)
			if script_res:
				EditorInterface.edit_script(script_res)
		"tres", "res":
			var res = load(_current_inspected_path)
			if res:
				EditorInterface.edit_resource(res)
		_:
			EditorInterface.select_file(_current_inspected_path)

func _on_show_in_filesystem() -> void:
	if not _current_inspected_path.is_empty() and Engine.is_editor_hint():
		if EditorInterface.has_method("get_file_system_dock"):
			var fs_dock = EditorInterface.get_file_system_dock()
			if fs_dock and fs_dock.has_method("navigate_to_path"):
				fs_dock.navigate_to_path(_current_inspected_path)
				return
		if EditorInterface.has_method("select_file"):
			EditorInterface.select_file(_current_inspected_path)
