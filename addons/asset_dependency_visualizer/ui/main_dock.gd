@tool
class_name MainDock
extends Control

## Master Editor Dock for Asset Dependency Visualizer. Coordinates tabs, service scans, search filtering, and view synchronization.

const AssetDependencyServiceScript = preload("res://addons/asset_dependency_visualizer/core/asset_dependency_service.gd")
const SearchFilterBarScript = preload("res://addons/asset_dependency_visualizer/ui/search_filter_bar.gd")
const InspectorPanelScript = preload("res://addons/asset_dependency_visualizer/ui/inspector_panel.gd")
const GraphViewScript = preload("res://addons/asset_dependency_visualizer/ui/graph_view.gd")
const HealthReportViewScript = preload("res://addons/asset_dependency_visualizer/ui/health_report_view.gd")

var service: RefCounted
var search_bar: Control
var tab_container: TabContainer
var inspector_panel: Control
var graph_view: Control
var health_report_view: Control

var _scan_btn: Button
var _incremental_btn: Button
var _heatmap_btn: Button
var _progress_bar: ProgressBar
var _status_label: Label
var _asset_tree: Tree # Tree view for quick asset navigation
var _loading_overlay: ColorRect
var _overlay_progress_bar: ProgressBar
var _overlay_status_label: Label
var _scan_start_ticks: int = 0

var _modal_overlay: ColorRect
var _modal_panel: PanelContainer
var _modal_title_label: Label
var _modal_body_label: Label
var _modal_action_btn: Button
var _modal_sec_action_btn: Button
var _modal_dismiss_btn: Button
var _modal_action_callback: Callable = Callable()
var _modal_sec_action_callback: Callable = Callable()

var _current_filter_query: String = ""
var _current_filter_cat: int = -1
var _current_sort_option: int = 0
var _current_inspected_path: String = ""

func _enter_tree() -> void:
	if not service:
		service = AssetDependencyServiceScript.new()

	if not service.scan_started.is_connected(_on_scan_started):
		service.scan_started.connect(_on_scan_started)
	if not service.scan_status_changed.is_connected(_on_scan_status_changed):
		service.scan_status_changed.connect(_on_scan_status_changed)
	if not service.scan_progress.is_connected(_on_scan_progress):
		service.scan_progress.connect(_on_scan_progress)
	if not service.scan_completed.is_connected(_on_scan_completed):
		service.scan_completed.connect(_on_scan_completed)

	_setup_ui()

func _setup_ui() -> void:
	if tab_container and is_instance_valid(tab_container):
		return

	for child in get_children():
		child.queue_free()

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)

	# 1. Top Control Bar (Scan buttons, Progress Bar, Focus Controls)
	var top_bar: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(top_bar)

	_scan_btn = Button.new()
	_scan_btn.text = "🔄 Full Scan"
	_scan_btn.pressed.connect(func(): service.run_full_scan())
	top_bar.add_child(_scan_btn)

	_incremental_btn = Button.new()
	_incremental_btn.text = "⚡ Incremental"
	_incremental_btn.pressed.connect(func(): service.run_incremental_scan())
	top_bar.add_child(_incremental_btn)

	var focus_btn: Button = Button.new()
	focus_btn.text = "🎯 Focus Subgraph"
	focus_btn.tooltip_text = "Isolate and view only the selected asset and its dependencies"
	focus_btn.pressed.connect(_on_focus_subgraph_pressed)
	top_bar.add_child(focus_btn)

	var reset_graph_btn: Button = Button.new()
	reset_graph_btn.text = "🌐 Show Full Graph"
	reset_graph_btn.tooltip_text = "Reset graph view to show all project assets"
	reset_graph_btn.pressed.connect(func():
		if service and service.get_graph() and graph_view:
			graph_view.rebuild_graph(service.get_graph(), _current_inspected_path)
	)
	top_bar.add_child(reset_graph_btn)

	_heatmap_btn = Button.new()
	_heatmap_btn.text = "🔥 Size Heatmap"
	_heatmap_btn.tooltip_text = "Toggle dynamic color gradient and size labels based on relative file sizes"
	_heatmap_btn.pressed.connect(_on_heatmap_pressed)
	top_bar.add_child(_heatmap_btn)

	var float_btn: Button = Button.new()
	float_btn.text = "🗗 Float Window"
	float_btn.pressed.connect(_on_toggle_float_window)
	top_bar.add_child(float_btn)

	_status_label = Label.new()
	_status_label.text = "Ready to scan project dependencies."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(150, 20)
	_progress_bar.visible = false
	top_bar.add_child(_progress_bar)

	# 2. Search & Filter Bar
	search_bar = SearchFilterBarScript.new()
	search_bar.filter_changed.connect(_on_filter_changed)
	main_vbox.add_child(search_bar)

	# 3. Main Split View (Left: Asset Tree list, Right: Tabbed View)
	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(hsplit)

	# Left Column: Asset Tree List
	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(260, 0)
	hsplit.add_child(left_vbox)

	var list_header: Label = Label.new()
	list_header.text = "Project Assets:"
	left_vbox.add_child(list_header)

	_asset_tree = Tree.new()
	_asset_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_tree.hide_root = true
	_asset_tree.item_selected.connect(_on_asset_tree_selected)
	left_vbox.add_child(_asset_tree)

	# Right Column: TabContainer (Inspector, Graph View, Health Report)
	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(tab_container)

	# Tab 1: Inspector
	inspector_panel = InspectorPanelScript.new()
	inspector_panel.name = "Inspector"
	inspector_panel.set_service(service)
	inspector_panel.asset_selected.connect(select_and_inspect_asset)
	tab_container.add_child(inspector_panel)

	# Tab 2: Visual Graph
	graph_view = GraphViewScript.new()
	graph_view.name = "Visual Graph"
	graph_view.set_service(service)
	graph_view.asset_node_selected.connect(_on_graph_node_selected)
	graph_view.open_asset_requested.connect(select_and_inspect_asset)
	graph_view.notification_requested.connect(show_modal_message)
	tab_container.add_child(graph_view)

	# Tab 3: Health Report
	health_report_view = HealthReportViewScript.new()
	health_report_view.name = "Health Report"
	health_report_view.set_service(service)
	health_report_view.inspect_asset_requested.connect(select_and_inspect_asset)
	health_report_view.inspect_cycle_requested.connect(_on_inspect_cycle_requested)
	health_report_view.export_graph_png_requested.connect(_on_health_report_export_png)
	health_report_view.notification_requested.connect(show_modal_message)
	tab_container.add_child(health_report_view)

	# 4. Loading Overlay (drawn on top of everything)
	_loading_overlay = ColorRect.new()
	_loading_overlay.color = Color(0.1, 0.1, 0.1, 0.75)
	_loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_overlay.visible = false
	add_child(_loading_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)

	# Set standard stylebox for the panel
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.17, 0.2, 0.95)
	panel_style.set_corner_radius_all(8)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.3, 0.35, 0.45)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	margin.add_theme_constant_override("margin_left", 35)
	margin.add_theme_constant_override("margin_right", 35)
	panel.add_child(margin)

	var overlay_vbox: VBoxContainer = VBoxContainer.new()
	overlay_vbox.custom_minimum_size = Vector2(380, 0)
	margin.add_child(overlay_vbox)

	var title_label: Label = Label.new()
	title_label.text = "🔍 Scanning Project Dependencies..."
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	overlay_vbox.add_child(title_label)

	var spacer1: Control = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 15)
	overlay_vbox.add_child(spacer1)

	_overlay_progress_bar = ProgressBar.new()
	_overlay_progress_bar.custom_minimum_size = Vector2(350, 24)
	overlay_vbox.add_child(_overlay_progress_bar)

	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	overlay_vbox.add_child(spacer2)

	_overlay_status_label = Label.new()
	_overlay_status_label.text = "Initializing scan..."
	_overlay_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_vbox.add_child(_overlay_status_label)

	# 5. Modal Alert & Notification Overlay (drawn on top of the dock)
	_modal_overlay = ColorRect.new()
	_modal_overlay.color = Color(0.08, 0.10, 0.14, 0.80)
	_modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_overlay.visible = false
	_modal_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hide_modal()
	)
	add_child(_modal_overlay)

	var modal_center: CenterContainer = CenterContainer.new()
	modal_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_overlay.add_child(modal_center)

	_modal_panel = PanelContainer.new()
	_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_center.add_child(_modal_panel)

	var m_margin: MarginContainer = MarginContainer.new()
	m_margin.add_theme_constant_override("margin_top", 22)
	m_margin.add_theme_constant_override("margin_bottom", 22)
	m_margin.add_theme_constant_override("margin_left", 32)
	m_margin.add_theme_constant_override("margin_right", 32)
	_modal_panel.add_child(m_margin)

	var m_vbox: VBoxContainer = VBoxContainer.new()
	m_vbox.custom_minimum_size = Vector2(400, 0)
	m_margin.add_child(m_vbox)

	_modal_title_label = Label.new()
	_modal_title_label.text = "Notification"
	_modal_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title_label.add_theme_font_size_override("font_size", 16)
	m_vbox.add_child(_modal_title_label)

	var m_spacer: Control = Control.new()
	m_spacer.custom_minimum_size = Vector2(0, 10)
	m_vbox.add_child(m_spacer)

	_modal_body_label = Label.new()
	_modal_body_label.text = "Message details..."
	_modal_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_body_label.custom_minimum_size = Vector2(380, 0)
	m_vbox.add_child(_modal_body_label)

	var m_spacer2: Control = Control.new()
	m_spacer2.custom_minimum_size = Vector2(0, 18)
	m_vbox.add_child(m_spacer2)

	var m_btn_bar: HBoxContainer = HBoxContainer.new()
	m_btn_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	m_btn_bar.add_theme_constant_override("separation", 12)
	m_vbox.add_child(m_btn_bar)

	_modal_action_btn = Button.new()
	_modal_action_btn.text = "Action"
	_modal_action_btn.visible = false
	_modal_action_btn.pressed.connect(func():
		var cb: Callable = _modal_action_callback
		hide_modal()
		if cb.is_valid():
			cb.call()
	)
	m_btn_bar.add_child(_modal_action_btn)

	_modal_sec_action_btn = Button.new()
	_modal_sec_action_btn.text = "Secondary"
	_modal_sec_action_btn.visible = false
	_modal_sec_action_btn.pressed.connect(func():
		var cb: Callable = _modal_sec_action_callback
		hide_modal()
		if cb.is_valid():
			cb.call()
	)
	m_btn_bar.add_child(_modal_sec_action_btn)

	_modal_dismiss_btn = Button.new()
	_modal_dismiss_btn.text = "OK"
	_modal_dismiss_btn.pressed.connect(hide_modal)
	m_btn_bar.add_child(_modal_dismiss_btn)

func show_modal_message(title: String, message: String, type: String = "info", action_label: String = "", action_callable: Callable = Callable(), sec_label: String = "", sec_callable: Callable = Callable()) -> void:
	if not _modal_overlay or not is_instance_valid(_modal_overlay):
		_setup_ui()

	_modal_body_label.text = message
	_modal_action_callback = action_callable
	_modal_sec_action_callback = sec_callable

	if not action_label.is_empty():
		_modal_action_btn.text = action_label
		_modal_action_btn.visible = true
	else:
		_modal_action_btn.visible = false

	if not sec_label.is_empty():
		_modal_sec_action_btn.text = sec_label
		_modal_sec_action_btn.visible = true
	else:
		_modal_sec_action_btn.visible = false

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.set_corner_radius_all(8)
	panel_style.set_border_width_all(2)

	match type.to_lower():
		"success":
			panel_style.bg_color = Color(0.10, 0.18, 0.12, 0.96)
			panel_style.border_color = Color(0.25, 0.90, 0.45)
			_modal_title_label.text = "✅ " + title.trim_prefix("✅ ")
			_modal_dismiss_btn.text = "OK"
		"warning":
			panel_style.bg_color = Color(0.18, 0.14, 0.08, 0.96)
			panel_style.border_color = Color(1.0, 0.70, 0.20)
			_modal_title_label.text = "⚠️ " + title.trim_prefix("⚠️ ")
			_modal_dismiss_btn.text = "Dismiss"
		"error":
			panel_style.bg_color = Color(0.22, 0.08, 0.10, 0.96)
			panel_style.border_color = Color(1.0, 0.35, 0.35)
			_modal_title_label.text = "❌ " + title.trim_prefix("❌ ")
			_modal_dismiss_btn.text = "Close"
		_:
			panel_style.bg_color = Color(0.12, 0.15, 0.22, 0.96)
			panel_style.border_color = Color(0.35, 0.65, 1.0)
			_modal_title_label.text = "ℹ️ " + title.trim_prefix("ℹ️ ")
			_modal_dismiss_btn.text = "OK"

	_modal_panel.add_theme_stylebox_override("panel", panel_style)
	_modal_overlay.visible = true

func hide_modal() -> void:
	if _modal_overlay and is_instance_valid(_modal_overlay):
		_modal_overlay.visible = false

func select_and_inspect_asset(path: String) -> void:
	_current_inspected_path = path
	if not inspector_panel or not is_instance_valid(inspector_panel):
		_setup_ui()
	if inspector_panel:
		inspector_panel.inspect_asset(path)
	if graph_view:
		graph_view.show_asset(path)

func _on_graph_node_selected(path: String) -> void:
	_current_inspected_path = path
	if inspector_panel:
		inspector_panel.inspect_asset(path)
	if graph_view and graph_view.get_current_view_mode() != GraphViewScript.ViewMode.CIRCULAR_LOOP and graph_view.get_current_view_mode() != GraphViewScript.ViewMode.FULL_PROJECT:
		graph_view.show_asset(path)

func _on_inspect_cycle_requested(cycle: Array) -> void:
	if cycle.is_empty():
		return
	if not tab_container or not is_instance_valid(tab_container):
		_setup_ui()
	if tab_container:
		tab_container.current_tab = 1 # Switch to Visual Graph tab
	if graph_view:
		graph_view.show_circular_cycle(cycle)
	if _status_label:
		_status_label.text = "⚠️ Showing Circular Dependency Loop (%d assets in cycle)" % cycle.size()

func _on_health_report_export_png() -> void:
	if not graph_view or not is_instance_valid(graph_view):
		return
	if tab_container and is_instance_valid(tab_container):
		tab_container.current_tab = 1 # Auto-switch to Visual Graph tab
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().process_frame
	graph_view.export_graph_png("res://reports/asset_graph_snapshot.png")

func _on_focus_subgraph_pressed() -> void:
	if _current_inspected_path.is_empty():
		show_modal_message(
			"No Asset Selected",
			"Please select an asset from the project asset list on the left to focus its subgraph.",
			"info"
		)
		return
	if graph_view:
		graph_view.show_asset(_current_inspected_path)
		tab_container.current_tab = 1 # Switch to Graph tab

func _on_heatmap_pressed() -> void:
	if not graph_view or not service or not service.get_graph() or service.get_graph().get_node_count() == 0:
		show_modal_message(
			"Scan Required",
			"Please run a scan first to calculate asset sizes and view the heatmap.",
			"warning",
			"🔄 Run Full Scan Now",
			func(): service.run_full_scan()
		)
		return

	tab_container.current_tab = 1 # Always switch to Visual Graph tab!
	var res: Dictionary = graph_view.toggle_size_heatmap()
	var is_active: bool = res.get("is_active", false)

	# Also refresh the tree list so it highlights with heatmap colors too
	_populate_asset_tree(service.get_graph())

	if is_active:
		var min_b: int = res.get("min_bytes", 0)
		var max_b: int = res.get("max_bytes", 0)
		_heatmap_btn.text = "🔥 Heatmap (ON)"
		_status_label.text = "🔥 Size Heatmap Active: 🟢 %s (Smallest) ➔ 🟡 ➔ 🔴 %s (Largest)" % [
			_format_bytes_helper(min_b),
			_format_bytes_helper(max_b)
		]
	else:
		_heatmap_btn.text = "🔥 Size Heatmap"
		_status_label.text = "Size heatmap turned off. Category colors restored."

func _format_bytes_helper(bytes: int) -> String:
	if bytes >= 1048576:
		return "%.2f MB" % (float(bytes) / 1048576.0)
	elif bytes >= 1024:
		return "%.1f KB" % (float(bytes) / 1024.0)
	else:
		return "%d B" % bytes

func _calculate_tree_heatmap_color(size_bytes: int, min_bytes: int, max_bytes: int) -> Color:
	if max_bytes <= min_bytes or max_bytes == 0:
		return Color(0.3, 0.9, 0.5)
	var t: float = clampf(float(size_bytes - min_bytes) / float(max_bytes - min_bytes), 0.0, 1.0)
	if t < 0.5:
		return Color(0.2, 0.9, 0.5).lerp(Color(1.0, 0.85, 0.15), t * 2.0)
	else:
		return Color(1.0, 0.85, 0.15).lerp(Color(1.0, 0.25, 0.25), (t - 0.5) * 2.0)

func _on_scan_started() -> void:
	_scan_start_ticks = Time.get_ticks_msec()
	if _loading_overlay:
		_loading_overlay.visible = true
		_overlay_progress_bar.value = 0
		_overlay_progress_bar.max_value = 100
		_overlay_status_label.text = "Initializing scan..."

func _on_scan_status_changed(status_text: String) -> void:
	_status_label.text = status_text
	if _loading_overlay:
		_overlay_status_label.text = status_text
		# Force a UI redraw by letting Godot process drawing events
		await Engine.get_main_loop().process_frame

func _on_scan_progress(current: int, total: int) -> void:
	_progress_bar.visible = true
	_progress_bar.max_value = total
	_progress_bar.value = current
	_status_label.text = "Scanning asset %d / %d..." % [current, total]

	if _loading_overlay:
		_overlay_progress_bar.max_value = total
		_overlay_progress_bar.value = current
		_overlay_status_label.text = "Analyzing dependencies: %d / %d assets" % [current, total]

func _on_scan_completed(graph: DependencyGraph, summary: Dictionary) -> void:
	var elapsed: int = Time.get_ticks_msec() - _scan_start_ticks
	if elapsed < 400:
		if is_inside_tree() and get_tree():
			await get_tree().create_timer(float(400 - elapsed) / 1000.0, true, false, true).timeout
		elif Engine.get_main_loop():
			await Engine.get_main_loop().create_timer(float(400 - elapsed) / 1000.0, true, false, true).timeout

	_progress_bar.visible = false
	if _loading_overlay:
		_loading_overlay.visible = false

	if _heatmap_btn:
		_heatmap_btn.text = "🔥 Size Heatmap"
	_status_label.text = "Scan complete! Found %d assets, %d edges." % [graph.get_node_count(), graph.get_edge_count()]

	_populate_asset_tree(graph)
	
	# Select first asset cleanly and display ONLY its focused graph
	if not _current_inspected_path.is_empty() and graph.has_node(_current_inspected_path):
		select_and_inspect_asset(_current_inspected_path)
	elif graph.get_node_count() > 0:
		var first_p: String = graph.nodes.keys()[0]
		for p in graph.nodes.keys():
			var n: AssetNode = graph.nodes[p]
			if n.is_main_scene:
				first_p = p
				break
		select_and_inspect_asset(first_p)

	health_report_view.update_report(summary)

func _populate_asset_tree(graph: DependencyGraph) -> void:
	_asset_tree.clear()
	var root: TreeItem = _asset_tree.create_item()

	var nodes_arr: Array = graph.nodes.values()
	_apply_sorting_and_filtering(nodes_arr)

	var is_hm: bool = graph_view and graph_view.is_heatmap_active()
	var min_bytes: int = 2147483647
	var max_bytes: int = 0

	if is_hm:
		for n in nodes_arr:
			var node: AssetNode = n
			min_bytes = mini(min_bytes, node.size_bytes)
			max_bytes = maxi(max_bytes, node.size_bytes)
		if min_bytes == 2147483647:
			min_bytes = 0

	for n in nodes_arr:
		var node: AssetNode = n
		var item: TreeItem = _asset_tree.create_item(root)
		item.set_text(0, "%s  [📦 %s] (%s)" % [
			node.path.get_file(),
			_format_bytes_helper(node.size_bytes),
			AssetNode.category_to_string(node.type)
		])
		item.set_metadata(0, node.path)
		
		# Set editor icon if available
		var icon: Texture2D = _get_editor_icon_for_category(node.type)
		if icon:
			item.set_icon(0, icon)

		# If heatmap is active, color the text in tree list as well
		if is_hm:
			item.set_custom_color(0, _calculate_tree_heatmap_color(node.size_bytes, min_bytes, max_bytes))

func _apply_sorting_and_filtering(nodes_arr: Array) -> void:
	# 1. Filter by Search Query & Category
	for i in range(nodes_arr.size() - 1, -1, -1):
		var n: AssetNode = nodes_arr[i]
		if not _current_filter_query.is_empty() and not n.path.to_lower().contains(_current_filter_query):
			nodes_arr.remove_at(i)
			continue
		if _current_filter_cat != -1 and n.type != _current_filter_cat:
			nodes_arr.remove_at(i)
			continue

	# 2. Apply Sorting Mode
	match _current_sort_option:
		SearchFilterBar.SortOption.NAME_ASC:
			nodes_arr.sort_custom(func(a: AssetNode, b: AssetNode): return a.path.get_file().nocasecmp_to(b.path.get_file()) < 0)
		SearchFilterBar.SortOption.NAME_DESC:
			nodes_arr.sort_custom(func(a: AssetNode, b: AssetNode): return a.path.get_file().nocasecmp_to(b.path.get_file()) > 0)
		SearchFilterBar.SortOption.SIZE_DESC:
			nodes_arr.sort_custom(func(a: AssetNode, b: AssetNode): return a.size_bytes > b.size_bytes)
		SearchFilterBar.SortOption.DEPENDENCIES_DESC:
			nodes_arr.sort_custom(func(a: AssetNode, b: AssetNode): return a.dependencies.size() > b.dependencies.size())
		SearchFilterBar.SortOption.DEPENDENTS_DESC:
			nodes_arr.sort_custom(func(a: AssetNode, b: AssetNode): return a.dependents.size() > b.dependents.size())

func _on_filter_changed(query: String, cat: int, sort_opt: int) -> void:
	_current_filter_query = query
	_current_filter_cat = cat
	_current_sort_option = sort_opt

	if service and service.get_graph():
		_populate_asset_tree(service.get_graph())
		if graph_view:
			graph_view.filter_graph(_current_filter_query, _current_filter_cat)

func _on_asset_tree_selected() -> void:
	var selected: TreeItem = _asset_tree.get_selected()
	if selected:
		var path: String = selected.get_metadata(0)
		select_and_inspect_asset(path)

func _get_editor_icon_for_category(cat: int) -> Texture2D:
	if not Engine.is_editor_hint():
		return null
	var theme: Theme = EditorInterface.get_editor_theme()
	if not theme:
		return null

	match cat:
		AssetNode.Category.SCENE:
			return theme.get_icon("PackedScene", "EditorIcons") if theme.has_icon("PackedScene", "EditorIcons") else null
		AssetNode.Category.SCRIPT:
			return theme.get_icon("Script", "EditorIcons") if theme.has_icon("Script", "EditorIcons") else null
		AssetNode.Category.TEXTURE:
			return theme.get_icon("ImageTexture", "EditorIcons") if theme.has_icon("ImageTexture", "EditorIcons") else null
		AssetNode.Category.AUDIO:
			return theme.get_icon("AudioStream", "EditorIcons") if theme.has_icon("AudioStream", "EditorIcons") else null
		AssetNode.Category.MODEL_3D:
			return theme.get_icon("Mesh", "EditorIcons") if theme.has_icon("Mesh", "EditorIcons") else null
		AssetNode.Category.FONT:
			return theme.get_icon("Font", "EditorIcons") if theme.has_icon("Font", "EditorIcons") else null
		AssetNode.Category.ANIMATION:
			return theme.get_icon("Animation", "EditorIcons") if theme.has_icon("Animation", "EditorIcons") else null
		AssetNode.Category.MATERIAL:
			return theme.get_icon("Material", "EditorIcons") if theme.has_icon("Material", "EditorIcons") else null
		AssetNode.Category.SHADER:
			return theme.get_icon("Shader", "EditorIcons") if theme.has_icon("Shader", "EditorIcons") else null
		AssetNode.Category.RESOURCE:
			return theme.get_icon("ResourcePreloader", "EditorIcons") if theme.has_icon("ResourcePreloader", "EditorIcons") else null
		_:
			return theme.get_icon("Object", "EditorIcons") if theme.has_icon("Object", "EditorIcons") else null

var _floating_window: Window

func _on_toggle_float_window() -> void:
	if _floating_window and is_instance_valid(_floating_window):
		_floating_window.grab_focus()
		return

	_floating_window = Window.new()
	_floating_window.title = "Asset Dependency Visualizer — Floating Window"
	_floating_window.size = Vector2i(1024, 700)
	_floating_window.close_requested.connect(func():
		_floating_window.queue_free()
		_floating_window = null
	)

	var sub_dock: Control = MainDock.new()
	sub_dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floating_window.add_child(sub_dock)

	if Engine.is_editor_hint():
		EditorInterface.get_base_control().add_child(_floating_window)
		_floating_window.popup_centered()

