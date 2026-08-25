class_name SweepRing
extends RefCounted

var radius: float = 0.0
var max_radius: float = 0.0
var fired_at: float = 0.0

func _init(p_max: float = 0.0, p_t: float = 0.0) -> void:
	max_radius = p_max
	fired_at = p_t
