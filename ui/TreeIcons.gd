class_name TreeIcons
extends RefCounted
## A glyph per kind of upgrade, drawn with primitives. Derived from what the
## node actually does, so a node's picture and its effect can never drift
## apart the way a hand-assigned icon field would.

enum Kind {
	DAMAGE, RATE, CRIT, PROJECTILES,      # burn
	SHROUD, BREATH,                        # shroud
	RANGE, PIERCE, CHAIN, AIM,             # reach
	SHIELD, MOTES,                         # root
	KEYSTONE, GENERIC,
}

const STAT_KIND := {
	"damage_mult": Kind.DAMAGE,
	"fire_rate_mult": Kind.RATE,
	"crit_chance": Kind.CRIT,
	"crit_mult": Kind.CRIT,
	"projectiles": Kind.PROJECTILES,
	"shroud": Kind.SHROUD,
	"douse_efficiency": Kind.BREATH,
	"douse_refill": Kind.BREATH,
	"range_mult": Kind.RANGE,
	"pierce": Kind.PIERCE,
	"chain": Kind.CHAIN,
	"aim_assist": Kind.AIM,
	"shields": Kind.SHIELD,
	"mote_mult": Kind.MOTES,
	"mote_add": Kind.MOTES,
}

static func kind_for(n: TreeNode) -> Kind:
	if n.keystone:
		return Kind.KEYSTONE
	for e in n.effects:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var stat: String = str((e as Dictionary).get("stat", ""))
		if STAT_KIND.has(stat):
			return STAT_KIND[stat]
	return Kind.GENERIC

## Draws into `ci` centred on `c`, fitting a box of `r` half-extent.
static func draw_icon(ci: CanvasItem, kind: Kind, c: Vector2, r: float, col: Color) -> void:
	var w: float = maxf(r * 0.24, 1.4)
	match kind:
		Kind.DAMAGE:
			# A spike driven downward.
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, r), c + Vector2(-r * 0.55, -r * 0.35),
				c + Vector2(0, -r * 0.05), c + Vector2(r * 0.55, -r * 0.35)]), col)
		Kind.RATE:
			# Two chevrons: more of the same, faster.
			for k in range(2):
				var y: float = -r * 0.55 + float(k) * r * 0.75
				ci.draw_polyline(PackedVector2Array([
					c + Vector2(-r * 0.6, y), c + Vector2(0, y + r * 0.5),
					c + Vector2(r * 0.6, y)]), col, w, true)
		Kind.CRIT:
			# A burst.
			for k in range(8):
				var a: float = TAU * float(k) / 8.0
				var d := Vector2(cos(a), sin(a))
				var inner: float = r * (0.22 if k % 2 == 0 else 0.36)
				var outer: float = r * (1.0 if k % 2 == 0 else 0.6)
				ci.draw_line(c + d * inner, c + d * outer, col, w, true)
		Kind.PROJECTILES:
			# Three shots fanning out.
			for k in range(3):
				var a: float = -PI * 0.5 + (float(k) - 1.0) * 0.42
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c - d * r * 0.5, c + d * r * 0.9, col, w, true)
				ci.draw_circle(c + d * r * 0.9, w * 0.9, col)
		Kind.SHROUD:
			# An eclipse: the light still there, mostly covered.
			ci.draw_arc(c, r * 0.78, 0.0, TAU, 26, col, w, true)
			ci.draw_circle(c + Vector2(r * 0.34, -r * 0.16), r * 0.72,
				Color(0.045, 0.055, 0.072))
		Kind.BREATH:
			# A held breath: a bar being drawn down.
			ci.draw_arc(c, r * 0.8, PI * 0.75, PI * 2.25, 22, col, w, true)
			ci.draw_line(c + Vector2(0, r * 0.1), c + Vector2(0, -r * 0.75), col, w, true)
		Kind.RANGE:
			# Widening arcs thrown from a point: reach.
			ci.draw_circle(c + Vector2(-r * 0.75, 0), w * 1.1, col)
			for k in range(3):
				var rr: float = r * (0.5 + float(k) * 0.45)
				ci.draw_arc(c + Vector2(-r * 0.75, 0), rr, -0.9, 0.9, 16, col, w, true)
		Kind.PIERCE:
			# A shot passing through.
			ci.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, w, true)
			ci.draw_arc(c + Vector2(r * 0.15, 0), r * 0.55, 0.0, TAU, 20, col, w * 0.8, true)
		Kind.CHAIN:
			# Two links.
			ci.draw_arc(c + Vector2(-r * 0.36, 0), r * 0.48, 0.0, TAU, 20, col, w, true)
			ci.draw_arc(c + Vector2(r * 0.36, 0), r * 0.48, 0.0, TAU, 20, col, w, true)
		Kind.AIM:
			# A reticle.
			ci.draw_arc(c, r * 0.62, 0.0, TAU, 24, col, w, true)
			for k in range(4):
				var a: float = float(k) * PI * 0.5
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + d * r * 0.62, c + d * r, col, w, true)
		Kind.SHIELD:
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.5),
				c + Vector2(r * 0.8, r * 0.25), c + Vector2(0, r),
				c + Vector2(-r * 0.8, r * 0.25), c + Vector2(-r * 0.8, -r * 0.5),
				c + Vector2(0, -r)]), col, w, true)
		Kind.MOTES:
			# A gathered mote.
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r * 0.85), c + Vector2(r * 0.7, 0),
				c + Vector2(0, r * 0.85), c + Vector2(-r * 0.7, 0)]), col)
		Kind.KEYSTONE:
			# A star inside the hex: this one changes a rule.
			var pts := PackedVector2Array()
			for k in range(10):
				var a: float = -PI * 0.5 + TAU * float(k) / 10.0
				var rr: float = r * (1.0 if k % 2 == 0 else 0.44)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)
		_:
			ci.draw_arc(c, r * 0.6, 0.0, TAU, 20, col, w, true)
