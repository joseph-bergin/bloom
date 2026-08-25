class_name TreeValidator
extends RefCounted
## Runs at startup in debug builds and in CI. Asserts structural integrity
## of the whole tree: no orphans, no unreachable nodes, no cycles,
## >=1 keystone per constellation, gateways blight_safe, unique ids,
## every `requires` target exists.

class Report extends RefCounted:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var gateways: Array[StringName] = []
	func ok() -> bool:
		return errors.is_empty()
	func to_text() -> String:
		var parts: PackedStringArray = []
		for e in errors:
			parts.append("ERROR: " + e)
		for w in warnings:
			parts.append("WARN:  " + w)
		if parts.is_empty():
			return "tree validation: OK"
		return "\n".join(parts)

static func validate(nodes: Dictionary) -> Report:
	var rep := Report.new()

	# --- unique ids are guaranteed by the Dictionary; check for empties ---
	for key in nodes.keys():
		var n: TreeNode = nodes[key]
		if String(n.id).is_empty():
			rep.errors.append("node with empty id")
		if n.constellation == &"":
			rep.errors.append("node '%s' has no constellation" % n.id)
		if n.kind == TreeNode.Kind.RANK and n.max_rank == 0:
			rep.errors.append("node '%s' is rank-kind with max_rank 0" % n.id)

	# --- requires targets exist, and no self-reference ---
	for key in nodes.keys():
		var n: TreeNode = nodes[key]
		for r in n.requires:
			if r == n.id:
				rep.errors.append("node '%s' requires itself" % n.id)
			elif not nodes.has(r):
				rep.errors.append("node '%s' requires missing node '%s'" % [n.id, r])

	# --- cycle detection (DFS with colours) ---
	var colour: Dictionary = {}
	for key in nodes.keys():
		if not colour.has(key):
			var cyc := _visit(key, nodes, colour)
			if cyc != "":
				rep.errors.append("circular requirement involving '%s'" % cyc)

	# --- reachability from roots (nodes with no requires) ---
	var roots: Array[StringName] = []
	for key in nodes.keys():
		var n: TreeNode = nodes[key]
		if n.requires.is_empty():
			roots.append(n.id)
	if roots.is_empty() and not nodes.is_empty():
		rep.errors.append("tree has no root node (every node has requirements)")

	var children: Dictionary = {}
	for key in nodes.keys():
		var n: TreeNode = nodes[key]
		for r in n.requires:
			if not children.has(r):
				children[r] = [] as Array[StringName]
			(children[r] as Array).append(n.id)

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
			rep.errors.append("node '%s' is unreachable from any root" % key)

	# --- every constellation has at least one keystone ---
	var by_con: Dictionary = {}
	var keystone_con: Dictionary = {}
	for key in nodes.keys():
		var n: TreeNode = nodes[key]
		by_con[n.constellation] = true
		if n.kind == TreeNode.Kind.KEYSTONE:
			keystone_con[n.constellation] = true
	for con in by_con.keys():
		if not keystone_con.has(con):
			rep.errors.append("constellation '%s' has no keystone" % con)

	# --- gateway nodes must be blight_safe -------------------------------
	# A gateway is any node that something else requires. Blighting one
	# would lock its whole downstream subtree: a soft-lock.
	for key in nodes.keys():
		if children.has(key):
			var n: TreeNode = nodes[key]
			rep.gateways.append(n.id)
			if not n.blight_safe:
				rep.errors.append(
					"gateway node '%s' has %d dependents but blight_safe is false" %
					[n.id, (children[key] as Array).size()])

	# --- soft warnings ----------------------------------------------------
	for key in nodes.keys():
		var n: TreeNode = nodes[key]
		var c: Dictionary = n.cost_at(0)
		if float(c["motes"]) <= 0.0 and float(c["signal"]) <= 0.0 and float(c["facets"]) <= 0.0:
			rep.warnings.append("node '%s' is free" % n.id)
		if n.kind == TreeNode.Kind.KEYSTONE and n.effects.is_empty():
			rep.warnings.append("keystone '%s' has no effects" % n.id)

	return rep

static func _visit(id: StringName, nodes: Dictionary, colour: Dictionary) -> String:
	colour[id] = 1  # grey
	var n: TreeNode = nodes.get(id)
	if n != null:
		for r in n.requires:
			if not nodes.has(r):
				continue
			var c: int = int(colour.get(r, 0))
			if c == 1:
				return String(r)
			if c == 0:
				var res := _visit(r, nodes, colour)
				if res != "":
					return res
	colour[id] = 2  # black
	return ""
