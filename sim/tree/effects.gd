class_name TreeEffects
extends RefCounted
## Applies a node's effect dictionaries onto a stat accumulator.
## Numeric ops land in `acc`; "rule" ops land in `rules` as string keys
## checked by the relevant system, e.g. Stats.has_rule(&"nullwake").

const OP_ADD := "add"
const OP_MUL := "mul"
const OP_MAX := "max"
const OP_RULE := "rule"

static func apply(effects: Array, rank: int, acc: Dictionary, rules: Dictionary) -> void:
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var eff: Dictionary = e
		var op: String = str(eff.get("op", OP_ADD))
		if op == OP_RULE:
			rules[StringName(str(eff.get("rule", eff.get("stat", ""))))] = true
			continue
		var stat: String = str(eff.get("stat", ""))
		if stat == "":
			continue
		var value: float = float(eff.get("value", 0.0))
		match op:
			OP_MUL:
				# Multiplicative stats accumulate as (1 + v)^rank on a base of 1.
				var base: float = float(acc.get(stat, 1.0))
				acc[stat] = base * pow(1.0 + value, float(rank))
			OP_MAX:
				acc[stat] = maxf(float(acc.get(stat, 0.0)), value)
			_:
				acc[stat] = float(acc.get(stat, 0.0)) + value * float(rank)
