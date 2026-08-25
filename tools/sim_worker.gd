extends RefCounted
## The actual balance runner. Loaded at runtime so the autoloads exist.

const DT := 1.0 / 60.0

## Spend preference per build. A player buys the cheapest thing they want.
const BUILDS := {
	"mixed":  {"burn": 1.0, "shroud": 1.0, "reach": 1.0, "root": 1.0},
	"burn":   {"burn": 1.0},
	"shroud": {"shroud": 1.0},
	"reach":  {"reach": 1.0},
	"root":   {"root": 1.0},
	"none":   {},
	# The pairing the design is actually built around: Shroud pays for the
	# luminance that Burn generates, so you can take more Burn than you
	# otherwise could afford to be seen carrying.
	"burnshroud": {"burn": 1.0, "shroud": 1.0},
	"burnreach":  {"burn": 1.0, "reach": 1.0},
	"burnroot":   {"burn": 1.0, "root": 1.0},
	"shroudroot": {"shroud": 1.0, "root": 1.0},
}

var minutes: float = 30.0
var rng_seed: int = 1234
var runs: int = 1
var out_path: String = "user://sweep.csv"
var _seed_embers: int = 0
var retire_at: float = 25.0 * 60.0

func run(args: Dictionary) -> void:
	if TreeDB.nodes.is_empty():
		TreeDB.load_all()
	minutes = float(args.get("minutes", minutes))
	rng_seed = int(args.get("seed", rng_seed))
	runs = int(args.get("runs", runs))
	out_path = str(args.get("out", out_path))
	var which: String = str(args.get("build", "all"))
	# --set=KEY=VALUE sweeps a tuning value for this invocation only.
	for k in args.keys():
		if str(k).begins_with("set:"):
			var key: String = str(k).substr(4)
			if not Constants.set_tuning(key, float(args[k])):
				push_warning("unknown tuning key '%s'" % key)
			else:
				print("  %s = %s" % [key, args[k]])

	_seed_embers = int(args.get("seed_embers", 0))
	retire_at = float(args.get("retire", 25.0)) * 60.0
	if args.has("cycles"):
		_campaign(which if which != "all" else "mixed", int(args["cycles"]))
		return

	var names: Array = BUILDS.keys() if which == "all" else [which]
	print("%-8s %6s %9s %8s %8s %7s %6s %7s %6s %6s" %
		["build", "level", "survived", "motes", "peaklum", "embers", "nodes",
		"kills", "brchs", "dps"])
	var rows: Array[String] = ["build,run,level,survived_s,total_motes,peak_lum,embers,nodes"]
	for name in names:
		var surv: float = 0.0
		var motes: float = 0.0
		var lum: float = 0.0
		var emb: float = 0.0
		var owned: float = 0.0
		var kl: float = 0.0
		var br: float = 0.0
		var sw: float = 0.0
		var lv: float = 0.0
		var dp: float = 0.0
		var lvl: float = 0.0
		for r in range(runs):
			var res: Dictionary = _one(name, rng_seed + r)
			surv += float(res["survived"])
			motes += float(res["motes"])
			lum += float(res["lum"])
			emb += float(res["embers"])
			owned += float(res["nodes"])
			kl += float(res["kills"])
			br += float(res["breaches"])
			sw += float(res["spawns"])
			lv += float(res["max_live"])
			dp += float(res["dps"])
			lvl += float(res["level"])
			rows.append("%s,%d,%d,%.1f,%.0f,%.1f,%.0f,%d" % [name, r, res["level"],
				res["survived"], res["motes"], res["lum"], res["embers"], res["nodes"]])
		var n: float = float(runs)
		print("%-8s %6.1f %9s %8s %8s %7s %6d %7d %6d %6d" % [name,
			lvl / n, UITheme.fmt_time(surv / n), UITheme.fmt(motes / n),
			UITheme.fmt(lum / n), UITheme.fmt(emb / n), int(owned / n),
			int(kl / n), int(br / n), int(dp / n)])

	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		for line in rows:
			f.store_line(line)
		f.close()
		print("csv: %s" % ProjectSettings.globalize_path(out_path))

func _one(build: String, seed_v: int) -> Dictionary:
	var s := GameStateData.new()
	GameState.s = s
	s.rng.seed = seed_v
	s.purchase_version += 1
	Stats.recompute(s)
	s.shields = Stats.max_shields

	var prefs: Dictionary = BUILDS.get(build, {})
	var steps: int = int(minutes * 60.0 / DT)
	var peak: float = 0.0
	var buy_timer: float = 0.0
	var kills: Array[int] = [0]
	var breaches: Array[int] = [0]
	var spawns: Array[int] = [0]
	var max_live: int = 0
	var ck := func(_t: int, _a: Vector2, _m: float): kills[0] += 1
	var bk := func(_r: int): breaches[0] += 1
	var sp := func(_c: Contact): spawns[0] += 1
	EventBus.contact_killed.connect(ck)
	EventBus.shield_breached.connect(bk)
	EventBus.contact_spawned.connect(sp)

	for _i in range(steps):
		if s.purchase_version != Stats.cached_version:
			Stats.recompute(s)
		s.t += DT
		Luminance.tick(s, DT)
		Spawning.tick(s, DT)
		Field.move_contacts(s, DT)
		Turret.tick(s, DT)
		Turret.move_projectiles(s, DT)
		Field.check_breaches(s)
		Levels.tick(s, DT)
		peak = maxf(peak, s.effective_luminance())
		max_live = maxi(max_live, s.contacts.size())
		if s.run_over:
			break
		# The player shops every couple of seconds, not every frame.
		buy_timer -= DT
		if buy_timer <= 0.0:
			buy_timer = 2.0
			_shop(s, prefs)

	EventBus.contact_killed.disconnect(ck)
	EventBus.shield_breached.disconnect(bk)
	EventBus.contact_spawned.disconnect(sp)
	return {"survived": s.t, "motes": s.total_motes_this_run, "lum": peak,
		"embers": GameState.embers_for(s.total_motes_this_run, s.level),
		"nodes": s.purchased.size(), "kills": kills[0], "breaches": breaches[0],
		"level": s.level,
		"spawns": spawns[0], "max_live": max_live, "dps": Stats.dps(),
		"range": Stats.turret_range, "shields": s.shields}

## Model a player pushing the tree outward: buy the deepest affordable node,
## rotating between the branches they care about so a multi-branch build is
## actually balanced rather than whichever branch happens to be cheapest.
## Infinite sinks are the fallback when nothing else is affordable, which is
## exactly what the spec says they are for.
var _rotate: int = 0

func _shop(s: GameStateData, prefs: Dictionary) -> void:
	if prefs.is_empty():
		return
	var branches: Array = prefs.keys()
	for _pass in range(8):
		var bought: bool = false
		for i in range(branches.size()):
			_rotate = (_rotate + 1) % branches.size()
			var one: Dictionary = {branches[_rotate]: true}
			if _buy_best(s, one, false):
				bought = true
				break
		if not bought and not _buy_best(s, prefs, true):
			return

func _buy_best(s: GameStateData, prefs: Dictionary, sinks: bool) -> bool:
	var best: TreeNode = null
	var best_cost: float = -1.0
	for id in TreeDB.all_ids():
		var n: TreeNode = TreeDB.get_node_def(id)
		if not prefs.has(String(n.branch)) or n.section != &"base":
			continue
		if n.is_infinite() != sinks:
			continue
		var rank: int = int(s.purchased.get(String(n.id), 0))
		if not n.is_infinite() and rank >= n.max_rank:
			continue
		var met: bool = true
		for r in n.requires:
			if int(s.purchased.get(String(r), 0)) <= 0:
				met = false
				break
		if not met:
			continue
		var c: float = n.cost_at(rank)
		if c <= s.motes and c > best_cost:
			best_cost = c
			best = n
	if best == null:
		return false
	s.motes -= best_cost
	s.purchased[String(best.id)] = int(s.purchased.get(String(best.id), 0)) + 1
	s.purchase_version += 1
	Stats.recompute(s)
	return true

func _campaign(build: String, cycles: int) -> void:
	var s := GameStateData.new()
	s.rng.seed = rng_seed
	s.purchase_version += 1
	s.embers = float(_seed_embers)
	for sec in [&"ember_1", &"ember_2", &"ember_3", &"ember_4"]:
		if _seed_embers > 0:
			s.unlocked_sections.append(String(sec))
	Stats.recompute(s)
	if _seed_embers > 0:
		_spend_embers(s)
		print("seeded with %d embers -> %d ember nodes, dps %.0f, shields %d" %
			[_seed_embers, _ember_nodes(s), Stats.dps(), Stats.max_shields])
	print("%-6s %6s %9s %9s %8s %9s %7s %7s" %
		["run", "level", "survived", "motes", "peaklum", "embers", "ember_n", "clock"])
	var clock: float = 0.0
	var banked: float = 0.0
	for c in range(cycles):
		var res: Dictionary = _run_with(s, build)
		clock += float(res["survived"])
		# Death pays less than retiring, which is the whole point of the
		# retire button; the campaign models a player who dies.
		# Retiring pays the bonus; dying does not. That gap is the reason
		# the retire button exists.
		var gained: float = GameState.embers_for(s.total_motes_this_run, s.level)
		if bool(res.get("retired", false)):
			gained = floor(gained * (1.0 + Constants.RETIRE_BONUS)) if gained > 0.0 else 1.0
		banked += gained
		s.embers += gained
		s.ember_count += 1
		var section: StringName = _next_section(s)
		if section != &"":
			s.unlocked_sections.append(String(section))
		_reset_run(s)
		_spend_embers(s)
		print("%-6d %6d %9s %9s %8s %9s %7d %7s" % [c + 1, int(res["level"]),
			UITheme.fmt_time(float(res["survived"])), UITheme.fmt(float(res["motes"])),
			UITheme.fmt(float(res["lum"])), UITheme.fmt(gained),
			_ember_nodes(s), UITheme.fmt_time(clock)])
	print("total play: %s, embers banked: %s, ember nodes: %d/%d" %
		[UITheme.fmt_time(clock), UITheme.fmt(banked), _ember_nodes(s), _ember_total()])

func _next_section(s: GameStateData) -> StringName:
	for sec in [&"ember_1", &"ember_2", &"ember_3", &"ember_4"]:
		if not s.unlocked_sections.has(String(sec)):
			return sec
	return &""

func _ember_nodes(s: GameStateData) -> int:
	var n: int = 0
	for key in s.purchased.keys():
		var d: TreeNode = TreeDB.get_node_def(StringName(str(key)))
		if d != null and d.branch == &"ember":
			n += 1
	return n

func _ember_total() -> int:
	return TreeDB.branch_nodes(&"ember").size()

func _reset_run(s: GameStateData) -> void:
	var kept: Dictionary = {}
	for key in s.purchased.keys():
		var d: TreeNode = TreeDB.get_node_def(StringName(str(key)))
		if d != null and d.branch == &"ember":
			kept[key] = s.purchased[key]
	s.purchased = kept
	s.t = 0.0
	s.motes = 0.0
	s.total_motes_this_run = 0.0
	s.contacts = [] as Array[Contact]
	s.projectiles = [] as Array[Projectile]
	s.wildfire_lum = 0.0
	s.spawn_timer = 0.0
	s.fire_timer = 0.0
	s.run_over = false
	s.purchase_version += 1
	Stats.recompute(s)
	s.shields = Stats.max_shields

func _spend_embers(s: GameStateData) -> void:
	for _pass in range(60):
		if not _buy_ember(s, false) and not _buy_ember(s, true):
			return

## Depth first, sinks only as the fallback — same policy as the mote shop.
func _buy_ember(s: GameStateData, sinks: bool) -> bool:
	var best: TreeNode = null
	var best_cost: float = -1.0
	for id in TreeDB.all_ids():
		var n: TreeNode = TreeDB.get_node_def(id)
		if n.branch != &"ember" or n.is_infinite() != sinks:
			continue
		if n.section != &"base" and not s.unlocked_sections.has(String(n.section)):
			continue
		var rank: int = int(s.purchased.get(String(n.id), 0))
		if not n.is_infinite() and rank >= n.max_rank:
			continue
		var met: bool = true
		for r in n.requires:
			if int(s.purchased.get(String(r), 0)) <= 0:
				met = false
				break
		if not met:
			continue
		var c: float = n.cost_at(rank)
		if c <= s.embers and c > best_cost:
			best_cost = c
			best = n
	if best == null:
		return false
	s.embers -= best_cost
	s.purchased[String(best.id)] = int(s.purchased.get(String(best.id), 0)) + 1
	s.purchase_version += 1
	Stats.recompute(s)
	return true

func _run_with(s: GameStateData, build: String) -> Dictionary:
	# Spawning reads ember_count off the live GameState, so the runner's
	# state object has to be the live one.
	GameState.s = s
	var prefs: Dictionary = BUILDS.get(build, {})
	var steps: int = int(minutes * 60.0 / DT)
	var peak: float = 0.0
	var buy_timer: float = 0.0
	for _i in range(steps):
		if s.purchase_version != Stats.cached_version:
			Stats.recompute(s)
		s.t += DT
		Luminance.tick(s, DT)
		Spawning.tick(s, DT)
		Field.move_contacts(s, DT)
		Turret.tick(s, DT)
		Turret.move_projectiles(s, DT)
		Field.check_breaches(s)
		Levels.tick(s, DT)
		peak = maxf(peak, s.effective_luminance())
		if s.run_over or s.t >= retire_at:
			break
		buy_timer -= DT
		if buy_timer <= 0.0:
			buy_timer = 2.0
			_shop(s, prefs)
	return {"survived": s.t, "motes": s.total_motes_this_run, "lum": peak,
		"level": s.level, "retired": not s.run_over}
