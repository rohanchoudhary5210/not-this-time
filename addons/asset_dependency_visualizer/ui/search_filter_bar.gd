@tool
class_name SearchFilterBar
extends HBoxContainer

## Control bar for search query, asset category filtering, and sorting options.

signal filter_changed(search_query: String, category_filter: int, sort_option: int)

enum SortOption {
	NAME_ASC,
	NAME_DESC,
	SIZE_DESC,
	DEPENDENCIES_DESC,
	DEPENDENTS_DESC
}

var _search_input: LineEdit
var _category_select: OptionButton
var _sort_select: OptionButton

func _enter_tree() -> void:
	custom_minimum_size = Vector2(0, 32)
	_setup_ui()

func _setup_ui() -> void:
	for child in get_children():
		child.queue_free()

	# Search Input
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search asset by path or name..."
	_search_input.clear_button_enabled = true
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.text_changed.connect(func(_text): _on_filter_updated())
	add_child(_search_input)

	# Category Filter
	_category_select = OptionButton.new()
	_category_select.add_item("All Categories", -1)
	_category_select.add_item("Scenes (.tscn, .scn)", AssetNode.Category.SCENE)
	_category_select.add_item("Scripts (.gd, .cs)", AssetNode.Category.SCRIPT)
	_category_select.add_item("Textures (.png, .svg...)", AssetNode.Category.TEXTURE)
	_category_select.add_item("3D Models (.glb, .gltf, .obj)", AssetNode.Category.MODEL_3D)
	_category_select.add_item("Audio (.wav, .ogg, .mp3)", AssetNode.Category.AUDIO)
	_category_select.add_item("Fonts (.ttf, .otf)", AssetNode.Category.FONT)
	_category_select.add_item("Animations (.anim)", AssetNode.Category.ANIMATION)
	_category_select.add_item("Resources (.tres, .res)", AssetNode.Category.RESOURCE)
	_category_select.add_item("Materials", AssetNode.Category.MATERIAL)
	_category_select.add_item("Shaders", AssetNode.Category.SHADER)
	_category_select.item_selected.connect(func(_idx): _on_filter_updated())
	add_child(_category_select)

	# Sort Option
	_sort_select = OptionButton.new()
	_sort_select.add_item("Sort: Name (A-Z)", SortOption.NAME_ASC)
	_sort_select.add_item("Sort: Name (Z-A)", SortOption.NAME_DESC)
	_sort_select.add_item("Sort: Size (Largest)", SortOption.SIZE_DESC)
	_sort_select.add_item("Sort: Dependencies (Most)", SortOption.DEPENDENCIES_DESC)
	_sort_select.add_item("Sort: Dependents (Most)", SortOption.DEPENDENTS_DESC)
	_sort_select.item_selected.connect(func(_idx): _on_filter_updated())
	add_child(_sort_select)

func _on_filter_updated() -> void:
	var query: String = _search_input.text.strip_edges().to_lower()
	var cat: int = _category_select.get_selected_id()
	var sort_opt: int = _sort_select.get_selected_id()
	filter_changed.emit(query, cat, sort_opt)

func get_search_query() -> String:
	return _search_input.text.strip_edges().to_lower() if _search_input else ""

func get_category_filter() -> int:
	return _category_select.get_selected_id() if _category_select else -1

func get_sort_option() -> int:
	return _sort_select.get_selected_id() if _sort_select else SortOption.NAME_ASC

