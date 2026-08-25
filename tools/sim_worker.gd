extends RefCounted
## The actual balance harness. Loaded by sim_runner.gd only after the game's
## autoloads have been registered as engine singletons, because this file
## references them and would not otherwise compile under --script.

var minutes: float = 60.0
var dt: float = 1.0 / 60.0
var sample: float = 10.0
var rng_seed: int = 12345
var build: String = "balanced"
var out_path: String = "user://sweep.csv"
var backlight_trials: int = 0

func run(args: Dictionary) -> void:
	# Outside the scene tree the autoload _ready() calls never fire, so the
	# tree database has to be told to load itself.
	if TreeDB.nodes.is_empty():
		TreeDB.load_all()
	minutes = float(args.get("minutes", minutes))
	dt = float(args.get("dt", dt))
	sample = float(args.get("sample", sample))
	rng_seed = int(args.get("seed", rng_seed))
	build = str(args.get("build", build))
	out_path = str(args.get("out", out_path))
	backlight_trials = int(args.get("backlight", backlight_trials))
	if backlight_trials > 0:
		_backlight_check()
	else:
		_run()

# --- Builds under test ----------------------------------------------------

const BUILDS := {
	"balanced": ["expansion_entry", "expansion_bloomfeed", "shroud_entry", "shroud_baffle",
		"optics_entry", "optics_resolution", "sweep_entry", "lance_entry", "lance_guidance",
		"cognition_entry", "cognition_autosweep", "cognition_autolance"],
	"greedy": ["expansion_entry", "expansion_bloomfeed", "expansion_spread",
		"expansion_harvest", "expansion_efflorescence", "lance_entry", "lance_velocity",
		"cognition_entry", "cognition_autosweep", "cognition_autolance"],
	"turtle": ["shroud_entry", "shroud_baffle", "shroud_dampen", "shroud_mantle",
		"shroud_occlude", "shroud_veil", "shroud_quiet"],
	"none": [],
}

func _apply_build(data: GameStateData) -> void:
	var ids: Array = BUILDS.get(build, [])
	for id in ids:
		var n: TreeNode = TreeDB.get_node_def(StringName(str(id)))
		if n == null:
			push_warning("sim_runner: unknown node '%s'" % id)
			continue
		data.purchased[str(id)] = maxi(n.max_rank, 1) if n.max_rank > 0 else 5
	data.purchase_version += 1
	Stats.recompute(data)
	data.redundancy = Stats.max_redundancy

# --- Run ------------------------------------------------------------------

func _run() -> void:
	var data := GameStateData.new()
	data.rng.seed = rng_seed
	_apply_build(data)

	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("sim_runner: cannot write %s" % out_path)
		return
	f.store_line("t,motes,signal,facets,total_motes,lum_eff,lum_struct,lum_trans," +
		"contacts,tracked,hunters,tethers,pressure,redundancy,incoming,run_over")

	var commits: Array[int] = [0]
	var fled: Array[int] = [0]
	EventBus.contact_committed.connect(func(c: Contact):
		commits[0] += 1
		if c.tier <= 1:
			fled[0] += 1)

	var total: float = minutes * 60.0
	var next_sample: float = 0.0
	var steps: int = int(total / dt)
	var died_at: float = -1.0

	for _i in range(steps):
		if data.purchase_version != Stats.cached_version:
			Stats.recompute(data)
		data.t += dt
		Luminance.tick(data, dt)
		Contacts.tick(data, dt)
		Sensing.tick(data, dt)
		Awareness.tick(data, dt)
		Lances.tick(data, dt)
		Tethers.tick(data, dt)
		Blight.tick(data, dt)
		Threat.tick(data, dt)
		Economy.tick(data, dt)
		Automation.tick(data, dt)

		if data.run_over and died_at < 0.0:
			died_at = data.t

		if data.t >= next_sample:
			next_sample += sample
			f.store_line(_row(data))

	f.store_line(_row(data))
	f.close()
	print("build=%s  seed=%d  minutes=%.0f  dt=%.5f" % [build, rng_seed, minutes, dt])
	print("  total motes earned: %.0f" % data.total_motes_earned)
	print("  final luminance:    %.1f" % data.luminance_effective())
	print("  field pressure:     %.3f" % data.field_pressure)
	print("  contacts alive:     %d" % data.contacts.size())
	print("  contacts that resolved you: %d (of which fled with it: %d)" % [commits[0], fled[0]])
	if died_at >= 0.0:
		print("  RUN ENDED at %.0fs (%.1f min): %s" % [died_at, died_at / 60.0, data.run_end_reason])
	else:
		print("  survived the full run")
	print("  csv: %s" % ProjectSettings.globalize_path(out_path))

func _row(d: GameStateData) -> String:
	var tracked: int = 0
	var hunters: int = 0
	for c in d.contacts:
		if Sensing.is_displayable(c, d.t):
			tracked += 1
		if c.is_hunter:
			hunters += 1
	return "%.1f,%.2f,%.2f,%.1f,%.2f,%.3f,%.3f,%.3f,%d,%d,%d,%d,%.4f,%d,%d,%d" % [
		d.t, d.motes, d.signal_c, d.facets, d.total_motes_earned,
		d.luminance_effective(), d.luminance_structural, d.luminance_transient,
		d.contacts.size(), tracked, hunters, d.tethers.size(),
		d.field_pressure, d.redundancy, d.incoming.size(), 1 if d.run_over else 0]

# --- Backlight verification (Phase 6 acceptance) --------------------------

func _backlight_check() -> void:
	var data := GameStateData.new()
	data.rng.seed = rng_seed
	_apply_build(data)
	data.luminance_structural = 240.0
	Stats.recompute(data)

	print("tier,displayed_p,observed_p,trials,abs_error")
	var worst: float = 0.0
	for tier in range(0, 6):
		var displayed: float = Backlight.witness_chance(data, tier)
		var hits: int = 0
		for _i in range(backlight_trials):
			var before: int = data.contacts.size()
			var t_before: float = data.luminance_transient
			if Backlight.roll(data, tier, Vector2(500.0, 0.0)):
				hits += 1
			# Keep conditions identical across trials: undo the side effects.
			data.luminance_transient = t_before
			while data.contacts.size() > before:
				data.contacts.pop_back()
		var observed: float = float(hits) / float(backlight_trials)
		var err: float = absf(observed - displayed)
		worst = maxf(worst, err)
		print("%d,%.4f,%.4f,%d,%.4f" % [tier, displayed, observed, backlight_trials, err])
	# 1000 trials at p~0.5 has a ~1.6% standard error; 3 sigma is ~4.7%.
	var tol: float = 3.0 / sqrt(float(backlight_trials))
	print("worst abs error %.4f, tolerance %.4f -> %s" %
		[worst, tol, "PASS" if worst <= tol else "FAIL"])
