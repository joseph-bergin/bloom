class_name TreeIcons
extends RefCounted
## A pixel sprite per kind of upgrade, defined as a 9x9 grid and drawn as
## whole blocks. The previous icons were thin vector strokes, which read as
## scratchy at tile size and did not belong next to a bitmap font.
##
## The kind is derived from what the node actually does, so a node's picture
## and its effect cannot drift apart the way a hand-assigned icon would.

enum Kind {
	DAMAGE, RATE, CRIT, PROJECTILES,      # burn
	SHROUD, BREATH, VISION,               # shroud
	RANGE, PIERCE, CHAIN, AIM,            # reach
	SHIELD, MOTES,                        # root
	KEYSTONE, GENERIC,
}

const STAT_KIND := {
	"damage_mult": Kind.DAMAGE,
	"damage_scale": Kind.DAMAGE,
	"fire_rate_mult": Kind.RATE,
	"crit_chance": Kind.CRIT,
	"crit_mult": Kind.CRIT,
	"projectiles": Kind.PROJECTILES,
	"shroud": Kind.SHROUD,
	"douse_efficiency": Kind.BREATH,
	"douse_refill": Kind.BREATH,
	"vision": Kind.VISION,
	"range_mult": Kind.RANGE,
	"pierce": Kind.PIERCE,
	"chain": Kind.CHAIN,
	"aim_assist": Kind.AIM,
	"shields": Kind.SHIELD,
	"mote_mult": Kind.MOTES,
	"mote_add": Kind.MOTES,
}

const G := 9   # grid is 9x9

## '#' is the icon colour, '+' a lighter highlight, '.' transparent.
const SPRITE := {
	Kind.DAMAGE: [
		"....#....",
		"....#....",
		"...###...",
		"..##+##..",
		"..#+++#..",
		".##+++##.",
		".##+++##.",
		".#######.",
		"..#####.."],
	Kind.RATE: [
		".........",
		".#...#...",
		".##..##..",
		".###.###.",
		".###+###+",
		".###.###.",
		".##..##..",
		".#...#...",
		"........."],
	Kind.CRIT: [
		"....#....",
		"....#....",
		"..#.#.#..",
		"...+++...",
		"##.+#+.##",
		"...+++...",
		"..#.#.#..",
		"....#....",
		"....#...."],
	Kind.PROJECTILES: [
		"#...#...#",
		"#...#...#",
		".#..#..#.",
		".#..#..#.",
		"..#.#.#..",
		"..#.#.#..",
		"...###...",
		"....#....",
		"....#...."],
	Kind.SHROUD: [
		"...#+#...",
		".###+....",
		".##+.....",
		"###+.....",
		"##+......",
		"###+.....",
		".##+.....",
		".###+....",
		"...#+#..."],
	Kind.BREATH: [
		"#########",
		".#+++++#.",
		"..#+++#..",
		"...#+#...",
		"....#....",
		"...#+#...",
		"..#+++#..",
		".#+++++#.",
		"#########"],
	Kind.VISION: [
		".........",
		"..#####..",
		".#+...+#.",
		"#..###..#",
		"#.##+##.#",
		"#..###..#",
		".#+...+#.",
		"..#####..",
		"........."],
	Kind.RANGE: [
		".........",
		".........",
		"..#...#..",
		".#.....#.",
		"+#######+",
		".#.....#.",
		"..#...#..",
		".........",
		"........."],
	Kind.PIERCE: [
		".........",
		".#.......",
		".#....#..",
		".#.....#.",
		".########",
		".#.....#.",
		".#....#..",
		".#.......",
		"........."],
	Kind.CHAIN: [
		".....###.",
		"....###..",
		"...###...",
		"..######.",
		".....##..",
		"....##...",
		"...##....",
		"..##.....",
		".#......."],
	Kind.AIM: [
		"....#....",
		"....#....",
		"..#####..",
		".##+++##.",
		"###+#+###",
		".##+++##.",
		"..#####..",
		"....#....",
		"....#...."],
	Kind.SHIELD: [
		".#######.",
		"#########",
		"#+#####+#",
		"#+#####+#",
		"#+#####+#",
		".#######.",
		"..#####..",
		"...###...",
		"....#...."],
	Kind.MOTES: [
		"....#....",
		"...###...",
		"..##+##..",
		".##+++##.",
		"##+++++##",
		".##+++##.",
		"..##+##..",
		"...###...",
		"....#...."],
	Kind.KEYSTONE: [
		".........",
		"#...#...#",
		"#..###..#",
		"#.##+##.#",
		"##+++++##",
		"#########",
		"#+#+#+#+#",
		"#########",
		"........."],
	Kind.GENERIC: [
		".........",
		"..#####..",
		".#+++++#.",
		".#+###+#.",
		".#+###+#.",
		".#+###+#.",
		".#+++++#.",
		"..#####..",
		"........."],
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

## Draws the sprite into `ci`, filling a `size`-wide box at `origin`.
## Blocks are snapped to whole pixels so the sprite stays crisp.
static func draw_icon(ci: CanvasItem, kind: Kind, origin: Vector2, size: float,
		col: Color) -> void:
	var rows: Array = SPRITE.get(kind, SPRITE[Kind.GENERIC])
	var px: float = maxf(round(size / float(G)), 1.0)
	var pad: Vector2 = (Vector2(size, size) - Vector2(px, px) * G) * 0.5
	var base: Vector2 = (origin + pad).round()
	var hi: Color = col.lerp(Color(1, 1, 1), 0.28)
	for y in range(G):
		var row: String = rows[y]
		for x in range(G):
			var c: String = row[x]
			if c == ".":
				continue
			ci.draw_rect(Rect2(base + Vector2(x, y) * px, Vector2(px, px)),
				hi if c == "+" else col)
