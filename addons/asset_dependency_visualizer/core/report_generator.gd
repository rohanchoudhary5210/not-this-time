@tool
class_name ReportGenerator
extends RefCounted

## Exports graph data and health reports into JSON, CSV, and Markdown formats.

static func export_to_json(graph: DependencyGraph, health_summary: Dictionary) -> String:
	var nodes_data: Array[Dictionary] = []
	for node in graph.nodes.values():
		nodes_data.append((node as AssetNode).to_dict())

	var edges_data: Array[Dictionary] = []
	for edge in graph.edges:
		edges_data.append((edge as DependencyEdge).to_dict())

	var export_dict: Dictionary = {
		"generated_at": Time.get_datetime_string_from_system(),
		"summary": health_summary,
		"nodes": nodes_data,
		"edges": edges_data
	}

	return JSON.stringify(export_dict, "\t")

static func export_to_csv(graph: DependencyGraph) -> String:
	var lines: Array[String] = [
		"Path,Type,Extension,SizeBytes,DependenciesCount,DependentsCount,IsMainScene,IsAutoload"
	]

	for n in graph.nodes.values():
		var node: AssetNode = n
		lines.append('"%s","%s","%s",%d,%d,%d,%s,%s' % [
			node.path,
			AssetNode.category_to_string(node.type),
			node.extension,
			node.size_bytes,
			node.dependencies.size(),
			node.dependents.size(),
			str(node.is_main_scene),
			str(node.is_autoload)
		])

	return "\n".join(lines)

static func export_to_markdown(graph: DependencyGraph, health_summary: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# Asset Dependency & Health Report")
	lines.append("Generated on: %s\n" % Time.get_datetime_string_from_system())

	lines.append("## Overview")
	lines.append("- **Total Assets:** %d" % health_summary.get("total_assets", 0))
	lines.append("- **Total Dependency Edges:** %d" % health_summary.get("total_edges", 0))
	lines.append("- **Potentially Unused Assets:** %d" % health_summary.get("potentially_unused_count", 0))
	lines.append("- **Duplicate Content Groups:** %d" % health_summary.get("duplicate_group_count", 0))
	lines.append("- **Circular Dependencies Found:** %d\n" % health_summary.get("circular_dependencies_count", 0))

	lines.append("## Asset Categories")
	var cats: Dictionary = health_summary.get("category_counts", {})
	for cat_name in cats.keys():
		lines.append("- **%s:** %d" % [cat_name, cats[cat_name]])
	lines.append("")

	var cycles: Array = health_summary.get("circular_dependencies", [])
	if cycles.size() > 0:
		lines.append("## ⚠️ Circular Dependencies Detected")
		for cycle in cycles:
			lines.append("- Loop: `%s`" % " ➔ ".join(cycle))
		lines.append("")

	var heavy: Array = health_summary.get("heavy_assets", [])
	if heavy.size() > 0:
		lines.append("## 📦 Top Heavy Assets")
		lines.append("| Path | Type | Size (KB) |")
		lines.append("| --- | --- | --- |")
		for item in heavy:
			var kb: float = float(item["size_bytes"]) / 1024.0
			lines.append("| `%s` | %s | %.2f KB |" % [item["path"], item["type"], kb])
		lines.append("")

	var heaviest_chain: Dictionary = health_summary.get("heaviest_chain", {})
	if not heaviest_chain.is_empty():
		lines.append("## 🏋️ Heaviest Transitive Dependency Chain")
		var root_p: String = heaviest_chain.get("root_path", "")
		var tot_kb: float = float(heaviest_chain.get("total_transitive_bytes", 0)) / 1024.0
		lines.append("- **Root Asset:** `%s`" % root_p)
		lines.append("- **Total Transitive Weight:** %.2f KB" % tot_kb)
		lines.append("- **Chain Dependencies:** `%s`" % ", ".join(heaviest_chain.get("transitive_chain", [])))
		lines.append("")

	return "\n".join(lines)

static func export_to_mermaid(graph: DependencyGraph) -> String:
	if not graph or graph.nodes.is_empty():
		return "flowchart TD\n    empty_node[\"No assets in project\"]\n"
	return export_subgraph_to_mermaid(graph, graph.nodes.keys())

static func export_subgraph_to_mermaid(graph: DependencyGraph, active_paths: Array) -> String:
	if not graph or active_paths.is_empty():
		return "flowchart TD\n    empty_node[\"No visible assets to export\"]\n"

	var lines: Array[String] = [
		"flowchart TD",
		"    %% Category Color Classes",
		"    classDef sceneClass fill:#1e4620,stroke:#38a169,stroke-width:2px,color:#e2e8f0;",
		"    classDef scriptClass fill:#1a365d,stroke:#3182ce,stroke-width:2px,color:#e2e8f0;",
		"    classDef textureClass fill:#44337a,stroke:#805ad5,stroke-width:2px,color:#e2e8f0;",
		"    classDef audioClass fill:#5f4510,stroke:#d69e2e,stroke-width:2px,color:#e2e8f0;",
		"    classDef resourceClass fill:#5f370e,stroke:#dd6b20,stroke-width:2px,color:#e2e8f0;",
		"    classDef shaderClass fill:#5a1827,stroke:#e53e3e,stroke-width:2px,color:#e2e8f0;",
		"    classDef materialClass fill:#521b41,stroke:#d53f8c,stroke-width:2px,color:#e2e8f0;",
		"    classDef otherClass fill:#2d3748,stroke:#718096,stroke-width:2px,color:#e2e8f0;",
		""
	]

	var node_ids: Dictionary = {}
	var id_counter: int = 0

	for path in active_paths:
		if not graph.has_node(path):
			continue
		var node: AssetNode = graph.get_node(path)
		var nid: String = "node_%d" % id_counter
		id_counter += 1
		node_ids[path] = nid
		var clean_name: String = _sanitize_mermaid(path.get_file())
		var cat_name: String = AssetNode.category_to_string(node.type)
		var style_class: String = _get_mermaid_style_class(node.type)
		lines.append('    %s["%s <br/> <i>[%s]</i>"]:::%s' % [nid, clean_name, cat_name, style_class])

	lines.append("")
	var rendered_edges: Dictionary = {}
	for edge in graph.edges:
		if node_ids.has(edge.from_path) and node_ids.has(edge.to_path):
			var from_id: String = node_ids[edge.from_path]
			var to_id: String = node_ids[edge.to_path]
			var edge_key: String = from_id + "->" + to_id
			if not rendered_edges.has(edge_key):
				rendered_edges[edge_key] = true
				lines.append("    %s --> %s" % [from_id, to_id])

	return "\n".join(lines)

static func export_to_mermaid_uml(graph: DependencyGraph) -> String:
	if not graph or graph.nodes.is_empty():
		return "classDiagram\n    class Empty {\n        <<None>>\n        No Assets Scanned\n    }\n"
	return export_subgraph_to_mermaid_uml(graph, graph.nodes.keys())

static func export_subgraph_to_mermaid_uml(graph: DependencyGraph, active_paths: Array) -> String:
	if not graph or active_paths.is_empty():
		return "classDiagram\n    class Empty {\n        <<None>>\n        No Visible Assets\n    }\n"

	var lines: Array[String] = [
		"classDiagram",
		"    %% UML Class Diagram of Asset Dependencies"
	]
	var node_ids: Dictionary = {}
	var id_counter: int = 0

	for path in active_paths:
		if not graph.has_node(path):
			continue
		var node: AssetNode = graph.get_node(path)
		var cid: String = "Asset_%d" % id_counter
		id_counter += 1
		node_ids[path] = cid
		var cat: String = AssetNode.category_to_string(node.type)
		var clean_name: String = _sanitize_mermaid(path.get_file())
		lines.append('    class %s["%s"] {' % [cid, clean_name])
		lines.append('        <<%s>>' % cat)
		lines.append('        %s' % _format_bytes(node.size_bytes))
		lines.append('    }')

	lines.append("")
	var rendered_edges: Dictionary = {}
	for edge in graph.edges:
		if node_ids.has(edge.from_path) and node_ids.has(edge.to_path):
			var from_id: String = node_ids[edge.from_path]
			var to_id: String = node_ids[edge.to_path]
			var edge_key: String = from_id + "->" + to_id
			if not rendered_edges.has(edge_key):
				rendered_edges[edge_key] = true
				lines.append("    %s --> %s : depends_on" % [from_id, to_id])

	return "\n".join(lines)

static func export_to_dot(graph: DependencyGraph) -> String:
	if not graph or graph.nodes.is_empty():
		return "digraph AssetDependencies {\n    empty [label=\"No Assets Scanned\"];\n}"

	var lines: Array[String] = [
		"digraph AssetDependencies {",
		"    rankdir=LR;",
		'    node [shape=box, style="rounded,filled", fillcolor="#f0f4f8", fontname="Helvetica", fontsize=10];',
		'    edge [color="#666666", arrowhead=vee];'
	]

	var node_ids: Dictionary = {}
	var id_counter: int = 0

	for path in graph.nodes.keys():
		var node: AssetNode = graph.nodes[path]
		var nid: String = "node_%d" % id_counter
		id_counter += 1
		node_ids[path] = nid
		var clean_label: String = "%s\\n[%s]" % [_sanitize_dot(path.get_file()), AssetNode.category_to_string(node.type)]
		lines.append('    %s [label="%s"];' % [nid, clean_label])

	var rendered_edges: Dictionary = {}
	for edge in graph.edges:
		var from_id: String = node_ids.get(edge.from_path, "")
		var to_id: String = node_ids.get(edge.to_path, "")
		if not from_id.is_empty() and not to_id.is_empty():
			var edge_key: String = from_id + "->" + to_id
			if not rendered_edges.has(edge_key):
				rendered_edges[edge_key] = true
				lines.append("    %s -> %s;" % [from_id, to_id])

	lines.append("}")
	return "\n".join(lines)

static func _sanitize_mermaid(text: String) -> String:
	return text.replace("\\", "/") \
		.replace('"', "'") \
		.replace("<", "&lt;") \
		.replace(">", "&gt;") \
		.replace("[", "(") \
		.replace("]", ")")

static func _sanitize_dot(text: String) -> String:
	return text.replace("\\", "\\\\") \
		.replace('"', '\\"') \
		.replace("\n", " ")

static func _get_mermaid_style_class(cat: int) -> String:
	match cat:
		AssetNode.Category.SCENE: return "sceneClass"
		AssetNode.Category.SCRIPT: return "scriptClass"
		AssetNode.Category.TEXTURE: return "textureClass"
		AssetNode.Category.AUDIO: return "audioClass"
		AssetNode.Category.RESOURCE: return "resourceClass"
		AssetNode.Category.SHADER: return "shaderClass"
		AssetNode.Category.MATERIAL: return "materialClass"
		_: return "otherClass"

static func _format_bytes(bytes: int) -> String:
	if bytes >= 1048576:
		return "%.1f MB" % (float(bytes) / 1048576.0)
	elif bytes >= 1024:
		return "%.1f KB" % (float(bytes) / 1024.0)
	else:
		return "%d B" % bytes

