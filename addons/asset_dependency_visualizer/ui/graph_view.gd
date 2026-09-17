@tool
class_name GraphView
extends GraphEdit

## Clean Interactive Visual Graph Renderer. Supports Single-Object Focused 3-Column Views, Full Transitive Trees, and Dynamic Heatmaps.

signal asset_node_selected(path: String)
signal open_asset_requested(path: String)
signal notification_requested(title: String, message: String, type: String, action_label: String, action_callable: Callable, sec_label: String, sec_callable: Callable)

const AssetNodeScript = preload("res://addons/asset_dependency_visualizer/core/asset_node.gd")

enum ViewMode {
	FOCUSED_DIRECT = 0,
	FOCUSED_TRANSITIVE = 1,
	FULL_PROJECT = 2,
	CIRCULAR_LOOP = 3
}

var _service: RefCounted
var _graph_node_map: Dictionary = {} # path -> GraphNode
var _current_target_path: String = ""
var _current_cycle: Array = []
var _current_view_mode: ViewMode = ViewMode.FOCUSED_DIRECT
var _is_heatmap_active: bool = false

# Top Floating Control Bar inside GraphEdit
var _top_toolbar: PanelContainer
var _target_label: Label
var _view_mode_select: OptionButton

func _enter_tree() -> void:
	_setup_internal_toolbar()

func set_service(service: RefCounted) -> void:
	_service = service

func _setup_internal_toolbar() -> void:
	if _top_toolbar and is_instance_valid(_top_toolbar):
		return

	_top_toolbar = PanelContainer.new()
	_top_toolbar.custom_minimum_size = Vector2(0, 36)
	_top_toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_toolbar.offset_left = 12
	_top_toolbar.offset_top = 44
	_top_toolbar.offset_right = -12
	_top_toolbar.offset_bottom = 80

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.92)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_top_toolbar.add_theme_stylebox_override("panel", style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_toolbar.add_child(hbox)

	_target_label = Label.new()
	_target_label.text = "🎯 Select an asset from the list to view its clean dependency graph"
	_target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_target_label)

	var mode_label: Label = Label.new()
	mode_label.text = "Mode: "
	hbox.add_child(mode_label)

	_view_mode_select = OptionButton.new()
	_view_mode_select.add_item("🎯 Single Object (Clean 3-Column)", ViewMode.FOCUSED_DIRECT)
	_view_mode_select.add_item("🌳 Single Object (Full Transitive Tree)", ViewMode.FOCUSED_TRANSITIVE)
	_view_mode_select.add_item("🌐 Full Project Graph (All Assets)", ViewMode.FULL_PROJECT)
	_view_mode_select.add_item("⚠️ Circular Loop (Isolated Cycle)", ViewMode.CIRCULAR_LOOP)
	_view_mode_select.selected = ViewMode.FOCUSED_DIRECT
	_view_mode_select.item_selected.connect(_on_view_mode_selected)
	hbox.add_child(_view_mode_select)

	var center_btn: Button = Button.new()
	center_btn.text = "🔍 Center View"
	center_btn.pressed.connect(reset_view)
	hbox.add_child(center_btn)

	var export_menu_btn: MenuButton = MenuButton.new()
	export_menu_btn.text = "📊 Export View"
	var popup: PopupMenu = export_menu_btn.get_popup()
	popup.add_item("📊 Export Mermaid (Flowchart) (.mmd)", 0)
	popup.add_item("📐 Export Mermaid (UML Class Diagram) (.mmd)", 1)
	popup.add_item("📷 Export Snapshot Image (PNG)", 2)
	popup.id_pressed.connect(_on_export_menu_selected)
	hbox.add_child(export_menu_btn)

	add_child(_top_toolbar)

func get_current_view_mode() -> ViewMode:
	return _current_view_mode

func _sync_view_mode_select() -> void:
	if _view_mode_select and is_instance_valid(_view_mode_select):
		for i in range(_view_mode_select.item_count):
			if _view_mode_select.get_item_id(i) == _current_view_mode:
				_view_mode_select.selected = i
				break

func _on_view_mode_selected(idx: int) -> void:
	_current_view_mode = _view_mode_select.get_item_id(idx) as ViewMode
	if _current_view_mode == ViewMode.CIRCULAR_LOOP:
		if not _current_cycle.is_empty():
			show_circular_cycle(_current_cycle)
		elif not _current_target_path.is_empty() and _service and _service.get_graph():
			var found_cycle: Array = _service.get_graph().find_cycle_for_asset(_current_target_path)
			if not found_cycle.is_empty():
				show_circular_cycle(found_cycle)
			else:
				if _target_label and is_instance_valid(_target_label):
					_target_label.text = "⚠️ '%s' is not part of any circular dependency loop." % _current_target_path.get_file()
		elif _service and _service.get_graph():
			var cycles: Array[Array] = _service.get_graph().detect_circular_dependencies()
			if cycles.size() > 0:
				show_circular_cycle(cycles[0])
			else:
				if _target_label and is_instance_valid(_target_label):
					_target_label.text = "✅ No circular dependency loops detected in the project."
	elif not _current_target_path.is_empty():
		show_asset(_current_target_path)
	elif _service and _service.get_graph():
		rebuild_graph(_service.get_graph())

## Main entry point to display an asset in the graph view
func show_asset(path: String) -> void:
	_current_target_path = path
	if not _service:
		return
	var graph: RefCounted = _service.get_graph()
	if not graph or not graph.has_node(path):
		return

	if _current_view_mode == ViewMode.CIRCULAR_LOOP:
		var found_cycle: Array = graph.find_cycle_for_asset(path)
		if not found_cycle.is_empty():
			show_circular_cycle(found_cycle)
			return
		else:
			_current_view_mode = ViewMode.FOCUSED_DIRECT
			_sync_view_mode_select()

	if _target_label and is_instance_valid(_target_label):
		_target_label.text = "🎯 Focused Object: %s" % path.get_file()

	match _current_view_mode:
		ViewMode.FOCUSED_DIRECT:
			_render_focused_direct(graph, path)
		ViewMode.FOCUSED_TRANSITIVE:
			_render_focused_transitive(graph, path)
		ViewMode.FULL_PROJECT:
			_render_full_project(graph, path)

	if _is_heatmap_active:
		apply_size_heatmap()

## 1. Cleanest 3-Column Single-Object Focused View
func _render_focused_direct(graph: RefCounted, target_path: String) -> void:
	clear_graph()
	var target_node: AssetNode = graph.get_node(target_path)
	if not target_node:
		return

	var left_dependents: Array[String] = target_node.dependents.duplicate()
	var right_dependencies: Array[String] = target_node.dependencies.duplicate()

	var col_x_left: float = 60.0
	var col_x_center: float = 460.0
	var col_x_right: float = 860.0
	var row_height: float = 130.0
	var top_offset: float = 70.0

	var max_rows: int = maxi(1, maxi(left_dependents.size(), right_dependencies.size()))
	var center_y: float = top_offset + maxf(0.0, float(max_rows - 1) * row_height * 0.5)

	# 1. Create Left Column (Used By / Dependents)
	for i in range(left_dependents.size()):
		var dep_path: String = left_dependents[i]
		var d_node: AssetNode = graph.get_node(dep_path)
		if d_node:
			var gnode: GraphNode = _create_graph_node(d_node, Vector2(col_x_left, top_offset + i * row_height), false)
			_graph_node_map[dep_path] = gnode

	# 2. Create Center Target Node (Highlighted Gold / Blue)
	var target_gnode: GraphNode = _create_graph_node(target_node, Vector2(col_x_center, center_y), true)
	_graph_node_map[target_path] = target_gnode

	# 3. Create Right Column (Uses / Dependencies)
	for i in range(right_dependencies.size()):
		var dep_path: String = right_dependencies[i]
		var d_node: AssetNode = graph.get_node(dep_path)
		if d_node:
			var gnode: GraphNode = _create_graph_node(d_node, Vector2(col_x_right, top_offset + i * row_height), false)
			_graph_node_map[dep_path] = gnode

	# 4. Connect Wires: Left -> Center, Center -> Right
	var target_gname: String = _clean_node_name(target_path)
	for dep_path in left_dependents:
		var from_gname: String = _clean_node_name(dep_path)
		if has_node(from_gname) and has_node(target_gname):
			connect_node(from_gname, 0, target_gname, 0)

	for dep_path in right_dependencies:
		var to_gname: String = _clean_node_name(dep_path)
		if has_node(target_gname) and has_node(to_gname):
			connect_node(target_gname, 0, to_gname, 0)

	scroll_offset = Vector2.ZERO

## 2. Full Transitive Tree for Target Object
func _render_focused_transitive(graph: RefCounted, target_path: String) -> void:
	clear_graph()
	var trans_deps: Array[String] = graph.get_transitive_dependencies(target_path)
	var trans_refs: Array[String] = graph.get_transitive_dependents(target_path)

	var visible_paths: Array[String] = [target_path]
	for p in trans_deps:
		if not visible_paths.has(p):
			visible_paths.append(p)
	for p in trans_refs:
		if not visible_paths.has(p):
			visible_paths.append(p)

	_render_nodes_and_edges(graph, visible_paths, target_path)

## 3. Global Full Project View
func _render_full_project(graph: RefCounted, selected_path: String = "") -> void:
	clear_graph()
	_render_nodes_and_edges(graph, graph.nodes.keys(), selected_path)

## 4. Isolated Circular Dependency Loop Graph View
func show_circular_cycle(cycle_paths: Array) -> void:
	_current_cycle = cycle_paths.duplicate()
	_current_view_mode = ViewMode.CIRCULAR_LOOP
	_sync_view_mode_select()

	clear_graph()
	if not _service:
		return
	var graph: RefCounted = _service.get_graph()
	if not graph:
		return

	var count: int = cycle_paths.size()
	if count == 0:
		if _target_label and is_instance_valid(_target_label):
			_target_label.text = "⚠️ No assets in selected circular loop."
		return

	if _target_label and is_instance_valid(_target_label):
		_target_label.text = "⚠️ Circular Dependency Loop: %d assets in cycle" % count

	# Arrange nodes in a radial loop / ring
	var center_pos: Vector2 = Vector2(480.0, 320.0)
	var radius: float = maxf(180.0, float(count) * 65.0)

	for i in range(count):
		var path: String = str(cycle_paths[i])
		var node: AssetNode = graph.get_node(path)
		if not node:
			continue

		var pos: Vector2
		if count == 1:
			pos = center_pos
		elif count == 2:
			pos = Vector2(center_pos.x - 200.0 + i * 400.0, center_pos.y)
		else:
			var angle: float = (float(i) / float(count)) * TAU - (PI / 2.0)
			pos = center_pos + Vector2(cos(angle), sin(angle)) * radius

		var gnode: GraphNode = _create_cycle_graph_node(node, pos, i + 1, count)
		_graph_node_map[path] = gnode

	# Connect Directed Edges within the cycle
	for edge in graph.edges:
		if cycle_paths.has(edge.from_path) and cycle_paths.has(edge.to_path):
			var from_gname: String = _clean_node_name(edge.from_path)
			var to_gname: String = _clean_node_name(edge.to_path)
			if has_node(from_gname) and has_node(to_gname):
				connect_node(from_gname, 0, to_gname, 0)

	scroll_offset = Vector2.ZERO

func rebuild_graph(graph: RefCounted, selected_path: String = "") -> void:
	if _current_view_mode == ViewMode.CIRCULAR_LOOP:
		if not _current_cycle.is_empty():
			show_circular_cycle(_current_cycle)
			return
	if not selected_path.is_empty():
		show_asset(selected_path)
	elif graph and graph.get_node_count() > 0:
		# Pick main scene or first node
		var first_path: String = graph.nodes.keys()[0]
		for p in graph.nodes.keys():
			var n: AssetNode = graph.nodes[p]
			if n.is_main_scene:
				first_path = p
				break
		show_asset(first_path)

func _create_cycle_graph_node(node: AssetNode, pos: Vector2, step_index: int, total_steps: int) -> GraphNode:
	var gnode: GraphNode = GraphNode.new()
	gnode.name = _clean_node_name(node.path)
	gnode.position_offset = pos
	gnode.title = "⚠️ [%d/%d] %s" % [step_index, total_steps, node.path.get_file()]

	# Distinctive crimson/red alert style for circular loop nodes
	var alert_style: StyleBoxFlat = StyleBoxFlat.new()
	alert_style.bg_color = Color(0.22, 0.08, 0.10, 0.95)
	alert_style.border_color = Color(1.0, 0.35, 0.35)
	alert_style.set_border_width_all(3)
	alert_style.set_corner_radius_all(8)
	gnode.add_theme_stylebox_override("panel", alert_style)
	gnode.add_theme_stylebox_override("panel_selected", alert_style)

	# Slot label
	var slot_label: Label = Label.new()
	var cat_name: String = AssetNodeScript.category_to_string(node.type)
	slot_label.text = "%s | 📦 %s | ⚠️ Loop Node" % [cat_name, _format_bytes(node.size_bytes)]
	gnode.add_child(slot_label)

	var color_in: Color = Color(1.0, 0.35, 0.35) # Red incoming
	var color_out: Color = Color(1.0, 0.65, 0.2) # Orange outgoing
	gnode.set_slot(0, true, 0, color_in, true, 0, color_out)

	var p: String = node.path
	gnode.node_selected.connect(func(): asset_node_selected.emit(p))
	gnode.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			open_asset_requested.emit(p)
			_open_asset_in_editor(p)
	)

	add_child(gnode)
	return gnode

func focus_subgraph(center_path: String) -> void:
	show_asset(center_path)

func _create_graph_node(node: AssetNode, pos: Vector2, is_target: bool) -> GraphNode:
	var gnode: GraphNode = GraphNode.new()
	gnode.name = _clean_node_name(node.path)
	gnode.position_offset = pos

	if is_target:
		gnode.title = "⭐ " + node.path.get_file() + " [TARGET]"
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.22, 0.32, 0.95)
		style.border_color = Color(1.0, 0.85, 0.2) # Gold Glow
		style.set_border_width_all(3)
		style.set_corner_radius_all(8)
		gnode.add_theme_stylebox_override("panel", style)
		gnode.add_theme_stylebox_override("panel_selected", style)
	else:
		gnode.title = node.path.get_file()

	# Slot label
	var slot_label: Label = Label.new()
	var cat_name: String = AssetNodeScript.category_to_string(node.type)
	slot_label.text = "%s | 📦 %s" % [cat_name, _format_bytes(node.size_bytes)]
	gnode.add_child(slot_label)

	var color_left: Color = get_category_color(node.type)
	var color_right: Color = Color(1.0, 0.6, 0.2)
	gnode.set_slot(0, true, 0, color_left, true, 0, color_right)

	var p: String = node.path
	gnode.node_selected.connect(func(): asset_node_selected.emit(p))
	gnode.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			open_asset_requested.emit(p)
			_open_asset_in_editor(p)
	)

	add_child(gnode)
	return gnode

func _render_nodes_and_edges(graph: RefCounted, paths_to_render: Array, selected_path: String = "") -> void:
	clear_connections()

	var column_spacing: float = 340.0
	var row_spacing: float = 140.0
	var layer_map: Dictionary = {}
	var layer_counters: Dictionary = {}
	var memo: Dictionary = {}

	for path in paths_to_render:
		var depth: int = graph.get_max_dependency_depth(path, {}, memo)
		layer_map[path] = depth

	for path in paths_to_render:
		var node: AssetNode = graph.get_node(path)
		if not node:
			continue

		var layer: int = layer_map.get(path, 0)
		var count_in_layer: int = layer_counters.get(layer, 0)
		layer_counters[layer] = count_in_layer + 1

		var pos: Vector2 = Vector2(layer * column_spacing + 60, count_in_layer * row_spacing + 70)
		var gnode: GraphNode = _create_graph_node(node, pos, path == selected_path)
		_graph_node_map[path] = gnode

	# Connect Edges
	for edge in graph.edges:
		if paths_to_render.has(edge.from_path) and paths_to_render.has(edge.to_path):
			var from_gname: String = _clean_node_name(edge.from_path)
			var to_gname: String = _clean_node_name(edge.to_path)
			if has_node(from_gname) and has_node(to_gname):
				connect_node(from_gname, 0, to_gname, 0)

func filter_graph(query: String, cat_filter: int) -> void:
	if not _service:
		return
	var graph: RefCounted = _service.get_graph()
	if not graph:
		return

	var has_filter: bool = not query.is_empty() or cat_filter != -1

	for node_path in _graph_node_map.keys():
		var gnode: GraphNode = _graph_node_map[node_path]
		var node: AssetNode = graph.get_node(node_path)
		if not node:
			continue

		var matches_query: bool = query.is_empty() or node_path.to_lower().contains(query)
		var matches_cat: bool = (cat_filter == -1) or (node.type == cat_filter)

		if has_filter:
			if matches_query and matches_cat:
				gnode.modulate = Color.WHITE
			else:
				gnode.modulate = Color(0.35, 0.35, 0.35, 0.25)
		else:
			gnode.modulate = Color.WHITE

func clear_graph() -> void:
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			child.queue_free()
	_graph_node_map.clear()
	# Ensure floating toolbar stays on top
	if _top_toolbar and is_instance_valid(_top_toolbar):
		move_child(_top_toolbar, get_child_count() - 1)

func highlight_dependency_chain(path: String) -> void:
	show_asset(path)

func reset_highlight() -> void:
	_is_heatmap_active = false
	for node_path in _graph_node_map.keys():
		var gnode: GraphNode = _graph_node_map[node_path]
		gnode.modulate = Color.WHITE
		gnode.remove_theme_stylebox_override("panel")
		gnode.remove_theme_stylebox_override("panel_selected")

func is_heatmap_active() -> bool:
	return _is_heatmap_active

## Toggles size heatmap mode on or off
func toggle_size_heatmap() -> Dictionary:
	if _is_heatmap_active:
		_is_heatmap_active = false
		reset_highlight()
		if not _current_target_path.is_empty():
			show_asset(_current_target_path)
		return { "is_active": false, "min_bytes": 0, "max_bytes": 0 }
	else:
		return apply_size_heatmap()

## Applies dynamic relative size heatmap with glowing borders and formatted size tags
func apply_size_heatmap() -> Dictionary:
	if not _service:
		return { "is_active": false, "min_bytes": 0, "max_bytes": 0 }

	var graph: RefCounted = _service.get_graph()
	if not graph or _graph_node_map.is_empty():
		return { "is_active": false, "min_bytes": 0, "max_bytes": 0 }

	_is_heatmap_active = true

	# 1. Compute min and max file size
	var min_bytes: int = 2147483647
	var max_bytes: int = 0

	for node_path in _graph_node_map.keys():
		var node: AssetNode = graph.get_node(node_path)
		if node:
			min_bytes = mini(min_bytes, node.size_bytes)
			max_bytes = maxi(max_bytes, node.size_bytes)

	if min_bytes == 2147483647:
		min_bytes = 0

	# 2. Color each node using relative 3-stop gradient & custom glowing StyleBoxFlat
	for node_path in _graph_node_map.keys():
		var gnode: GraphNode = _graph_node_map[node_path]
		var node: AssetNode = graph.get_node(node_path)
		if not node:
			continue

		var color: Color = _calculate_heatmap_color(node.size_bytes, min_bytes, max_bytes)

		# Create glowing styled border & background for the node
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = color.darkened(0.7)
		style.border_color = color
		style.set_border_width_all(3)
		style.set_corner_radius_all(8)
		gnode.add_theme_stylebox_override("panel", style)
		gnode.add_theme_stylebox_override("panel_selected", style)

		# Update slot label with size
		if gnode.get_child_count() > 0 and gnode.get_child(0) is Label:
			var slot_label: Label = gnode.get_child(0)
			var cat_name: String = AssetNodeScript.category_to_string(node.type)
			slot_label.text = "%s | 📦 %s" % [cat_name, _format_bytes(node.size_bytes)]

	return {
		"is_active": true,
		"min_bytes": min_bytes,
		"max_bytes": max_bytes
	}

func _calculate_heatmap_color(size_bytes: int, min_bytes: int, max_bytes: int) -> Color:
	if max_bytes <= min_bytes or max_bytes == 0:
		return Color(0.25, 0.85, 0.45) # Default pleasant green

	var t: float = clampf(float(size_bytes - min_bytes) / float(max_bytes - min_bytes), 0.0, 1.0)

	if t < 0.5:
		var factor: float = t * 2.0
		return Color(0.2, 0.9, 0.5).lerp(Color(1.0, 0.85, 0.15), factor)
	else:
		var factor: float = (t - 0.5) * 2.0
		return Color(1.0, 0.85, 0.15).lerp(Color(1.0, 0.2, 0.2), factor)

func _format_bytes(bytes: int) -> String:
	if bytes >= 1048576:
		return "%.2f MB" % (float(bytes) / 1048576.0)
	elif bytes >= 1024:
		return "%.1f KB" % (float(bytes) / 1024.0)
	else:
		return "%d B" % bytes

func reset_view() -> void:
	scroll_offset = Vector2.ZERO
	zoom = 1.0

func export_graph_png(target_path: String = "res://reports/asset_graph_snapshot.png") -> void:
	if _graph_node_map.is_empty() and _service and _service.get_graph() and _service.get_graph().get_node_count() > 0:
		rebuild_graph(_service.get_graph())
		if Engine.get_main_loop():
			await Engine.get_main_loop().process_frame

	var vp: Viewport = get_viewport()
	if not vp:
		notification_requested.emit("Export Failed", "Viewport not found to capture graph image.", "error", "", Callable(), "", Callable())
		return
	var img: Image = vp.get_texture().get_image()
	if not img:
		notification_requested.emit("Export Failed", "Could not acquire viewport texture image.", "error", "", Callable(), "", Callable())
		return

	# Crop precisely to GraphView bounds (removes left tree, top bar, outside editor panels)
	var global_r: Rect2i = Rect2i(get_global_rect())
	var vp_rect: Rect2i = Rect2i(0, 0, img.get_width(), img.get_height())
	var crop_rect: Rect2i = global_r.intersection(vp_rect)
	if crop_rect.size.x > 0 and crop_rect.size.y > 0:
		img = img.get_region(crop_rect)

	var dir_path: String = target_path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var err: Error = img.save_png(target_path)
	if err == OK:
		notification_requested.emit(
			"Graph Snapshot Saved",
			"Saved graph image snapshot to:\n%s" % target_path,
			"success",
			"🔍 Show in FileSystem",
			func(): if Engine.is_editor_hint(): EditorInterface.select_file(target_path),
			"",
			Callable()
		)
	else:
		notification_requested.emit("Export Failed", "Error saving PNG snapshot to: %s" % target_path, "error", "", Callable(), "", Callable())
func _on_export_menu_selected(id: int) -> void:
	match id:
		0:
			export_active_view_mermaid()
		1:
			export_active_view_mermaid_uml()
		2:
			export_graph_png("res://reports/asset_graph_snapshot.png")

func export_active_view_mermaid() -> void:
	if _graph_node_map.is_empty() or not _service or not _service.get_graph():
		notification_requested.emit(
			"No Active Graph",
			"Please select an asset or circular loop to display in the graph before exporting.",
			"warning",
			"",
			Callable(),
			"",
			Callable()
		)
		return

	var paths: Array = _graph_node_map.keys()
	var content: String = _service.export_subgraph_mermaid(paths)
	var target_path: String = "res://reports/active_view_mermaid.mmd"
	_save_text_file(target_path, content, "Active View Mermaid Flowchart")

func export_active_view_mermaid_uml() -> void:
	if _graph_node_map.is_empty() or not _service or not _service.get_graph():
		notification_requested.emit(
			"No Active Graph",
			"Please select an asset or circular loop to display in the graph before exporting.",
			"warning",
			"",
			Callable(),
			"",
			Callable()
		)
		return

	var paths: Array = _graph_node_map.keys()
	var content: String = _service.export_subgraph_mermaid_uml(paths)
	var target_path: String = "res://reports/active_view_uml.mmd"
	_save_text_file(target_path, content, "Active View Mermaid UML")

func _save_text_file(target_path: String, content: String, report_name: String) -> void:
	var dir_path: String = target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		notification_requested.emit(
			"Graph Exported Successfully",
			"Saved %s to:\n%s" % [report_name, target_path],
			"success",
			"🔍 Show in FileSystem",
			func(): if Engine.is_editor_hint(): EditorInterface.select_file(target_path),
			"",
			Callable()
		)
	else:
		notification_requested.emit(
			"Export Failed",
			"Could not write to file:\n%s" % target_path,
			"error",
			"",
			Callable(),
			"",
			Callable()
		)

func _open_asset_in_editor(target_path: String) -> void:
	if not Engine.is_editor_hint() or target_path.is_empty():
		return
	var ext: String = target_path.get_extension().to_lower()
	match ext:
		"tscn", "scn":
			EditorInterface.open_scene_from_path(target_path)
		"gd":
			var script_res = load(target_path)
			if script_res:
				EditorInterface.edit_script(script_res)
		"tres", "res":
			var res = load(target_path)
			if res:
				EditorInterface.edit_resource(res)
		_:
			EditorInterface.select_file(target_path)

func _clean_node_name(path: String) -> String:
	return path.replace("://", "_").replace("/", "_").replace(".", "_").replace(" ", "_").replace("-", "_").replace("(", "_").replace(")", "_").replace("@", "_").replace(":", "_")

static func get_category_color(cat: int) -> Color:
	match cat:
		AssetNode.Category.SCENE: return Color(0.3, 0.9, 0.4) # Scene (Green)
		AssetNode.Category.SCRIPT: return Color(0.3, 0.8, 1.0) # Script (Cyan)
		AssetNode.Category.TEXTURE: return Color(0.8, 0.4, 0.9) # Texture (Purple)
		AssetNode.Category.AUDIO: return Color(1.0, 0.8, 0.2) # Audio (Yellow)
		AssetNode.Category.MATERIAL: return Color(1.0, 0.4, 0.6) # Material (Pink)
		AssetNode.Category.SHADER: return Color(0.9, 0.2, 0.3) # Shader (Red)
		AssetNode.Category.RESOURCE: return Color(1.0, 0.5, 0.2) # Resource (Orange)
		AssetNode.Category.MODEL_3D: return Color(0.3, 0.6, 1.0) # 3D Model (Sky Blue)
		AssetNode.Category.FONT: return Color(0.95, 0.75, 0.3) # Font (Gold)
		AssetNode.Category.ANIMATION: return Color(0.7, 0.4, 0.95) # Animation (Violet)
		_: return Color(0.7, 0.7, 0.7)
