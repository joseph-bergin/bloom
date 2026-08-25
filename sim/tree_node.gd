class_name TreeNode
extends RefCounted

var id: StringName
var branch: StringName
var display_name: String
var desc: String
var max_rank: int = 1          # -1 for infinite sinks
var cost: float = 0.0
var cost_growth: float = 1.15
var lum: float = 0.0           # luminance PER RANK
var requires: Array[StringName] = []
var effects: Array = []
var pos: Vector2 = Vector2.ZERO
var keystone: bool = false

static func from_dict(d: Dictionary) -> TreeNode:
	var n := TreeNode.new()
	n.id = StringName(str(d.get("id", "")))
	n.branch = StringName(str(d.get("branch", "")))
	n.display_name = str(d.get("name", str(n.id)))
	n.desc = str(d.get("desc", ""))
	n.max_rank = int(d.get("max_rank", 1))
	n.cost = float(d.get("cost", 0.0))
	n.cost_growth = float(d.get("cost_growth", 1.15))
	n.lum = float(d.get("lum", 0.0))
	for r in (d.get("requires", []) as Array):
		n.requires.append(StringName(str(r)))
	n.effects = d.get("effects", [])
	var p: Dictionary = d.get("pos", {})
	n.pos = Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
	n.keystone = bool(d.get("keystone", false))
	return n

func is_infinite() -> bool:
	return max_rank < 0

## cost * pow(cost_growth, rank). Nothing else.
func cost_at(rank: int) -> float:
	return cost * pow(cost_growth, float(rank))

func lum_at(rank: int) -> float:
	return lum * float(rank)
