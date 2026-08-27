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

	var names: Array = BUILDS.keys() if which == "all" else [which]
	print("%-11s %6s %9s %9s %8s %6s %7s %6s %6s" %
		["build", "level", "survived", "motes", "peaklum", "nodes",
		"kills", "brchs", "dps"])
	var rows: Array[String] = ["build,run,level,survived_s,total_motes,peak_lum,nodes"]
	for name in names:
		var surv: float = 0.0
		var motes: float = 0.0
		var lum: float = 0.0
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
			owned += float(res["nodes"])
			kl += float(res["kills"])
			br += float(res["breaches"])
			sw += float(res["spawns"])
			lv += float(res["max_live"])
			dp += float(res["dps"])
			lvl += float(res["level"])
			rows.append("%s,%d,%d,%.1f,%.0f,%.1f,%d" % [name, r, res["level"],
				res["survived"], res["motes"], res["lum"], res["nodes"]])
		var n: float = float(runs)
		print("%-11s %6.1f %9s %9s %8s %6d %7d %6d %6d" % [name,
			lvl / n, UITheme.fmt_time(surv / n), UITheme.fmt(motes / n),
			UITheme.fmt(lum / n), int(owned / n),
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
		# The upgrade step waits for a decision. The runner shops, then goes.
		if s.phase == GameStateData.Phase.UPGRADING:
			_shop(s, prefs)
			Levels.begin_next(s)
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
		if not prefs.has(String(n.branch)):
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
	# The real path, not a copy of it. This used to mutate purchased/motes
	# by hand and so never granted bought shields — the runner was balancing
	# a game where Root's defensive half did nothing, which is not the game
	# that ships.
	return GameState.purchase(best.id)
