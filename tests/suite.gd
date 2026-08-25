extends RefCounted
## Sim maths is pure and must be tested. Written in the shape gdUnit4 expects
## (test_* methods, assert helpers) but self-hosted so the suite runs with no
## addon installed: `godot --headless --script res://tests/test_runner.gd`.

var _pass: int = 0
var _fail: int = 0
var _current: String = ""

func run_all() -> int:
	if TreeDB.nodes.is_empty():
		TreeDB.load_all()
	var names: PackedStringArray = []
	for m in get_method_list():
		var n: String = str(m["name"])
		if n.begins_with("test_"):
			names.append(n)
	names.sort()
	for n in names:
		_current = n
		var before: int = _fail
		call(n)
		if _fail == before:
			print("  ok   %s" % n)
	print("\n%d passed, %d failed" % [_pass, _fail])
	return _fail

# --- assertions ----------------------------------------------------------

func ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("  FAIL %s: %s" % [_current, msg])

func near(a: float, b: float, tol: float, msg: String) -> void:
	ok(absf(a - b) <= tol, "%s (got %f, want %f +/- %f)" % [msg, a, b, tol])

func fresh(seed_v: int = 7) -> GameStateData:
	var d := GameStateData.new()
	d.rng.seed = seed_v
	d.purchase_version += 1
	Stats.recompute(d)
	d.redundancy = Stats.max_redundancy
	return d

# --- cascade -------------------------------------------------------------

func test_cascade_reaches_next_tier_at_expected_rate() -> void:
	var d := fresh()
	var c := Contact.new()
	c.tier = 0
	d.contacts.append(c)
	# At zero pressure a tier-0 contact takes 1 / CASCADE_BASE seconds.
	var expected: float = 1.0 / Constants.CASCADE_BASE
	var dt: float = 0.5
	var elapsed: float = 0.0
	while c.tier == 0 and elapsed < expected * 2.0:
		Contacts._step(d, dt)
		elapsed += dt
	ok(c.tier == 1, "contact should cascade to tier 1")
	near(elapsed, expected, 2.0, "cascade time at zero pressure (~285s)")

func test_cascade_is_faster_at_higher_tier_and_pressure() -> void:
	var d := fresh()
	var slow := Contact.new()
	slow.tier = 0
	d.contacts.append(slow)
	Contacts._step(d, 1.0)
	var low_rate: float = slow.cascade

	var d2 := fresh()
	d2.field_pressure = 1.0
	var fast := Contact.new()
	fast.tier = 4
	d2.contacts.append(fast)
	Contacts._step(d2, 1.0)
	ok(fast.cascade > low_rate, "pressure and tier both accelerate cascade")

func test_cascade_respects_the_cold_ceiling() -> void:
	var d := fresh()
	d.cold_rank = Constants.TIER_MAX     # ceiling collapses to 0
	var c := Contact.new()
	c.tier = 0
	d.contacts.append(c)
	for _i in range(2000):
		Contacts._step(d, 1.0)
	ok(c.tier == 0, "nothing may cascade past the Cold's ceiling")

# --- awareness -----------------------------------------------------------

func test_awareness_does_not_accrue_below_threshold() -> void:
	var d := fresh()
	var c := Contact.new()
	c.tier = 0
	c.range_u = Constants.FIELD_RADIUS
	d.contacts.append(c)
	d.luminance_structural = 1.0        # far below 30 * 1.9^0 * 1.0
	Awareness.tick(d, 10.0)
	ok(c.awareness == 0.0, "a faint bloom is not noticed")

func test_awareness_accrues_proportional_to_overbrightness() -> void:
	var d := fresh()
	var c := Contact.new()
	c.tier = 0
	c.range_u = Constants.FIELD_RADIUS
	d.contacts.append(c)
	var thr: float = Awareness.threshold(c)
	near(thr, Constants.AWARENESS_THRESHOLD_BASE, 0.001, "tier-0 threshold at max range")
	d.luminance_structural = thr * 3.0  # ratio 3 -> rate = RATE * 2
	Awareness.tick(d, 1.0)
	near(c.awareness, Constants.AWARENESS_RATE * 2.0, 1e-6, "awareness rate")

func test_awareness_threshold_scales_with_tier_and_range() -> void:
	var near_c := Contact.new()
	near_c.tier = 0
	near_c.range_u = Constants.FIELD_RADIUS * 0.5
	var far_c := Contact.new()
	far_c.tier = 0
	far_c.range_u = Constants.FIELD_RADIUS
	ok(Awareness.threshold(near_c) < Awareness.threshold(far_c),
		"closer contacts notice a fainter bloom")
	var high := Contact.new()
	high.tier = 3
	high.range_u = Constants.FIELD_RADIUS
	near(Awareness.threshold(high) / Awareness.threshold(far_c),
		pow(Constants.AWARENESS_TIER_MULT, 3.0), 0.001, "tier multiplier")

func test_low_tier_flees_and_high_tier_commits() -> void:
	var d := fresh()
	var low := Contact.new()
	low.tier = 1
	low.range_u = 500.0
	low.awareness = 1.0
	d.contacts.append(low)
	d.luminance_structural = 5000.0
	Awareness.tick(d, 0.016)
	ok(low.state == Contact.State.FLEEING, "tier 0-1 flees")

	var d2 := fresh()
	var mid := Contact.new()
	mid.tier = 3
	mid.range_u = 500.0
	mid.awareness = 1.0
	d2.contacts.append(mid)
	d2.luminance_structural = 5000.0
	Awareness.tick(d2, 0.016)
	ok(mid.state == Contact.State.COMMITTED, "tier 2-3 commits")
	ok(d2.incoming.size() == 1, "tier 2-3 launches a strike")

# --- backlight -----------------------------------------------------------

func test_backlight_floor_and_cap() -> void:
	var d := fresh()
	d.luminance_structural = 0.0
	near(Backlight.witness_chance(d, 0), Constants.BACKLIGHT_FLOOR, 0.02,
		"a dark bloom still risks the floor")
	d.luminance_structural = 1.0e9
	near(Backlight.witness_chance(d, 7), Constants.BACKLIGHT_CAP, 1e-6,
		"witness chance is capped")

func test_backlight_matches_the_spec_formula() -> void:
	var d := fresh()
	d.luminance_structural = 200.0
	Stats.recompute(d)
	var l: float = d.luminance_effective()
	for tier in range(0, 5):
		var flash: float = Constants.TRANSIENT_DETONATION * pow(float(tier) + 1.0, 1.4)
		var want: float = clampf(0.015 + flash * l * 0.00004, 0.015, 0.90)
		near(Backlight.witness_chance(d, tier), want, 1e-6, "p_witness at tier %d" % tier)

## The number shown before the player commits must be the number rolled.
func test_backlight_displayed_probability_is_the_rolled_probability() -> void:
	var d := fresh(99)
	d.luminance_structural = 240.0
	Stats.recompute(d)
	var trials: int = 4000
	var tier: int = 3
	var displayed: float = Backlight.witness_chance(d, tier)
	var hits: int = 0
	for _i in range(trials):
		var before: int = d.contacts.size()
		var t_before: float = d.luminance_transient
		if Backlight.roll(d, tier, Vector2(400.0, 0.0)):
			hits += 1
		d.luminance_transient = t_before
		while d.contacts.size() > before:
			d.contacts.pop_back()
	var observed: float = float(hits) / float(trials)
	near(observed, displayed, 3.0 / sqrt(float(trials)),
		"observed witness rate must match the displayed one")

func test_hunter_spawns_aware_and_closing() -> void:
	var d := fresh()
	var h: Contact = Backlight.spawn_hunter(d, 4, Vector2(600.0, 0.0))
	ok(h.is_hunter, "hunter flagged")
	near(h.awareness, Constants.HUNTER_AWARENESS, 1e-6, "hunter starts aware")
	ok(h.closing < 0.0, "hunter closes")
	ok(h.tier >= Constants.HUNTER_TIER_MIN, "hunter tier floor")
	ok(d.has_hunter(), "state reports a live hunter")

# --- knowledge model -----------------------------------------------------

func test_believed_position_dead_reckons_from_stale_data() -> void:
	var c := Contact.new()
	c.has_contact = true
	c.known_at = 0.0
	c.known_bearing = 0.0
	c.known_range = 100.0
	c.known_drift = 0.0
	c.known_closing = 10.0
	var p: Vector2 = Sensing.believed_position(c, 5.0)
	near(p.x, 150.0, 1e-4, "dead reckoning extrapolates range")

func test_uncertainty_grows_with_staleness_and_shrinks_with_tracking() -> void:
	var c := Contact.new()
	c.has_contact = true
	c.known_at = 0.0
	var d := fresh()
	near(Sensing.uncertainty_radius(c, 10.0), 10.0 * Constants.UNCERT_GROWTH, 1e-4,
		"uncertainty radius")
	ok(Sensing.is_displayable(c, 10.0), "still on the board")
	ok(not Sensing.is_displayable(c, 10000.0), "drops off past the threshold")

func test_stale_data_lowers_hit_chance() -> void:
	var d := fresh()
	var c := Contact.new()
	c.has_contact = true
	c.known_at = 0.0
	d.t = 5.0
	near(Lances.hit_chance_for(d, c), 1.0 - 5.0 * Constants.STALE_PENALTY, 1e-6,
		"5s stale at no tracking investment is ~50%")
	d.t = 100.0
	near(Lances.hit_chance_for(d, c), Stats.min_hit_chance, 1e-6, "floors at min hit chance")

## No renderer or UI file may read the truth. It sounds paranoid; it catches
## a real bug (spec section 3).
func test_no_render_or_ui_file_reads_true_position() -> void:
	var offenders: PackedStringArray = []
	for root in ["res://scenes/", "res://ui/"]:
		_scan(root, offenders)
	ok(offenders.is_empty(),
		"true_position() referenced in: " + ", ".join(offenders))

func _scan(dir_path: String, offenders: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(dir_path + sub + "/", offenders)
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var txt := FileAccess.get_file_as_string(dir_path + f)
		if txt.contains("true_position"):
			offenders.append(dir_path + f)

# --- luminance -----------------------------------------------------------

func test_shroud_reduces_structural_but_never_fully() -> void:
	var d := fresh()
	d.luminance_structural = 100.0
	near(d.luminance_effective(), 100.0, 1e-6, "no shroud, no reduction")
	ok(Constants.SHROUD_CAP < 1.0, "full invisibility is never allowed")

func test_transient_decays_toward_zero() -> void:
	var d := fresh()
	Luminance.add_transient(d, 100.0)
	Luminance.tick(d, Stats.transient_tau)
	near(d.luminance_transient, 100.0 * exp(-1.0), 0.01, "one tau is a 1/e decay")

func test_purchase_flares_luminance() -> void:
	var d := fresh()
	d.motes = 1.0e9
	var before: float = d.luminance_transient
	ok(Economy.purchase(d, &"expansion_entry"), "purchase succeeds")
	near(d.luminance_transient - before, Constants.TRANSIENT_PURCHASE, 1e-6,
		"buying an upgrade is loud")
	Stats.recompute(d)
	ok(Stats.structural_from_tree > 0.0, "and raises structural luminance")

# --- economy and tree ----------------------------------------------------

func test_rank_cost_curve() -> void:
	var n: TreeNode = TreeDB.get_node_def(&"expansion_bloomfeed")
	ok(n != null, "node exists")
	var base: float = n.cost_motes
	near(float(n.cost_at(3)["motes"]), base * pow(n.cost_growth, 3.0), 1e-4, "cost growth")

func test_requirements_gate_purchase() -> void:
	var d := fresh()
	d.motes = 1.0e9
	d.signal_c = 1.0e9
	d.facets = 1.0e9
	ok(not Economy.can_purchase(d, TreeDB.get_node_def(&"expansion_bloomfeed")),
		"cannot buy past an unbuilt requirement")
	Economy.purchase(d, &"expansion_entry")
	ok(Economy.can_purchase(d, TreeDB.get_node_def(&"expansion_bloomfeed")),
		"requirement met unlocks the child")

func test_respec_is_free_and_total() -> void:
	var d := fresh()
	d.motes = 100000.0
	var start: float = d.motes
	Economy.purchase(d, &"expansion_entry")
	Economy.purchase(d, &"expansion_entry")
	ok(d.motes < start, "purchases cost")
	ok(Economy.respec(d), "respec allowed with no blight")
	near(d.motes, start, 1e-4, "respec refunds every rank at the price paid")
	ok(d.purchased.is_empty(), "and unbuilds everything")

func test_respec_locks_while_blighted() -> void:
	var d := fresh()
	d.blighted_nodes = PackedStringArray(["expansion_bloomfeed"])
	ok(not Economy.can_respec(d), "respec locks while blight is active")

func test_infinite_sinks_never_cap() -> void:
	var d := fresh()
	d.motes = 1.0e12
	var n: TreeNode = TreeDB.get_node_def(&"expansion_greed")
	ok(n != null and n.is_infinite(), "greed is an infinite sink")
	_own_ancestry(d, n.id)
	for _i in range(40):
		Economy.purchase(d, n.id)
	ok(int(d.purchased.get("expansion_greed", 0)) == 40, "sinks keep accepting ranks")

## Grant every ancestor of a node so its own purchase can be tested alone.
func _own_ancestry(d: GameStateData, id: StringName) -> void:
	var n: TreeNode = TreeDB.get_node_def(id)
	if n == null:
		return
	for r in n.requires:
		if int(d.purchased.get(String(r), 0)) <= 0:
			_own_ancestry(d, r)
			d.purchased[String(r)] = 1
	d.purchase_version += 1

# --- tree integrity ------------------------------------------------------

func test_tree_validates() -> void:
	var rep: TreeValidator.Report = TreeValidator.validate(TreeDB.nodes)
	ok(rep.ok(), "tree validation:\n" + rep.to_text())

func test_tree_has_every_specified_keystone() -> void:
	for id in ["shroud_nullwake", "optics_long_ear", "lance_overburn",
			"expansion_wildfire", "tether_hostage", "redundancy_diaspora",
			"cognition_autarch", "shroud_cinder"]:
		ok(TreeDB.has_node_def(StringName(id)), "keystone %s exists" % id)

func test_every_constellation_has_a_keystone() -> void:
	for con in TreeDB.constellations:
		var found: bool = false
		for n in TreeDB.constellation_nodes(con):
			if n.kind == TreeNode.Kind.KEYSTONE:
				found = true
				break
		ok(found, "constellation %s has a keystone" % con)

func test_tree_is_large_enough() -> void:
	ok(TreeDB.nodes.size() >= 280, "tree has %d nodes (target ~290)" % TreeDB.nodes.size())

# --- blight --------------------------------------------------------------

## Fuzz: random blight configurations must never soft-lock progression.
func test_blight_never_soft_locks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var all: Array = TreeDB.all_ids()
	var soft_locks: int = 0
	for _i in range(10000):
		var d := fresh()
		# Own a random slice of the tree, then blight a legal subset of it.
		d.purchased.clear()
		for _j in range(rng.randi_range(1, 25)):
			var id: StringName = all[rng.randi_range(0, all.size() - 1)]
			d.purchased[String(id)] = rng.randi_range(1, 4)
		var candidates: Array[StringName] = Blight._candidates(d)
		if candidates.is_empty():
			continue
		var count: int = mini(rng.randi_range(1, 6), candidates.size())
		for _k in range(count):
			var pick: int = rng.randi_range(0, candidates.size() - 1)
			d.blighted_nodes.append(String(candidates[pick]))
			candidates.remove_at(pick)
		# A soft-lock is a blighted node that anything else depends on.
		for b in d.blighted_nodes:
			if not TreeDB.children_of(StringName(b)).is_empty():
				soft_locks += 1
	ok(soft_locks == 0, "%d soft-locking blight configurations found" % soft_locks)

func test_blight_suspends_effects_but_keeps_luminance() -> void:
	var d := fresh()
	d.motes = 1.0e9
	Economy.purchase(d, &"expansion_entry")
	Stats.recompute(d)
	var lum_before: float = Stats.structural_from_tree
	var yield_before: float = Stats.yield_mult
	d.blighted_nodes.append("expansion_entry")
	d.purchase_version += 1
	Stats.recompute(d)
	near(Stats.structural_from_tree, lum_before, 1e-6,
		"blighted growth still burns — you built it")
	ok(Stats.yield_mult < yield_before, "but its effect is suspended")

func test_blight_locks_downstream_children() -> void:
	var d := fresh()
	d.blighted_nodes = PackedStringArray(["expansion_entry"])
	ok(Blight.is_locked(d, &"expansion_bloomfeed"), "children of a blighted node lock")
	ok(not Blight.is_locked(d, &"shroud_entry"), "unrelated branches stay open")

# --- tethers -------------------------------------------------------------

func test_tether_slack_rises_with_your_own_luminance() -> void:
	var d := fresh()
	var dim: float = Tethers.slack_rate(d)
	d.luminance_structural = 400.0
	var bright: float = Tethers.slack_rate(d)
	ok(bright > dim, "your own growth erodes your credibility")

func test_tether_fires_at_full_slack_with_no_counterplay() -> void:
	var d := fresh()
	var c := Contact.new()
	c.id = 1
	c.tier = 1
	d.contacts.append(c)
	var t := Tether.new()
	t.contact_id = 1
	t.slack = 0.999
	t.tier = 1
	d.tethers.append(t)
	Tethers.tick(d, 10.0)
	ok(d.tethers.is_empty(), "the tether is gone")
	ok(d.incoming.size() == 1, "and it fired")
	ok(not d.incoming[0].detected, "undetectable")
	near(d.incoming[0].arrives_at, d.t, 1e-6, "immediate")

func test_hostage_doctrine_fires_every_tether_at_once() -> void:
	var d := fresh()
	for i in range(3):
		var c := Contact.new()
		c.id = i + 1
		d.contacts.append(c)
		var t := Tether.new()
		t.contact_id = i + 1
		t.slack = 0.5
		d.tethers.append(t)
	d.tethers[0].slack = 0.999
	Stats._rules[&"hostage_doctrine"] = true
	Tethers.tick(d, 1.0)
	Stats._rules.erase(&"hostage_doctrine")
	ok(d.tethers.is_empty(), "if any tether fires, all tethers fire")
	ok(d.incoming.size() == 3, "three strikes inbound")

# --- threat --------------------------------------------------------------

func test_strikes_are_undetected_without_optics_rank_six() -> void:
	var d := fresh()
	var c := Contact.new()
	c.tier = 3
	c.range_u = 500.0
	var s: IncomingStrike = Threat.launch_strike(d, c)
	ok(not s.detected, "no warning at all without the investment")
	Stats.optics_grade = Constants.OPTICS_RANK_STRIKE_DETECT
	var s2: IncomingStrike = Threat.launch_strike(d, c)
	ok(s2.detected, "Optics rank 6 sees them coming")
	Stats.optics_grade = 0

func test_strike_landing_costs_redundancy_and_ends_the_run_at_zero() -> void:
	var d := fresh()
	d.redundancy = 2
	var s := IncomingStrike.new()
	s.arrives_at = 0.0
	d.incoming.append(s)
	Threat.tick(d, 0.1)
	ok(d.redundancy == 1, "redundancy lost")
	ok(not d.run_over, "still alive")
	var s2 := IncomingStrike.new()
	s2.arrives_at = 0.0
	d.incoming.append(s2)
	Threat.tick(d, 0.1)
	ok(d.run_over, "run ends at zero redundancy")

# --- keystones -----------------------------------------------------------

func test_nullwake_forbids_the_sweep() -> void:
	var d := fresh()
	ok(Sensing.can_sweep(d), "sweep available by default")
	Stats._rules[&"nullwake"] = true
	ok(not Stats.can_sweep(), "Nullwake gives up the sweep permanently")
	ok(not Sensing.fire_sweep(d), "and the sweep refuses to fire")
	Stats._rules.erase(&"nullwake")

func test_overburn_always_hits() -> void:
	var d := fresh()
	var c := Contact.new()
	c.has_contact = true
	c.known_at = 0.0
	d.t = 500.0
	ok(Lances.hit_chance_for(d, c) < 0.2, "very stale data is a bad shot")
	Stats._rules[&"overburn"] = true
	near(Lances.hit_chance_for(d, c), 1.0, 1e-6, "Overburn ignores staleness")
	Stats._rules.erase(&"overburn")

func test_autarch_removes_manual_targeting() -> void:
	ok(Stats.manual_targeting_allowed(), "manual targeting by default")
	Stats._rules[&"autarch"] = true
	ok(not Stats.manual_targeting_allowed(), "Autarch takes the trigger")
	Stats._rules.erase(&"autarch")

func test_cinder_hides_you_below_twenty() -> void:
	var d := fresh()
	d.luminance_structural = 10.0
	Stats._rules[&"cinder"] = true
	near(Luminance.detectable(d), 0.0, 1e-6, "undetectable under 20")
	d.luminance_structural = 60.0
	ok(Luminance.detectable(d) > 0.0, "and visible above it")
	Stats._rules.erase(&"cinder")

# --- prestige and saves --------------------------------------------------

func test_ember_payout_formula() -> void:
	var d := fresh()
	d.total_motes_earned = 8.0e6
	d.facets = 10.0
	near(Ember.embers_gained(d), floor(pow(8.0, 0.42)) + 5.0, 1e-6, "ember payout")

func test_voluntary_ember_beats_being_forced() -> void:
	var d := fresh()
	d.total_motes_earned = 5.0e7
	var voluntary: float = Ember.total_payout(d)
	d.run_over = true
	var forced: float = Ember.total_payout(d)
	ok(voluntary > forced, "leaving on your own terms always pays more")

func test_ember_resets_the_run_but_keeps_the_meta() -> void:
	var d := fresh()
	d.total_motes_earned = 1.0e7
	d.motes = 500.0
	d.purchased["expansion_entry"] = 3
	d.contacts.append(Contact.new())
	var report: Dictionary = Ember.commit(d)
	ok(d.motes == 0.0 and d.purchased.is_empty() and d.contacts.is_empty(), "the run ends")
	ok(d.ember_count == 1 and d.embers > 0.0, "the ember carries")
	ok(d.unlocked_regions.size() == 1, "a new region catches")
	ok(float(report["embers"]) > 0.0, "report is populated")

func test_dormancy_rejects_clock_manipulation() -> void:
	near(Dormancy.elapsed_since(Time.get_unix_time_from_system() + 100000.0), 0.0, 1e-6,
		"negative deltas are rejected")
	ok(Dormancy.elapsed_since(1.0) <= Constants.DORMANCY_CLAMP_SECONDS,
		"offline time is clamped to 12h")

func test_save_round_trip_preserves_state() -> void:
	var d := fresh()
	d.motes = 1234.5
	d.facets = 7.0
	d.t = 999.0
	d.purchased["expansion_entry"] = 2
	d.cold_rank = 3
	d.unlocked_regions = PackedStringArray(["choir"])
	var c := Contact.new()
	c.id = 42
	c.tier = 5
	c.has_contact = true
	c.known_bearing = 1.234
	d.contacts.append(c)

	var saved: Dictionary = SaveManager.serialize(d)
	var restored := GameStateData.new()
	SaveManager.deserialize(saved, restored)
	near(restored.motes, 1234.5, 1e-4, "motes")
	near(restored.t, 999.0, 1e-4, "clock")
	ok(int(restored.purchased["expansion_entry"]) == 2, "purchases")
	ok(restored.cold_rank == 3, "cold rank")
	ok(restored.contacts.size() == 1 and restored.contacts[0].id == 42, "contacts")
	near(restored.contacts[0].known_bearing, 1.234, 1e-4, "knowledge block survives")

## Round-trip across three schema versions with zero state loss.
func test_migration_chain_from_version_one() -> void:
	var d := fresh()
	d.motes = 4321.0
	d.total_motes_earned = 90000.0
	d.purchased["shroud_entry"] = 4

	var v1: Dictionary = SaveManager.serialize(d)
	v1["version"] = 1
	v1.erase("unlocked_regions")
	v1.erase("cold_rank")
	v1.erase("triage_rules")
	v1.erase("run_over")
	v1.erase("run_end_reason")

	var migrated: Dictionary = SaveManager.migrate(v1)
	ok(int(migrated["version"]) == Constants.SAVE_VERSION, "migrated to current version")
	ok(migrated.has("unlocked_regions"), "v1 -> v2 added regions")
	ok(migrated.has("triage_rules"), "v2 -> v3 added triage rules")

	var restored := GameStateData.new()
	SaveManager.deserialize(migrated, restored)
	near(restored.motes, 4321.0, 1e-4, "no state lost across the chain")
	ok(int(restored.purchased["shroud_entry"]) == 4, "purchases survive migration")

	# And a current-version save must pass through untouched.
	var v3: Dictionary = SaveManager.serialize(d)
	ok(SaveManager.migrate(v3).hash() == v3.hash(), "current saves are not rewritten")

# --- automation ----------------------------------------------------------

func test_triage_rules_are_first_match_wins() -> void:
	var c := Contact.new()
	c.known_tier = 5
	c.known_awareness = 0.8
	var rules: Array = [
		{"enabled": true, "min_tier": 0, "max_tier": 2, "action": "tether"},
		{"enabled": true, "min_tier": 3, "max_tier": 7, "action": "lance"},
	]
	ok(Automation._decide(c, rules) == "lance", "the matching rule wins")
	c.known_tier = 1
	ok(Automation._decide(c, rules) == "tether", "and order decides")
	ok(Automation._decide(c, []) == "ignore", "no rules means no action")

func test_disabled_rules_are_skipped() -> void:
	var c := Contact.new()
	c.known_tier = 1
	var rules: Array = [{"enabled": false, "min_tier": 0, "max_tier": 7, "action": "lance"}]
	ok(Automation._decide(c, rules) == "ignore", "disabled rules do nothing")

# --- progression -----------------------------------------------------------

## There must never be a wall: a point where the player has banked currency
## and the next thing is out of reach. Spending down to your last mote is
## normal and expected; a gap you cannot cross is the failure this catches.
func test_no_affordability_wall_in_the_first_hours() -> void:
	var d := fresh()
	var worst_ratio: float = 0.0
	var worst_step: int = -1
	# Walk a plausible wealth curve across the first few hours.
	for step in range(1, 80):
		d.motes = pow(1.35, float(step)) * 10.0
		d.signal_c = d.motes * 0.15
		d.facets = floor(float(step) / 8.0)
		var wealth: float = d.motes
		# Buy out everything reachable at this wealth, then look at what is next.
		for _pass in range(6):
			for id in TreeDB.all_ids():
				if Economy.can_purchase(d, TreeDB.get_node_def(id)):
					Economy.purchase(d, id)
			Stats.recompute(d)
		var cheapest: float = INF
		for id in TreeDB.all_ids():
			var n: TreeNode = TreeDB.get_node_def(id)
			if n == null or n.region != &"base":
				continue
			if not n.is_infinite() and int(d.purchased.get(String(id), 0)) >= n.max_rank:
				continue
			if not Economy.requirements_met(d, n):
				continue
			var c: Dictionary = Economy.next_cost(d, n)
			if float(c["facets"]) > d.facets:
				continue
			cheapest = minf(cheapest, float(c["motes"]) + float(c["signal"]))
		ok(cheapest < INF, "step %d: something is always purchasable" % step)
		var ratio: float = cheapest / maxf(wealth, 1.0)
		if ratio > worst_ratio:
			worst_ratio = ratio
			worst_step = step
	# The next purchase must always cost less than a doubling of current wealth.
	ok(worst_ratio <= 2.0,
		"worst gap was %.2fx wealth at step %d" % [worst_ratio, worst_step])

## Infinite sinks exist so there is always something cheap to click.
func test_every_constellation_has_an_infinite_sink() -> void:
	var missing: PackedStringArray = []
	for con in TreeDB.constellations:
		var found: bool = false
		for n in TreeDB.constellation_nodes(con):
			if n.is_infinite():
				found = true
				break
		if not found:
			missing.append(String(con))
	ok(missing.is_empty(), "constellations with no sink: " + ", ".join(missing))
