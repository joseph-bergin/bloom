extends RefCounted
## Sim maths is pure and must be tested.

var _pass: int = 0
var _fail: int = 0
var _current: String = ""

func run_all() -> int:
	if TreeDB.nodes.is_empty():
		TreeDB.load_all()
	var names: PackedStringArray = []
	for m in get_method_list():
		if str(m["name"]).begins_with("test_"):
			names.append(str(m["name"]))
	names.sort()
	for n in names:
		_current = n
		var before: int = _fail
		call(n)
		if _fail == before:
			print("  ok   %s" % n)
	print("\n%d passed, %d failed" % [_pass, _fail])
	return _fail

func ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("  FAIL %s: %s" % [_current, msg])

func near(a: float, b: float, tol: float, msg: String) -> void:
	ok(absf(a - b) <= tol, "%s (got %f, want %f +/- %f)" % [msg, a, b, tol])

func fresh() -> GameStateData:
	var s := GameStateData.new()
	GameState.s = s
	s.rng.seed = 7
	s.purchase_version += 1
	Stats.recompute(s)
	s.shields = Stats.max_shields
	return s

func own(s: GameStateData, id: StringName, rank: int = 1) -> void:
	var n: TreeNode = TreeDB.get_node_def(id)
	for r in n.requires:
		if int(s.purchased.get(String(r), 0)) <= 0:
			own(s, r, 1)
	s.purchased[String(id)] = rank
	s.purchase_version += 1
	Stats.recompute(s)

# --- luminance -----------------------------------------------------------

func test_luminance_is_the_sum_of_purchased_node_light() -> void:
	var s := fresh()
	near(s.effective_luminance(), 0.0, 1e-6, "nothing built, nothing glowing")
	var n: TreeNode = TreeDB.get_node_def(&"burn_entry")
	own(s, &"burn_entry", 3)
	Luminance.tick(s, 0.0)
	near(s.luminance, n.lum * 3.0, 1e-4, "L = sum(node.lum * rank)")

func test_shroud_reduces_luminance_but_never_to_zero() -> void:
	var s := fresh()
	own(s, &"burn_entry", 10)
	Luminance.tick(s, 0.0)
	var bright: float = s.luminance
	own(s, &"shroud_baffle", 10)
	Luminance.tick(s, 0.0)
	ok(s.luminance < bright, "shroud reduces luminance")
	ok(Constants.SHROUD_CAP < 1.0, "never fully dark")
	near(s.luminance, (Stats.lum_from_tree) * (1.0 - Stats.shroud), 1e-4,
		"L = tree light * (1 - shroud)")

func test_shroud_is_hard_capped() -> void:
	var s := fresh()
	for id in ["shroud_entry", "shroud_baffle", "shroud_mantle", "shroud_veil",
			"shroud_occlude"]:
		own(s, StringName(id), 10)
	for _i in range(60):
		if GameState.purchase(&"shroud_hush"):
			pass
	ok(Stats.shroud <= Constants.SHROUD_CAP + 1e-6,
		"shroud caps at %.2f (got %.3f)" % [Constants.SHROUD_CAP, Stats.shroud])

func test_douse_cuts_luminance_to_a_tenth_and_drains() -> void:
	var s := fresh()
	own(s, &"burn_entry", 10)
	Luminance.tick(s, 0.0)
	var lit: float = s.effective_luminance()
	s.dousing = true
	near(s.effective_luminance(), lit * Constants.DOUSE_FACTOR, 1e-4, "douse factor")
	var before: float = s.douse_meter
	Luminance.tick(s, 1.0)
	near(s.douse_meter, before - Stats.douse_drain, 1e-4, "meter drains while held")
	s.dousing = false
	Luminance.tick(s, 1.0)
	ok(s.douse_meter > before - Stats.douse_drain, "and refills when released")

## Holding the key at empty used to flicker on and off every frame, firing
## the start/end events over and over. It is spent until it recovers.
func test_an_empty_meter_spends_the_douse_until_it_recovers() -> void:
	var s := fresh()
	s.dousing = true
	s.douse_meter = 0.01
	Luminance.tick(s, 1.0)
	ok(s.douse_spent, "the meter is spent")
	ok(not s.is_dousing(), "and holding the key does nothing")

	# Still held, still spent, no chattering.
	for _i in range(20):
		Luminance.tick(s, 0.05)
		ok(not s.is_dousing(), "stays spent while it refills")
	ok(s.douse_meter > 0.0, "and it does refill while held")

	while s.douse_meter < Constants.DOUSE_RECOVER:
		Luminance.tick(s, 0.5)
	Luminance.tick(s, 0.01)
	ok(not s.douse_spent, "past the recovery mark it can be used again")
	ok(s.is_dousing(), "and the held key takes effect")

func test_hiding_slows_spawning_hard() -> void:
	var s := fresh()
	GameState.s = s
	var open_rate: float = Spawning.spawn_interval(60.0)
	s.dousing = true
	s.douse_meter = 1.0
	ok(Spawning.spawn_interval(60.0) > open_rate * 3.0,
		"hiding has to actually slow the field, not trim it")

# --- spawning ------------------------------------------------------------

func test_spawn_interval_shortens_with_luminance() -> void:
	near(Spawning.spawn_interval(0.0), Constants.SPAWN_INTERVAL_BASE, 1e-4, "base interval")
	near(Spawning.spawn_interval(50.0), Constants.SPAWN_INTERVAL_BASE / 2.0, 1e-4,
		"L = 50 doubles the spawn rate")
	ok(Spawning.spawn_interval(200.0) < Spawning.spawn_interval(100.0),
		"brighter is always faster")

func test_max_tier_and_drift_track_luminance() -> void:
	ok(Spawning.max_tier(0.0) == 0, "tier 0 at zero light")
	ok(Spawning.max_tier(120.0) == 3, "L/40 sets the tier")
	ok(Spawning.max_tier(1.0e6) == Constants.MAX_TIER, "tier is capped")
	near(Spawning.drift_speed(0.0), Constants.DRIFT_BASE, 1e-4, "base drift")
	near(Spawning.drift_speed(100.0),
		Constants.DRIFT_BASE + 100.0 * Constants.DRIFT_LUM_SCALE, 1e-4, "drift scales")

func test_contacts_spawn_at_the_edge_and_move_inward() -> void:
	var s := fresh()
	var c: Contact = Spawning.spawn_one(s, 0.0)
	near(c.pos.length(), Constants.FIELD_RADIUS, 1e-3, "spawns at the field edge")
	var before: float = c.pos.length()
	Field.move_contacts(s, 1.0)
	ok(c.pos.length() < before, "drifts toward the centre")

func test_contact_hp_and_motes_scale_with_tier() -> void:
	var s := fresh()
	for tier in range(0, 5):
		var c := Contact.make(tier, Vector2(Constants.FIELD_RADIUS, 0.0), 10.0)
		near(c.max_hp, Constants.HP_BASE * pow(Constants.HP_TIER_MULT, float(tier)),
			1e-4, "hp at tier %d" % tier)
		near(c.motes(), Constants.MOTE_BASE * pow(Constants.MOTE_TIER_MULT, float(tier)),
			1e-4, "motes at tier %d" % tier)

func test_tier_rolls_bias_toward_the_top() -> void:
	var s := fresh()
	var high: int = 0
	var trials: int = 4000
	for _i in range(trials):
		if Spawning.roll_tier(s, 240.0) >= 4:
			high += 1
	# Uniform over 0..6 would put ~43% at tier 4+. The bias must beat that.
	ok(float(high) / float(trials) > 0.50,
		"escalating field, not an averaging one (got %.2f)" % (float(high) / float(trials)))

# --- sight ---------------------------------------------------------------

## The mechanic the whole design was pitched on: what your light reaches,
## you can fight. What it does not, you cannot.
func test_sight_grows_with_light() -> void:
	var s := fresh()
	GameState.s = s
	var dark: float = Sight.radius(s)
	near(dark, Constants.VISION_BASE, 0.001, "you see something at zero light")
	own(s, &"burn_entry", 10)
	Luminance.tick(s, 0.0)
	ok(Sight.radius(s) > dark, "and further the brighter you burn")

func test_the_turret_cannot_touch_what_it_cannot_see() -> void:
	var s := fresh()
	GameState.s = s
	var far := Contact.make(0, Vector2(Sight.radius(s) + 40.0, 0.0), 0.0)
	s.contacts.append(far)
	ok(not Sight.can_see(s, far), "past the light it is unseen")
	ok(Turret.nearest(s) == null, "so the turret will not lock it")
	ok(not Turret.anything_in_range(s), "and holds its fire")

	var near_c := Contact.make(0, Vector2(Sight.radius(s) - 20.0, 0.0), 0.0)
	s.contacts.append(near_c)
	ok(Sight.can_see(s, near_c), "inside the light it is seen")
	ok(Turret.nearest(s) == near_c, "and the turret takes it")

func test_shots_pass_through_the_unseen() -> void:
	var s := fresh()
	GameState.s = s
	var ghost := Contact.make(0, Vector2(Sight.radius(s) + 60.0, 0.0), 0.0)
	s.contacts.append(ghost)
	var p := Projectile.make(Vector2.ZERO, Vector2.RIGHT, 9999.0, false)
	p.pos = ghost.pos
	s.projectiles.append(p)
	Turret.move_projectiles(s, 0.001)
	near(ghost.hp, ghost.max_hp, 0.001, "an unseen contact takes no damage")

## Otherwise losing the boss in the dark would read as a bug, not darkness.
func test_a_boss_is_always_visible() -> void:
	var s := fresh()
	GameState.s = s
	var b := Contact.make_boss(3, Vector2(Constants.FIELD_RADIUS, 0.0), 10.0)
	ok(Sight.can_see(s, b), "the boss announces itself however dark it is")

## Range you cannot see past is wasted, which is what makes the two
## branches that buy them a real choice rather than a stacking order.
func test_engagement_is_the_nearer_of_sight_and_range() -> void:
	var s := fresh()
	GameState.s = s
	near(Sight.engagement(s), minf(Sight.radius(s), Stats.turret_range), 0.001,
		"engagement is whichever binds")
	ok(Sight.radius(s) < Stats.turret_range,
		"a dark opening is sight-limited, so light is worth buying")

## Shroud's answer to going dark: sight that costs no light to have.
func test_shroud_buys_sight_without_emitting() -> void:
	var s := fresh()
	GameState.s = s
	var before: float = Sight.radius(s)
	own(s, &"shroud_adapt", 8)
	Luminance.tick(s, 0.0)
	ok(Sight.radius(s) > before, "dark adaptation extends sight")
	near(s.luminance, 0.0, 0.001, "and emits nothing doing it")

## Being safe and being blind are the same act.
func test_hiding_pulls_the_light_in() -> void:
	var s := fresh()
	GameState.s = s
	own(s, &"burn_entry", 6)
	Luminance.tick(s, 0.0)
	var open_sight: float = Sight.radius(s)
	s.dousing = true
	s.douse_meter = 1.0
	ok(Sight.radius(s) < open_sight * 0.6,
		"hiding costs most of your sight, not a trim")

# --- turret --------------------------------------------------------------

func test_turret_targets_the_nearest_contact_in_range() -> void:
	var s := fresh()
	var far := Contact.make(0, Vector2(Stats.turret_range - 10.0, 0.0), 0.0)
	var close := Contact.make(0, Vector2(60.0, 0.0), 0.0)
	s.contacts.append(far)
	s.contacts.append(close)
	ok(Turret.nearest(s) == close, "nearest wins")
	s.contacts.clear()
	s.contacts.append(Contact.make(0, Vector2(Stats.turret_range + 50.0, 0.0), 0.0))
	ok(Turret.nearest(s) == null, "out of range is not a target")

func test_turret_fires_and_kills_and_pays_out() -> void:
	var s := fresh()
	s.contacts.append(Contact.make(0, Vector2(120.0, 0.0), 0.0))
	var fired: bool = false
	for _i in range(400):
		Turret.tick(s, 1.0 / 60.0)
		Turret.move_projectiles(s, 1.0 / 60.0)
		if not s.projectiles.is_empty():
			fired = true
		if s.contacts.is_empty():
			break
	ok(fired, "the turret fires on its own")
	ok(s.contacts.is_empty(), "and the contact dies")
	ok(s.motes > 0.0, "motes drop")
	near(s.total_motes_this_run, s.motes, 1e-6, "run total tracks the payout")

func test_projectiles_expire_off_field() -> void:
	var s := fresh()
	s.projectiles.append(Projectile.make(Vector2.ZERO, Vector2.RIGHT, 1.0, false))
	for _i in range(600):
		Turret.move_projectiles(s, 1.0 / 60.0)
	ok(s.projectiles.is_empty(), "nothing travels forever")

func test_dps_combines_damage_rate_and_crit() -> void:
	var s := fresh()
	near(Stats.dps(), Constants.TURRET_DAMAGE_BASE * Constants.TURRET_RATE_BASE, 1e-4,
		"base dps")
	own(s, &"burn_entry", 10)
	ok(Stats.dps() > Constants.TURRET_DAMAGE_BASE * Constants.TURRET_RATE_BASE,
		"damage nodes raise dps")

# --- shields and run end -------------------------------------------------

func test_reaching_the_centre_costs_a_shield() -> void:
	var s := fresh()
	s.shields = 3
	s.contacts.append(Contact.make(0, Vector2(5.0, 0.0), 0.0))
	Field.check_breaches(s)
	ok(s.shields == 2, "one shield lost")
	ok(s.contacts.is_empty(), "the contact destroys itself")
	ok(not s.run_over, "still alive")

func test_three_breaches_end_the_run() -> void:
	var s := fresh()
	s.shields = 3
	for _i in range(3):
		s.contacts.append(Contact.make(0, Vector2(1.0, 0.0), 0.0))
		Field.check_breaches(s)
	ok(s.run_over, "the run ends at zero shields")

func test_root_nodes_add_shields() -> void:
	var s := fresh()
	var base: int = Stats.max_shields
	own(s, &"root_shield", 2)
	ok(Stats.max_shields > base, "Second Skin adds shields")

# --- economy and tree ----------------------------------------------------

func test_cost_curve_is_cost_times_growth_to_the_rank() -> void:
	var n: TreeNode = TreeDB.get_node_def(&"burn_entry")
	for r in range(0, 6):
		near(n.cost_at(r), n.cost * pow(n.cost_growth, float(r)), 1e-4,
			"cost at rank %d" % r)

func test_purchase_spends_motes_and_raises_luminance() -> void:
	var s := fresh()
	s.motes = 1000.0
	var before_motes: float = s.motes
	ok(GameState.purchase(&"burn_entry"), "purchase succeeds")
	ok(s.motes < before_motes, "motes are spent")
	Luminance.tick(s, 0.0)
	ok(s.luminance > 0.0, "and the bloom grows")

func test_requirements_gate_purchase() -> void:
	var s := fresh()
	s.motes = 1.0e9
	ok(not GameState.can_purchase(TreeDB.get_node_def(&"burn_stoke")),
		"cannot skip a requirement")
	GameState.purchase(&"burn_entry")
	ok(GameState.can_purchase(TreeDB.get_node_def(&"burn_stoke")),
		"met requirement unlocks the child")

func test_max_rank_is_respected_and_sinks_are_infinite() -> void:
	var s := fresh()
	s.motes = 1.0e12
	var n: TreeNode = TreeDB.get_node_def(&"burn_entry")
	for _i in range(n.max_rank + 5):
		GameState.purchase(&"burn_entry")
	ok(int(s.purchased["burn_entry"]) == n.max_rank, "rank caps")
	var sink: TreeNode = TreeDB.get_node_def(&"burn_more")
	ok(sink.is_infinite(), "sinks are uncapped")
	own(s, &"burn_more", 0)
	s.motes = 1.0e12
	for _i in range(30):
		GameState.purchase(&"burn_more")
	ok(int(s.purchased.get("burn_more", 0)) >= 25, "sinks keep accepting ranks")

func test_respec_is_free_and_total() -> void:
	var s := fresh()
	s.motes = 5000.0
	var start: float = s.motes
	GameState.purchase(&"burn_entry")
	GameState.purchase(&"burn_entry")
	ok(s.motes < start, "purchases cost")
	GameState.respec()
	near(s.motes, start, 1e-4, "every rank refunded at the price paid")
	ok(s.purchased.is_empty(), "and the tree is unbuilt")

func test_nothing_shows_until_its_prerequisite_is_bought() -> void:
	var s := fresh()
	ok(GameState.is_revealed(TreeDB.get_node_def(&"burn_entry")), "roots are visible")
	var deep: TreeNode = TreeDB.get_node_def(&"burn_furnace")
	ok(not GameState.is_revealed(deep), "distant nodes stay hidden")
	var kids: Array = TreeDB.children_of(&"burn_entry")
	ok(not kids.is_empty(), "burn_entry leads somewhere")
	for k in kids:
		ok(not GameState.is_revealed(TreeDB.get_node_def(k)),
			"a buyable-but-unbought parent reveals nothing")
	own(s, &"burn_entry", 1)
	for k in kids:
		ok(GameState.is_revealed(TreeDB.get_node_def(k)),
			"owning a node reveals what it leads to")
		# ...and no further. The grandchildren wait their turn.
		for gk in TreeDB.children_of(k):
			ok(not GameState.is_revealed(TreeDB.get_node_def(gk)),
				"reveal stops at the children of what you own")

# --- tree integrity ------------------------------------------------------

## Thirteen Root nodes once granted a stat that had been removed with the
## prestige system. They still cost motes and light and did nothing at all.
## Nothing in the tree may reference a stat or rule the sim never reads.
## PixelFont holds its own copy of the base size because an autoload cannot
## reference a class_name on a cold checkout. Keep the two in step.
func test_the_font_base_size_matches_the_type_scale() -> void:
	ok(PixelFont.BASE_SIZE == UITheme.BODY,
		"PixelFont.BASE_SIZE (%d) must equal UITheme.BODY (%d)"
		% [PixelFont.BASE_SIZE, UITheme.BODY])

func test_every_node_effect_is_actually_read() -> void:
	var live: Dictionary = {}
	for key in ["damage_mult", "damage_scale", "fire_rate_mult", "crit_chance",
			"crit_mult", "projectiles", "shroud", "douse_efficiency",
			"douse_refill", "range_mult", "pierce", "chain", "aim_assist",
			"vision", "shields", "mote_mult", "mote_add"]:
		live[key] = true
	var rules: Dictionary = {}
	for key in ["wildfire", "cinder", "longshot", "diaspora"]:
		rules[key] = true

	var dead: PackedStringArray = []
	for id in TreeDB.all_ids():
		var n: TreeNode = TreeDB.get_node_def(id)
		for e in n.effects:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = e
			if str(d.get("op", "add")) == "rule":
				if not rules.has(str(d.get("rule", ""))):
					dead.append("%s -> rule %s" % [n.display_name, d.get("rule", "")])
			elif not live.has(str(d.get("stat", ""))):
				dead.append("%s -> %s" % [n.display_name, d.get("stat", "")])
	ok(dead.is_empty(), "nodes with effects nothing reads: " + ", ".join(dead))

func test_tree_validates() -> void:
	var errs: PackedStringArray = TreeDB.validate()
	ok(errs.is_empty(), "tree validation:\n" + "\n".join(errs))

## The suite once passed a full run while HUD.gd had a parse error, because
## nothing here ever loads a UI script. A UI that will not compile is a
## broken build whether or not the sim is fine.
func test_every_script_compiles() -> void:
	var n: int = 0
	for dir in ["res://ui", "res://scenes", "res://autoload", "res://sim"]:
		for path in _gd_files(dir):
			# CACHE_MODE_IGNORE: a plain load() hands back the copy already
			# compiled at import time and passes even on a broken file.
			var scr: Resource = ResourceLoader.load(
				path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
			ok(scr != null and (scr as GDScript).can_instantiate(),
				"%s compiles" % path)
			n += 1
	ok(n > 20, "found scripts to check (got %d)" % n)

func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		var path: String = dir + "/" + name
		if d.current_is_dir():
			out.append_array(_gd_files(path))
		elif name.ends_with(".gd"):
			out.append(path)
		name = d.get_next()
	d.list_dir_end()
	return out

## A cue whose envelope is wrong is silent, and silence is not a test
## failure anywhere else. Every voice has to carry signal without clipping.
func test_every_cue_has_audible_signal() -> void:
	var cues := {
		"hover": Synth.hover(), "press": Synth.press(),
		"denied": Synth.denied(), "click": Synth.click(),
		"purchase": Synth.purchase(), "breach": Synth.breach(),
		"cleared": Synth.cleared(), "boss": Synth.boss(),
		"open": Synth.whoosh(true), "close": Synth.whoosh(false),
	}
	for name in cues:
		var w: AudioStreamWAV = cues[name]
		var n: int = w.data.size() / 2
		ok(n > 100, "%s has samples" % name)
		var peak: float = 0.0
		for i in range(n):
			peak = maxf(peak, absf(float(w.data.decode_s16(i * 2)) / 32767.0))
		ok(peak > 0.05, "%s is audible (peak %.3f)" % [name, peak])
		ok(peak < 0.999, "%s does not clip (peak %.3f)" % [name, peak])

## The pause menu used to leave the sim ticking while aiming fell back to
## auto, so holding it open turned the turret into a gun that never missed.
## Pausing has to stop the tick outright.
func test_pausing_stops_the_tick() -> void:
	var s := fresh()
	s.phase = GameStateData.Phase.FIGHTING
	GameState.paused = true
	GameState._physics_process(0.5)
	near(s.t, 0.0, 1e-6, "no time passes while paused")
	ok(s.contacts.is_empty(), "and nothing spawns behind the menu")
	GameState.paused = false
	GameState._physics_process(0.5)
	ok(s.t > 0.0, "time passes again once unpaused")

func test_tree_is_the_right_size() -> void:
	var n: int = TreeDB.nodes.size()
	ok(n >= 125 and n <= 140, "~130 nodes (got %d)" % n)
	for b in TreeDB.branches:
		ok(b in [&"burn", &"shroud", &"reach", &"root"],
			"no branch outside the four (found '%s')" % b)

func test_every_branch_has_a_keystone_and_a_sink() -> void:
	for b in [&"burn", &"shroud", &"reach", &"root"]:
		var key: bool = false
		var sink: bool = false
		for n in TreeDB.branch_nodes(b):
			key = key or n.keystone
			sink = sink or n.is_infinite()
		ok(key, "branch %s has a keystone" % b)
		ok(sink, "branch %s has an infinite sink" % b)

func test_branch_luminance_identity_matches_the_design() -> void:
	# Burn is very loud, Shroud is silent, Reach and Root are the middle.
	var avg: Dictionary = {}
	for b in [&"burn", &"shroud", &"reach", &"root"]:
		var total: float = 0.0
		var n_count: int = 0
		for n in TreeDB.branch_nodes(b):
			if n.is_infinite() or n.keystone:
				continue
			total += n.lum
			n_count += 1
		avg[b] = total / maxf(float(n_count), 1.0)
	near(float(avg[&"shroud"]), 0.0, 1e-6, "Shroud costs no light")
	ok(float(avg[&"burn"]) > float(avg[&"reach"]), "Burn is louder than Reach")
	ok(float(avg[&"burn"]) > float(avg[&"root"]), "Burn is louder than Root")
	ok(float(avg[&"burn"]) >= 3.0 and float(avg[&"burn"]) <= 8.0,
		"Burn sits in 3-8 lum (got %.1f)" % avg[&"burn"])

## There must never be motes in hand with nothing affordable to buy.
func test_no_affordability_wall() -> void:
	var s := fresh()
	var worst: float = 0.0
	for step in range(1, 60):
		s.motes = pow(1.4, float(step)) * 20.0
		var wealth: float = s.motes
		for _pass in range(8):
			for id in TreeDB.all_ids():
				if GameState.can_purchase(TreeDB.get_node_def(id)):
					GameState.purchase(id)
		var cheapest: float = INF
		for id in TreeDB.all_ids():
			var n: TreeNode = TreeDB.get_node_def(id)
			var rank: int = int(s.purchased.get(String(id), 0))
			if not n.is_infinite() and rank >= n.max_rank:
				continue
			if not GameState.requirements_met(n):
				continue
			cheapest = minf(cheapest, n.cost_at(rank))
		ok(cheapest < INF, "step %d: something is purchasable" % step)
		worst = maxf(worst, cheapest / maxf(wealth, 1.0))
	ok(worst <= 2.0, "worst gap was %.2fx wealth" % worst)

# --- keystones -----------------------------------------------------------

func test_wildfire_triples_damage_and_grows_light_forever() -> void:
	var s := fresh()
	# Own the run-up first: the keystone's multiplier is measured against a
	# tree that already has its prerequisites, not against a bare turret.
	own(s, &"burn_wildfire", 1)
	s.purchased.erase("burn_wildfire")
	s.purchase_version += 1
	Stats.recompute(s)
	var base: float = Stats.damage
	own(s, &"burn_wildfire", 1)
	near(Stats.damage / base, Constants.WILDFIRE_DAMAGE_MULT, 0.01, "damage x3")
	var before: float = s.wildfire_lum
	Luminance.tick(s, 10.0)
	near(s.wildfire_lum - before, Constants.WILDFIRE_LUM_RATE * 10.0, 1e-4,
		"luminance grows +0.3/s, forever")

func test_cinder_silences_the_field_below_twenty() -> void:
	var s := fresh()
	own(s, &"shroud_cinder", 1)
	ok(is_inf(Spawning.spawn_interval(10.0)), "nothing spawns under 20 luminance")
	var above: float = Spawning.spawn_interval(100.0)
	Stats._rules.erase(&"cinder")
	var normal: float = Spawning.spawn_interval(100.0)
	near(above, normal / Constants.CINDER_SPAWN_MULT, 1e-4, "and doubles it above")

func test_longshot_trades_fire_rate_for_range_and_pierce() -> void:
	var s := fresh()
	own(s, &"reach_longshot", 1)
	s.purchased.erase("reach_longshot")
	s.purchase_version += 1
	Stats.recompute(s)
	var r0: float = Stats.turret_range
	var f0: float = Stats.fire_rate
	own(s, &"reach_longshot", 1)
	near(Stats.turret_range / r0, Constants.LONGSHOT_RANGE_MULT, 0.01, "range x2.5")
	near(Stats.fire_rate / f0, Constants.LONGSHOT_RATE_MULT, 0.01, "fire rate halved")
	ok(Stats.pierce > 0, "and projectiles pierce")

func test_diaspora_trades_income_for_shields() -> void:
	var s := fresh()
	own(s, &"root_diaspora", 1)
	s.purchased.erase("root_diaspora")
	s.purchase_version += 1
	Stats.recompute(s)
	var sh: int = Stats.max_shields
	var income: float = Stats.mote_mult
	own(s, &"root_diaspora", 1)
	ok(Stats.max_shields == sh + Constants.DIASPORA_SHIELDS, "+3 shields")
	near(Stats.mote_mult / income, Constants.DIASPORA_INCOME_MULT, 0.01, "income -40%")

# --- levels and bosses ---------------------------------------------------

func test_level_quota_grows_and_kills_advance_it() -> void:
	var s := fresh()
	s.level_quota = Levels.compute_quota(s)
	var early: int = s.level_quota
	s.level = 12
	ok(Levels.compute_quota(s) > early, "later levels ask for more")
	s.level = 1
	near(Levels.progress(s), 0.0, 1e-6, "a fresh level is at zero")
	for _i in range(Levels.quota(s)):
		Levels.on_kill(s, Contact.make(0, Vector2(10, 0), 0.0))
	near(Levels.progress(s), 1.0, 1e-6, "quota met")

func test_meeting_the_quota_summons_a_boss() -> void:
	var s := fresh()
	s.level_quota = Levels.compute_quota(s)
	for _i in range(Levels.quota(s)):
		Levels.on_kill(s, Contact.make(0, Vector2(10, 0), 0.0))
	Levels.tick(s, 0.016)
	ok(s.phase == GameStateData.Phase.BOSS, "the level turns into a boss fight")
	var b: Contact = s.boss()
	ok(b != null and b.is_boss, "and a boss exists")
	var plain := Contact.make(b.tier, Vector2(10, 0), 0.0)
	ok(b.max_hp > plain.max_hp, "the boss takes more killing than a contact")
	ok(b.radius > plain.radius * 2.0, "and is unmistakable on the field")
	ok(b.motes() > plain.motes() * 5.0, "and worth killing")

func test_nothing_new_spawns_during_a_boss_or_the_breather() -> void:
	var s := fresh()
	s.phase = GameStateData.Phase.BOSS
	for _i in range(600):
		Spawning.tick(s, 0.1)
	ok(s.contacts.is_empty(), "the boss fight is not diluted with adds")
	s.phase = GameStateData.Phase.UPGRADING
	for _i in range(600):
		Spawning.tick(s, 0.1)
	ok(s.contacts.is_empty(), "and nothing creeps in while the tree is open")

func test_killing_the_boss_clears_the_level_and_pays() -> void:
	var s := fresh()
	s.phase = GameStateData.Phase.BOSS
	s.boss_id = 0
	var before: float = s.motes
	Levels.tick(s, 0.016)
	ok(s.phase == GameStateData.Phase.UPGRADING, "the level is over and says so")
	ok(s.motes > before, "clearing pays a bonus")
	near(s.motes - before, Levels.clear_bonus(s), 1e-4, "the level clear bonus")
	ok(s.level_quota >= int(Constants.LEVEL_QUOTA_MIN), "the next quota is set")
	ok(GameState.begin_next_level(), "and the player starts the next one")
	ok(s.level == 2 and s.phase == GameStateData.Phase.FIGHTING, "then level 2 begins")
	ok(s.level_kills == 0, "with a fresh quota")

func test_the_field_empties_when_a_level_is_cleared() -> void:
	var s := fresh()
	s.phase = GameStateData.Phase.BOSS
	for _i in range(6):
		s.contacts.append(Contact.make(0, Vector2(200, 0), 0.0))
	Levels.tick(s, 0.016)
	ok(s.contacts.is_empty(), "the win is legible — the field clears")

## The boss is the gate. Failing it costs a shield and does not advance the
## level — otherwise a build with no damage walks through by paying shields.
func test_a_boss_that_reaches_you_costs_a_shield_and_comes_back() -> void:
	var s := fresh()
	s.shields = 3
	s.level = 4
	s.phase = GameStateData.Phase.BOSS
	var b := Contact.make_boss(2, Vector2(4.0, 0.0), 10.0)
	b.hp = b.max_hp * 0.4
	s.contacts.append(b)
	s.boss_id = b.get_instance_id()
	Field.check_breaches(s)
	ok(s.shields == 2, "it costs a shield")
	ok(s.level == 4, "the level does not advance")
	ok(s.phase == GameStateData.Phase.BOSS, "you are still in the boss fight")
	var again: Contact = s.boss()
	ok(again != null and again != b, "and it comes straight back")
	near(again.hp, b.hp, 1e-6, "as hurt as you left it")

func test_a_boss_breach_with_no_shields_left_ends_the_run() -> void:
	var s := fresh()
	s.shields = 1
	s.phase = GameStateData.Phase.BOSS
	var b := Contact.make_boss(2, Vector2(3.0, 0.0), 10.0)
	s.contacts.append(b)
	s.boss_id = b.get_instance_id()
	Field.check_breaches(s)
	ok(s.run_over, "the run ends")
	ok(s.run_end_reason.contains("boss"), "and says the boss did it")

## Otherwise a slow, dark build takes as long as it likes over every level.
func test_the_boss_arrives_on_time_even_without_the_quota() -> void:
	var s := fresh()
	s.level_quota = 9999
	ok(s.phase == GameStateData.Phase.FIGHTING, "starts fighting")
	Levels.tick(s, Levels.time_limit() * 0.5)
	ok(s.phase == GameStateData.Phase.FIGHTING, "not yet")
	Levels.tick(s, Levels.time_limit() * 0.6)
	ok(s.phase == GameStateData.Phase.BOSS, "the boss comes anyway")

func test_boss_kills_do_not_count_toward_the_next_quota() -> void:
	var s := fresh()
	var b := Contact.make_boss(1, Vector2(100, 0), 10.0)
	Levels.on_kill(s, b)
	ok(s.level_kills == 0, "the boss is the level, not progress toward it")

func test_levels_add_pressure_of_their_own() -> void:
	ok(Levels.spawn_scalar(8) > Levels.spawn_scalar(1), "later levels are denser")
	var s := fresh()
	var early: float = Spawning.spawn_interval(60.0)
	s.level = 10
	ok(Spawning.spawn_interval(60.0) < early, "and spawn faster at the same light")

func test_bosses_keep_growing_past_the_tier_cap() -> void:
	var s := fresh()
	s.phase = GameStateData.Phase.FIGHTING
	s.level_quota = 1
	s.level_kills = 1
	Levels.tick(s, 0.016)
	var early: float = s.boss().max_hp
	var s2 := fresh()
	s2.level = 30
	s2.level_quota = 1
	s2.level_kills = 1
	Levels.tick(s2, 0.016)
	ok(s2.boss().max_hp > early * 10.0,
		"there is always a wall ahead, however strong the player gets")

func test_the_field_is_capped() -> void:
	var s := fresh()
	for _i in range(Constants.MAX_CONTACTS):
		s.contacts.append(Contact.make(0, Vector2(400, 0), 0.0))
	for _i in range(400):
		Spawning.tick(s, 1.0)
	ok(s.contacts.size() <= Constants.MAX_CONTACTS, "the field has a hard ceiling")

func test_boss_tier_rises_with_level_and_light() -> void:
	var s := fresh()
	var low: int = Levels.boss_tier(s)
	s.level = 12
	ok(Levels.boss_tier(s) > low, "deeper levels field bigger bosses")
	ok(Levels.boss_tier(s) <= Constants.MAX_TIER, "and stay inside the tier cap")

# --- run lifecycle and saves ---------------------------------------------

## The upgrade step is the whole rhythm now: fight, clear, spend, go again.
func test_clearing_a_level_hands_control_back_to_the_player() -> void:
	var s := fresh()
	s.phase = GameStateData.Phase.BOSS
	s.boss_id = 0
	Levels.tick(s, 0.016)
	ok(s.phase == GameStateData.Phase.UPGRADING, "clearing hands control back")
	for _i in range(600):
		Levels.tick(s, 1.0)
	ok(s.phase == GameStateData.Phase.UPGRADING and s.level == 1,
		"and no amount of waiting starts the next level on its own")

func test_begin_next_only_works_while_upgrading() -> void:
	var s := fresh()
	s.phase = GameStateData.Phase.FIGHTING
	ok(not GameState.begin_next_level(), "cannot skip a level mid-fight")

## Levels.reset used to write a field that no longer exists, which only
## surfaced on the title screen's New Run path.
func test_reset_clears_every_field_it_touches() -> void:
	var s := fresh()
	s.level = 7
	s.level_kills = 4
	s.phase = GameStateData.Phase.BOSS
	s.boss_id = 99
	s.level_time = 30.0
	Levels.reset(s)
	ok(s.level == 1 and s.level_kills == 0, "back to the first level")
	ok(s.phase == GameStateData.Phase.FIGHTING, "and to the fighting phase")
	ok(s.boss_id == 0 and s.level_time == 0.0, "with nothing left over")
	ok(s.best_level >= 7, "but the best reached is kept")

func test_restarting_unbuilds_everything_and_keeps_the_best() -> void:
	var s := fresh()
	s.level = 11
	s.motes = 900.0
	s.purchased["burn_entry"] = 3
	s.contacts.append(Contact.make(0, Vector2(300, 0), 0.0))
	s.run_over = true
	GameState.restart_run()
	ok(s.level == 1 and s.phase == GameStateData.Phase.FIGHTING, "back to level 1")
	ok(s.purchased.is_empty() and s.motes == 0.0, "the tree unbuilds")
	ok(s.contacts.is_empty() and not s.run_over, "and the field is clear")
	ok(s.best_level >= 11, "the best level reached is the score, and it stays")
	ok(s.shields == Stats.max_shields, "shields come back")

## Higher tiers must pay better than they cost, or being bright is strictly
## a mistake and the whole tree is a trap.
func test_brightness_pays_for_itself() -> void:
	ok(Constants.MOTE_TIER_MULT > Constants.HP_TIER_MULT,
		"motes per tier (%.2f) must outrun health per tier (%.2f)"
		% [Constants.MOTE_TIER_MULT, Constants.HP_TIER_MULT])
	var lo := Contact.make(0, Vector2(400, 0), 0.0)
	var hi := Contact.make(4, Vector2(400, 0), 0.0)
	ok(hi.motes() / hi.max_hp > lo.motes() / lo.max_hp,
		"a bigger contact is worth more per point of health")

## Tied to the boss, which caps at MAX_TIER, so it cannot run away with the
## level counter the way an exponential in `level` did.
func test_the_clear_bonus_is_bounded() -> void:
	var s := fresh()
	s.level = 1
	var low: float = Levels.clear_bonus(s)
	s.level = 60
	var high: float = Levels.clear_bonus(s)
	ok(high > low, "deeper levels pay more")
	s.level = 400
	near(Levels.clear_bonus(s), high, high * 0.01, "but the bonus is bounded")

# --- saves ---------------------------------------------------------------

func test_save_round_trip_preserves_state() -> void:
	var s := fresh()
	s.motes = 1234.5
	s.t = 456.0
	s.shields = 2
	s.purchased["burn_entry"] = 4
	s.level = 6
	s.best_level = 9
	s.contacts.append(Contact.make(3, Vector2(200.0, 100.0), 20.0))

	var restored := GameStateData.new()
	SaveManager.deserialize(SaveManager.serialize(s), restored)
	near(restored.motes, 1234.5, 1e-4, "motes")
	ok(restored.shields == 2, "shields")
	ok(int(restored.purchased["burn_entry"]) == 4, "purchases")
	ok(restored.contacts.size() == 1 and restored.contacts[0].tier == 3, "contacts")
	ok(restored.level == 6 and restored.best_level == 9, "level progress")

func test_migration_from_version_one() -> void:
	var s := fresh()
	s.motes = 777.0
	s.purchased["shroud_entry"] = 2
	var v1: Dictionary = SaveManager.serialize(s)
	v1["version"] = 1
	v1.erase("wildfire_lum")
	v1.erase("level")
	v1.erase("level_kills")
	v1.erase("best_level")
	var migrated: Dictionary = SaveManager.migrate(v1)
	ok(int(migrated["version"]) == Constants.SAVE_VERSION, "migrated to current")
	ok(migrated.has("wildfire_lum"), "v1 -> v2 filled the new fields")
	ok(migrated.has("level") and migrated.has("best_level"),
		"v2 -> v3 filled in levels")
	var restored := GameStateData.new()
	SaveManager.deserialize(migrated, restored)
	near(restored.motes, 777.0, 1e-4, "no state lost")
	var current: Dictionary = SaveManager.serialize(s)
	ok(SaveManager.migrate(current).hash() == current.hash(),
		"current saves pass through untouched")
