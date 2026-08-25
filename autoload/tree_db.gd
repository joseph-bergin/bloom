extends Node
## Loads and validates tree JSON at startup, provides lookup.

const TREE_DIR := "res://data/tree/"

var nodes: Dictionary = {}                 # StringName -> TreeNode
var by_constellation: Dictionary = {}      # StringName -> Array[TreeNode]
var children: Dictionary = {}              # StringName -> Array[StringName]
var constellations: Array[StringName] = []
var validation: TreeValidator.Report = null

func _ready() -> void:
	load_all()

func load_all() -> void:
	nodes.clear()
	by_constellation.clear()
	children.clear()
	constellations.clear()

	var dir := DirAccess.open(TREE_DIR)
	if dir == null:
		push_error("TreeDB: cannot open %s" % TREE_DIR)
		return
	var files: PackedStringArray = []
	for f in dir.get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()

	for f in files:
		_load_file(TREE_DIR + f)

	_index()

	validation = TreeValidator.validate(nodes)
	if not validation.ok():
		push_error("TreeDB validation failed:\n" + validation.to_text())
	elif not validation.warnings.is_empty() and OS.is_debug_build():
		print(validation.to_text())
	print("TreeDB: %d nodes across %d constellations" % [nodes.size(), constellations.size()])

func _load_file(path: String) -> void:
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		push_error("TreeDB: empty or unreadable %s" % path)
		return
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		push_error("TreeDB: JSON parse error in %s" % path)
		return
	var list: Array = []
	if typeof(parsed) == TYPE_ARRAY:
		list = parsed
	elif typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("nodes"):
		list = (parsed as Dictionary)["nodes"]
	else:
		push_error("TreeDB: %s must be an array or {nodes:[...]}" % path)
		return
	for entry in list:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var n := TreeNode.from_dict(entry)
		if nodes.has(n.id):
			push_error("TreeDB: duplicate node id '%s' in %s" % [n.id, path])
			continue
		nodes[n.id] = n

func _index() -> void:
	for key in nodes.keys():
		var n: TreeNode = nodes[key]
		if not by_constellation.has(n.constellation):
			by_constellation[n.constellation] = []
			constellations.append(n.constellation)
		(by_constellation[n.constellation] as Array).append(n)
		for r in n.requires:
			if not children.has(r):
				children[r] = [] as Array[StringName]
			(children[r] as Array).append(n.id)
	constellations.sort()

func get_node_def(id: StringName) -> TreeNode:
	return nodes.get(id)

func has_node_def(id: StringName) -> bool:
	return nodes.has(id)

func children_of(id: StringName) -> Array:
	return children.get(id, [])

func all_ids() -> Array:
	return nodes.keys()

func constellation_nodes(con: StringName) -> Array:
	return by_constellation.get(con, [])

## Nodes in regions the player has unlocked (base is always unlocked).
func available_nodes(unlocked: PackedStringArray) -> Array:
	var out: Array = []
	for key in nodes.keys():
		var n: TreeNode = nodes[key]
		if n.region == &"base" or String(n.region) in unlocked:
			out.append(n)
	return out
