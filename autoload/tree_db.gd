extends Node
## Loads and validates tree JSON at startup.

const TREE_DIR := "res://data/tree/"

var nodes: Dictionary = {}            # StringName -> TreeNode
var by_branch: Dictionary = {}        # StringName -> Array[TreeNode]
var children: Dictionary = {}         # StringName -> Array[StringName]
var branches: Array[StringName] = []
var errors: PackedStringArray = []

func _ready() -> void:
	load_all()

func load_all() -> void:
	nodes.clear()
	by_branch.clear()
	children.clear()
	branches.clear()

	var dir := DirAccess.open(TREE_DIR)
	if dir == null:
		push_error("TreeDB: cannot open %s" % TREE_DIR)
		return
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".json"):
			_load_file(TREE_DIR + f)

	for key in nodes.keys():
		var n: TreeNode = nodes[key]
		if not by_branch.has(n.branch):
			by_branch[n.branch] = []
			branches.append(n.branch)
		(by_branch[n.branch] as Array).append(n)
		for r in n.requires:
			if not children.has(r):
				children[r] = [] as Array[StringName]
			(children[r] as Array).append(n.id)

	errors = validate()
	if not errors.is_empty():
		push_error("TreeDB validation failed:\n" + "\n".join(errors))
	print("TreeDB: %d nodes across %d branches" % [nodes.size(), branches.size()])

func _load_file(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("TreeDB: %s must be a JSON array" % path)
		return
	for entry in (parsed as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var n := TreeNode.from_dict(entry)
		if nodes.has(n.id):
			push_error("TreeDB: duplicate id '%s'" % n.id)
			continue
		nodes[n.id] = n

## No missing requirements, no cycles, no unreachable nodes, one keystone
## per branch, every id unique.
func validate() -> PackedStringArray:
	var out: PackedStringArray = []
	for key in nodes.keys():
		var n: TreeNode = nodes[key]
		if n.branch == &"":
			out.append("node '%s' has no branch" % n.id)
		for r in n.requires:
			if r == n.id:
				out.append("node '%s' requires itself" % n.id)
			elif not nodes.has(r):
				out.append("node '%s' requires missing '%s'" % [n.id, r])

	var colour: Dictionary = {}
	for key in nodes.keys():
		if not colour.has(key):
			var cyc := _visit(key, colour)
			if cyc != "":
				out.append("circular requirement at '%s'" % cyc)

	var roots: Array[StringName] = []
	for key in nodes.keys():
		if (nodes[key] as TreeNode).requires.is_empty():
			roots.append(key)
	if roots.is_empty() and not nodes.is_empty():
		out.append("tree has no root")
	var seen: Dictionary = {}
	var stack: Array[StringName] = roots.duplicate()
	while not stack.is_empty():
		var cur: StringName = stack.pop_back()
		if seen.has(cur):
			continue
		seen[cur] = true
		for ch in (children.get(cur, []) as Array):
			stack.append(ch)
	for key in nodes.keys():
		if not seen.has(key):
			out.append("node '%s' is unreachable" % key)

	var keystones: Dictionary = {}
	for key in nodes.keys():
		var n2: TreeNode = nodes[key]
		if n2.keystone:
			keystones[n2.branch] = true
	for b in by_branch.keys():
		if not keystones.has(b):
			out.append("branch '%s' has no keystone" % b)
	return out

func _visit(id: StringName, colour: Dictionary) -> String:
	colour[id] = 1
	var n: TreeNode = nodes.get(id)
	if n != null:
		for r in n.requires:
			if not nodes.has(r):
				continue
			var c: int = int(colour.get(r, 0))
			if c == 1:
				return String(r)
			if c == 0:
				var res := _visit(r, colour)
				if res != "":
					return res
	colour[id] = 2
	return ""

func get_node_def(id: StringName) -> TreeNode:
	return nodes.get(id)

func has_node_def(id: StringName) -> bool:
	return nodes.has(id)

func all_ids() -> Array:
	return nodes.keys()

func branch_nodes(b: StringName) -> Array:
	return by_branch.get(b, [])

func children_of(id: StringName) -> Array:
	return children.get(id, [])
