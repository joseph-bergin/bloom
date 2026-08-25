extends RefCounted
## See tools/tree_generator.gd for usage.

const TREE_DIR := "res://data/tree/"

## Per-constellation bulk retune. Multipliers applied to every node in the
## constellation; a balance pass is a single-file edit here, which is the
## whole point of keeping tuning out of the system files.
const RETUNE := {
	"expansion":  {"motes": 1.0, "lum": 1.0},
	"shroud":     {"motes": 1.0, "lum": 1.0},
	"optics":     {"motes": 1.0, "lum": 1.0},
	"sweep":      {"motes": 1.0, "lum": 1.0},
	"lance":      {"motes": 1.0, "lum": 1.0},
	"tether":     {"motes": 1.0, "lum": 1.0},
	"redundancy": {"motes": 1.0, "lum": 1.0},
	"cognition":  {"motes": 1.0, "lum": 1.0},
}

func run(args: Dictionary) -> int:
	if TreeDB.nodes.is_empty():
		TreeDB.load_all()

	if args.has("validate"):
		var rep: TreeValidator.Report = TreeValidator.validate(TreeDB.nodes)
		print(rep.to_text())
		return 0 if rep.ok() else 1

	if args.has("retune"):
		return _retune(args.has("write"))

	_report()
	return 0

# --- statistics ----------------------------------------------------------

func _report() -> void:
	print("%-12s %5s %6s %8s %10s %10s %6s %6s" %
		["constellation", "nodes", "keys", "sinks", "motes@r0", "lum/node", "gates", "leaves"])
	var totals := {"nodes": 0, "gates": 0, "leaves": 0}
	for con in TreeDB.constellations:
		var list: Array = TreeDB.constellation_nodes(con)
		var keys: int = 0
		var sinks: int = 0
		var motes: float = 0.0
		var lum: float = 0.0
		var gates: int = 0
		for n in list:
			if n.kind == TreeNode.Kind.KEYSTONE:
				keys += 1
			if n.is_infinite():
				sinks += 1
			motes += n.cost_motes
			lum += n.lum
			if not TreeDB.children_of(n.id).is_empty():
				gates += 1
		var leaves: int = list.size() - gates
		totals["nodes"] += list.size()
		totals["gates"] += gates
		totals["leaves"] += leaves
		print("%-12s %5d %6d %8d %10s %10.2f %6d %6d" %
			[String(con), list.size(), keys, sinks,
			UITheme.fmt(motes / maxf(float(list.size()), 1.0)),
			lum / maxf(float(list.size()), 1.0), gates, leaves])
	print("\n%d nodes, %d gateways (never blightable), %d blightable leaves" %
		[totals["nodes"], totals["gates"], totals["leaves"]])

	# Luminance budget: what the tree costs you if you build all of it.
	var total_lum: float = 0.0
	var total_shroud: float = 0.0
	for id in TreeDB.all_ids():
		var n: TreeNode = TreeDB.get_node_def(id)
		var ranks: int = n.max_rank if n.max_rank > 0 else 10
		total_lum += n.lum * float(ranks)
		for e in n.effects:
			if typeof(e) == TYPE_DICTIONARY and str(e.get("stat", "")) == "shroud":
				total_shroud += float(e.get("value", 0.0)) * float(ranks)
	print("full build: %.0f structural luminance, %.0f%% raw shroud (capped at %d%%)" %
		[total_lum, total_shroud * 100.0, int(Constants.SHROUD_CAP * 100.0)])

# --- bulk retune ---------------------------------------------------------

func _retune(write: bool) -> int:
	var dir := DirAccess.open(TREE_DIR)
	if dir == null:
		push_error("cannot open %s" % TREE_DIR)
		return 1
	var changed: int = 0
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var path: String = TREE_DIR + f
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_ARRAY:
			continue
		var list: Array = parsed
		var touched: bool = false
		for entry in list:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var e: Dictionary = entry
			var con: String = str(e.get("constellation", ""))
			if not RETUNE.has(con):
				continue
			var rule: Dictionary = RETUNE[con]
			var m: float = float(rule.get("motes", 1.0))
			var l: float = float(rule.get("lum", 1.0))
			if is_equal_approx(m, 1.0) and is_equal_approx(l, 1.0):
				continue
			var cost: Dictionary = e.get("cost", {})
			if cost.has("motes"):
				cost["motes"] = round(float(cost["motes"]) * m)
				e["cost"] = cost
			if e.has("lum"):
				e["lum"] = snappedf(float(e["lum"]) * l, 0.01)
			touched = true
			changed += 1
		if touched and write:
			var out := FileAccess.open(path, FileAccess.WRITE)
			out.store_string(JSON.stringify(list, " "))
			out.close()
	print("%d nodes retuned%s" % [changed, "" if write else " (dry run — pass --write)"])
	if write:
		TreeDB.load_all()
		var rep: TreeValidator.Report = TreeValidator.validate(TreeDB.nodes)
		print(rep.to_text())
		return 0 if rep.ok() else 1
	return 0
