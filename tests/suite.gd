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

func test_douse_releases_when_the_meter_empties() -> void:
	var s := fresh()
	s.dousing = true
	s.douse_meter = 0.01
	Luminance.tick(s, 1.0)
	ok(not s.dousing, "an empty meter stops the douse")
	ok(not s.is_dousing(), "and it stops counting")

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

func test_fog_reveals_neighbours_only() -> void:
	var s := fresh()
	ok(GameState.is_revealed(TreeDB.get_node_def(&"burn_entry")), "roots are visible")
	var deep: TreeNode = TreeDB.get_node_def(&"burn_furnace")
	ok(not GameState.is_revealed(deep), "distant nodes stay fogged")
	own(s, &"burn_entry", 1)
	var kids: Array = TreeDB.children_of(&"burn_entry")
	ok(not kids.is_empty(), "burn_entry leads somewhere")
	for k in kids:
		ok(GameState.is_revealed(TreeDB.get_node_def(k)),
			"owning a node reveals what it leads to")

# --- tree integrity ------------------------------------------------------

func test_tree_validates() -> void:
	var errs: PackedStringArray = TreeDB.validate()
	ok(errs.is_empty(), "tree validation:\n" + "\n".join(errs))

func test_tree_is_the_right_size() -> void:
	var base: int = 0
	for id in TreeDB.all_ids():
		if (TreeDB.get_node_def(id) as TreeNode).branch != &"ember":
			base += 1
	ok(base >= 125 and base <= 140, "~130 base nodes (got %d)" % base)
	ok(TreeDB.branch_nodes(&"ember").size() >= 18,
		"~20 ember nodes (got %d)" % TreeDB.branch_nodes(&"ember").size())

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
			if n.section != &"base":
				continue
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

# --- prestige and saves --------------------------------------------------

func test_ember_payout_formula() -> void:
	var s := fresh()
	near(GameState.embers_for(0.0), 0.0, 1e-6, "nothing earned, nothing banked")
	near(GameState.embers_for(Constants.EMBER_DIVISOR * 9.0), 3.0, 1e-6,
		"floor(sqrt(motes / divisor))")

## Retiring early must always beat dying.
func test_retiring_always_beats_dying() -> void:
	var s := fresh()
	for motes in [0.0, 500.0, 5000.0, 50000.0, 500000.0, 5.0e6]:
		s.total_motes_this_run = motes
		ok(GameState.embers_on_retire() > GameState.embers_on_death()
			or GameState.embers_on_death() == 0.0 and GameState.embers_on_retire() > 0.0,
			"retire beats death at %s motes (%s vs %s)" % [motes,
				GameState.embers_on_retire(), GameState.embers_on_death()])

func test_banking_resets_the_run_but_keeps_ember_nodes() -> void:
	var s := fresh()
	s.total_motes_this_run = 100000.0
	s.motes = 500.0
	own(s, &"burn_entry", 3)
	s.unlocked_sections.append("ember_1")
	s.purchased["ember_spark"] = 2
	var report: Dictionary = GameState.bank_embers(true)
	ok(s.motes == 0.0, "run currency clears")
	ok(not s.purchased.has("burn_entry"), "the base tree unbuilds")
	ok(int(s.purchased.get("ember_spark", 0)) == 2, "ember nodes persist")
	ok(s.ember_count == 1 and s.embers > 0.0, "embers bank")
	ok(s.shields == Stats.max_shields, "shields come back")
	ok(float(report["gained"]) > 0.0, "report is populated")

func test_each_prestige_unlocks_a_new_section() -> void:
	var s := fresh()
	var seen: Dictionary = {}
	for _i in range(4):
		var sec: StringName = GameState.next_section()
		ok(sec != &"" and not seen.has(sec), "a fresh section each cycle")
		seen[sec] = true
		s.unlocked_sections.append(String(sec))

func test_field_gets_denser_each_cycle() -> void:
	var s := fresh()
	var first: float = Spawning.spawn_interval(50.0)
	s.ember_count = 5
	ok(Spawning.spawn_interval(50.0) < first, "a darker, denser field each time")

func test_save_round_trip_preserves_state() -> void:
	var s := fresh()
	s.motes = 1234.5
	s.embers = 9.0
	s.ember_count = 2
	s.t = 456.0
	s.shields = 2
	s.purchased["burn_entry"] = 4
	s.unlocked_sections = PackedStringArray(["ember_1"])
	s.contacts.append(Contact.make(3, Vector2(200.0, 100.0), 20.0))

	var restored := GameStateData.new()
	SaveManager.deserialize(SaveManager.serialize(s), restored)
	near(restored.motes, 1234.5, 1e-4, "motes")
	near(restored.embers, 9.0, 1e-4, "embers")
	ok(restored.ember_count == 2, "cycle count")
	ok(restored.shields == 2, "shields")
	ok(int(restored.purchased["burn_entry"]) == 4, "purchases")
	ok(restored.contacts.size() == 1 and restored.contacts[0].tier == 3, "contacts")

func test_migration_from_version_one() -> void:
	var s := fresh()
	s.motes = 777.0
	s.purchased["shroud_entry"] = 2
	var v1: Dictionary = SaveManager.serialize(s)
	v1["version"] = 1
	v1.erase("unlocked_sections")
	v1.erase("wildfire_lum")
	var migrated: Dictionary = SaveManager.migrate(v1)
	ok(int(migrated["version"]) == Constants.SAVE_VERSION, "migrated to current")
	ok(migrated.has("unlocked_sections") and migrated.has("wildfire_lum"),
		"v1 -> v2 filled the new fields")
	var restored := GameStateData.new()
	SaveManager.deserialize(migrated, restored)
	near(restored.motes, 777.0, 1e-4, "no state lost")
	var current: Dictionary = SaveManager.serialize(s)
	ok(SaveManager.migrate(current).hash() == current.hash(),
		"current saves pass through untouched")
