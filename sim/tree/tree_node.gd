class_name TreeNode
extends RefCounted

enum Kind { RANK, KEYSTONE, BRIDGE, SINK }

var id: StringName
var constellation: StringName
var display_name: String
var desc: String
var kind: Kind = Kind.RANK
var max_rank: int = 1          # -1 for infinite sinks
var cost_motes: float = 0.0
var cost_signal: float = 0.0
var cost_facets: float = 0.0
var cost_growth: float = 1.15
var lum: float = 0.0           # structural luminance PER RANK
var requires: Array[StringName] = []
var effects: Array = []        # Dictionary entries
var pos: Vector2 = Vector2.ZERO
var blight_safe: bool = false
var reveal_radius: float = 180.0
var region: StringName = &"base"   # base, or an ember-only region id

static func from_dict(d: Dictionary) -> TreeNode:
	var n := TreeNode.new()
	n.id = StringName(str(d.get("id", "")))
	n.constellation = StringName(str(d.get("constellation", "")))
	n.display_name = str(d.get("name", str(n.id)))
	n.desc = str(d.get("desc", ""))
	match str(d.get("kind", "rank")):
		"keystone": n.kind = Kind.KEYSTONE
		"bridge": n.kind = Kind.BRIDGE
		"sink": n.kind = Kind.SINK
		_: n.kind = Kind.RANK
	n.max_rank = int(d.get("max_rank", 1))
	var cost: Dictionary = d.get("cost", {})
	n.cost_motes = float(cost.get("motes", 0.0))
	n.cost_signal = float(cost.get("signal", 0.0))
	n.cost_facets = float(cost.get("facets", 0.0))
	n.cost_growth = float(d.get("cost_growth", Constants.COST_GROWTH_RANK))
	n.lum = float(d.get("lum", 0.0))
	var req: Array = d.get("requires", [])
	for r in req:
		n.requires.append(StringName(str(r)))
	n.effects = d.get("effects", [])
	var p: Dictionary = d.get("pos", {})
	n.pos = Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
	n.blight_safe = bool(d.get("blight_safe", false))
	n.reveal_radius = float(d.get("reveal_radius", 180.0))
	n.region = StringName(str(d.get("region", "base")))
	return n

func is_infinite() -> bool:
	return max_rank < 0

## Cost of buying the (rank+1)-th rank, given current rank.
func cost_at(rank: int) -> Dictionary:
	var mult: float = pow(cost_growth, float(rank))
	return {
		"motes": cost_motes * mult,
		"signal": cost_signal * mult,
		"facets": cost_facets * (1.0 if kind == Kind.KEYSTONE else mult),
	}

func lum_at(rank: int) -> float:
	return lum * float(rank)
