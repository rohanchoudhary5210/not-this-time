@tool
class_name DependencyGraph
extends RefCounted

## Represents a directed graph G = (V, E) where V are AssetNodes and E are DependencyEdges.
## Directed edge A -> B means "Asset A depends on Asset B".

var nodes: Dictionary = {} # String (path) -> AssetNode
var edges: Array[DependencyEdge] = [] # List of DependencyEdge

func clear() -> void:
	nodes.clear()
	edges.clear()

func add_node(node: AssetNode) -> void:
	nodes[node.path] = node

func get_node(path: String) -> AssetNode:
	return nodes.get(path, null)

func has_node(path: String) -> bool:
	return nodes.has(path)

func add_edge(from_path: String, to_path: String, relation: DependencyEdge.RelationType = DependencyEdge.RelationType.HARD_REFERENCE) -> void:
	if from_path == to_path or not nodes.has(from_path) or not nodes.has(to_path):
		return

	var source: AssetNode = nodes[from_path]
	var target: AssetNode = nodes[to_path]

	source.add_dependency(to_path)
	target.add_dependent(from_path)

	var edge: DependencyEdge = DependencyEdge.new(from_path, to_path, relation)
	edges.append(edge)

func remove_outgoing_edges(from_path: String) -> void:
	if not nodes.has(from_path):
		return
	var source: AssetNode = nodes[from_path]
	for to_path in source.dependencies:
		if nodes.has(to_path):
			nodes[to_path].remove_dependent(from_path)
	source.dependencies.clear()

	var new_edges: Array[DependencyEdge] = []
	for edge in edges:
		if edge.from_path != from_path:
			new_edges.append(edge)
	edges = new_edges

func get_node_count() -> int:
	return nodes.size()

func get_edge_count() -> int:
	return edges.size()

# ==============================================================================
# GRAPH ALGORITHMS
# ==============================================================================

## DFS: Returns all transitive dependencies (all assets A depends on directly or indirectly)
## Time Complexity: O(V + E), Space Complexity: O(V)
func get_transitive_dependencies(start_path: String) -> Array[String]:
	var result: Array[String] = []
	var visited: Dictionary = {}
	_dfs_dependencies(start_path, visited, result)
	return result

func _dfs_dependencies(current_path: String, visited: Dictionary, result: Array[String]) -> void:
	var node: AssetNode = nodes.get(current_path, null)
	if not node:
		return

	visited[current_path] = true

	for dep_path in node.dependencies:
		if not visited.has(dep_path):
			result.append(dep_path)
			_dfs_dependencies(dep_path, visited, result)

## DFS Reverse: Returns all transitive dependents (all assets that depend on A directly or indirectly)
## Crucial for "What breaks if I delete this asset?"
## Time Complexity: O(V + E), Space Complexity: O(V)
func get_transitive_dependents(target_path: String) -> Array[String]:
	var result: Array[String] = []
	var visited: Dictionary = {}
	_dfs_dependents(target_path, visited, result)
	return result

func _dfs_dependents(current_path: String, visited: Dictionary, result: Array[String]) -> void:
	var node: AssetNode = nodes.get(current_path, null)
	if not node:
		return

	visited[current_path] = true

	for dependent_path in node.dependents:
		if not visited.has(dependent_path):
			result.append(dependent_path)
			_dfs_dependents(dependent_path, visited, result)

## BFS: Calculates shortest path from start_path to target_path
## Time Complexity: O(V + E), Space Complexity: O(V)
func find_shortest_path(start_path: String, target_path: String) -> Array[String]:
	if start_path == target_path or not nodes.has(start_path) or not nodes.has(target_path):
		return []

	var queue: Array[String] = [start_path]
	var parent_map: Dictionary = {start_path: ""}
	var visited: Dictionary = {start_path: true}

	var found: bool = false
	while queue.size() > 0:
		var current: String = queue.pop_front()
		if current == target_path:
			found = true
			break

		var curr_node: AssetNode = nodes[current]
		for dep in curr_node.dependencies:
			if not visited.has(dep):
				visited[dep] = true
				parent_map[dep] = current
				queue.append(dep)

	if not found:
		return []

	# Reconstruct path
	var path: Array[String] = []
	var curr: String = target_path
	while curr != "":
		path.push_front(curr)
		curr = parent_map.get(curr, "")

	return path

## Tarjan's Strongly Connected Components Algorithm for Circular Dependency Detection
## Time Complexity: O(V + E), Space Complexity: O(V)
func detect_circular_dependencies() -> Array[Array]:
	var index: int = 0
	var stack: Array[String] = []
	var indices: Dictionary = {}
	var lowlink: Dictionary = {}
	var on_stack: Dictionary = {}
	var cycles: Array[Array] = []

	for node_path in nodes.keys():
		if not indices.has(node_path):
			_tarjan_scc(node_path, index, stack, indices, lowlink, on_stack, cycles)

	# Filter and order cycles (only components with size > 1 or self-loops)
	var valid_cycles: Array[Array] = []
	for scc in cycles:
		if scc.size() > 1:
			valid_cycles.append(order_cycle(scc))
		elif scc.size() == 1:
			var single: String = scc[0]
			var node: AssetNode = nodes[single]
			if node.dependencies.has(single):
				valid_cycles.append(scc)

	return valid_cycles

## Orders nodes in a cycle along directed dependency edges (e.g. A -> B -> C -> A)
func order_cycle(scc: Array) -> Array:
	if scc.size() <= 1:
		return scc
	var ordered: Array = []
	var visited: Dictionary = {}
	var current: String = str(scc[0])
	ordered.append(current)
	visited[current] = true

	while ordered.size() < scc.size():
		var node: AssetNode = nodes.get(current, null)
		var next_node: String = ""
		if node:
			for dep in node.dependencies:
				if scc.has(dep) and not visited.has(dep):
					next_node = dep
					break
		if next_node.is_empty():
			for item in scc:
				var p: String = str(item)
				if not visited.has(p):
					next_node = p
					break
		if next_node.is_empty():
			break
		visited[next_node] = true
		ordered.append(next_node)
		current = next_node

	return ordered

## Finds the circular dependency loop containing the specified asset, if any
func find_cycle_for_asset(path: String) -> Array:
	var all_cycles: Array[Array] = detect_circular_dependencies()
	for c in all_cycles:
		if c.has(path):
			return c
	return []

func _tarjan_scc(u: String, index: int, stack: Array[String], indices: Dictionary, lowlink: Dictionary, on_stack: Dictionary, cycles: Array[Array]) -> void:
	indices[u] = index
	lowlink[u] = index
	index += 1
	stack.append(u)
	on_stack[u] = true

	var u_node: AssetNode = nodes.get(u, null)
	if u_node:
		for v in u_node.dependencies:
			if not indices.has(v):
				_tarjan_scc(v, index, stack, indices, lowlink, on_stack, cycles)
				lowlink[u] = mini(lowlink[u], lowlink[v])
			elif on_stack.get(v, false):
				lowlink[u] = mini(lowlink[u], indices[v])

	if lowlink[u] == indices[u]:
		var scc: Array = []
		while true:
			var w: String = stack.pop_back()
			on_stack[w] = false
			scc.append(w)
			if w == u:
				break
		cycles.append(scc)

## Calculates total size of an asset and all its transitive dependencies
func get_transitive_size_bytes(start_path: String) -> int:
	var trans_deps: Array[String] = get_transitive_dependencies(start_path)
	var total: int = 0
	var start_node: AssetNode = nodes.get(start_path, null)
	if start_node:
		total += start_node.size_bytes

	for dep in trans_deps:
		var dep_node: AssetNode = nodes.get(dep, null)
		if dep_node:
			total += dep_node.size_bytes
	return total

## Finds the deepest dependency tree depth starting from a node
func get_max_dependency_depth(start_path: String, visited: Dictionary = {}, memo: Dictionary = {}) -> int:
	if memo.has(start_path):
		return memo[start_path]

	var node: AssetNode = nodes.get(start_path, null)
	if not node or node.dependencies.is_empty():
		return 0

	var max_depth: int = 0
	visited[start_path] = true

	for dep in node.dependencies:
		if not visited.has(dep):
			var depth: int = 1 + get_max_dependency_depth(dep, visited.duplicate(), memo)
			max_depth = maxi(max_depth, depth)

	memo[start_path] = max_depth
	return max_depth

## Finds the single asset with the heaviest cumulative transitive size (self + all dependencies)
func find_heaviest_dependency_chain() -> Dictionary:
	var heaviest_path: String = ""
	var max_cumulative_bytes: int = -1
	var last_yield: int = Time.get_ticks_msec()

	for path in nodes.keys():
		var trans_bytes: int = get_transitive_size_bytes(path)
		if trans_bytes > max_cumulative_bytes:
			max_cumulative_bytes = trans_bytes
			heaviest_path = path

		if Time.get_ticks_msec() - last_yield > 16:
			await Engine.get_main_loop().process_frame
			last_yield = Time.get_ticks_msec()

	if heaviest_path.is_empty():
		return {}

	return {
		"root_path": heaviest_path,
		"total_transitive_bytes": max_cumulative_bytes,
		"transitive_chain": get_transitive_dependencies(heaviest_path)
	}
