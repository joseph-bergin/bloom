extends Node
## The state and the tick.

var s: GameStateData = GameStateData.new()
var paused: bool = false
var _hitstop: float = 0.0

func _ready() -> void:
	s.rng.randomize()
	Stats.recompute(s)
	s.shields = Stats.max_shields

func _physics_process(delta: float) -> void:
	if paused or s.run_over:
		return
	if _hitstop > 0.0:
		_hitstop -= delta
		return
	if s.purchase_version != Stats.cached_version:
		Stats.recompute(s)
	s.t += delta

	Luminance.tick(s, delta)
	Spawning.tick(s, delta)
	Field.move_contacts(s, delta)
	Turret.tick(s, delta)
	Turret.move_projectiles(s, delta)
	Field.check_breaches(s)

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _process(_delta: float) -> void:
	# Douse is held, not toggled.
	s.dousing = Input.is_action_pressed("douse") and not paused and not s.run_over

# --- purchases -----------------------------------------------------------

func rank_of(id: StringName) -> int:
	return int(s.purchased.get(String(id), 0))

func requirements_met(n: TreeNode) -> bool:
	for r in n.requires:
		if rank_of(r) <= 0:
			return false
	return true

func next_cost(n: TreeNode) -> float:
	return n.cost_at(rank_of(n.id))

func can_purchase(n: TreeNode) -> bool:
	if n == null or s.run_over:
		return false
	if n.section != &"base" and not s.unlocked_sections.has(String(n.section)):
		return false
	if not n.is_infinite() and rank_of(n.id) >= n.max_rank:
		return false
	if not requirements_met(n):
		return false
	return s.motes >= next_cost(n)

## A node is revealed once a requirement is owned; otherwise it silhouettes.
func is_revealed(n: TreeNode) -> bool:
	if n.requires.is_empty() or requirements_met(n):
		return true
	for r in n.requires:
		if rank_of(r) > 0:
			return true
	return false

func purchase(id: StringName) -> bool:
	var n: TreeNode = TreeDB.get_node_def(id)
	if not can_purchase(n):
		return false
	s.motes -= next_cost(n)
	var rank: int = rank_of(id) + 1
	s.purchased[String(id)] = rank
	s.purchase_version += 1
	Stats.recompute(s)
	EventBus.node_purchased.emit(id, rank)
	return true

## Free respec, always. Zero cost, no cooldown.
func respec() -> void:
	for key in s.purchased.keys():
		var n: TreeNode = TreeDB.get_node_def(StringName(str(key)))
		if n == null:
			continue
		for r in range(int(s.purchased[key])):
			s.motes += n.cost_at(r)
	s.purchased.clear()
	s.purchase_version += 1
	s.wildfire_lum = 0.0
	Stats.recompute(s)
	EventBus.respec_performed.emit()

# --- prestige ------------------------------------------------------------

func embers_for(total: float) -> float:
	return floor(sqrt(total / Constants.EMBER_DIVISOR)) * Stats.ember_mult

func embers_on_death() -> float:
	return embers_for(s.total_motes_this_run)

## Retiring early must always beat dying — strictly, at every point on the
## curve. Rounding alone lets the bonus vanish at small payouts, so the
## result is floored at one more than the death payout.
func embers_on_retire() -> float:
	var died: float = embers_on_death()
	return maxf(floor(died * (1.0 + Constants.RETIRE_BONUS)), died + 1.0)

const SECTIONS: Array[StringName] = [&"ember_1", &"ember_2", &"ember_3", &"ember_4"]

func next_section() -> StringName:
	for sec in SECTIONS:
		if not s.unlocked_sections.has(String(sec)):
			return sec
	return &""

func bank_embers(retired: bool) -> Dictionary:
	var gained: float = embers_on_retire() if retired else embers_on_death()
	var section: StringName = next_section()
	var report: Dictionary = {
		"gained": gained, "cycle": s.ember_count + 1,
		"section": String(section), "retired": retired,
		"total_motes": s.total_motes_this_run, "time": s.t,
	}

	s.embers += gained
	s.ember_count += 1
	if section != &"":
		s.unlocked_sections.append(String(section))
		EventBus.section_unlocked.emit(section)

	# Ember nodes persist; everything else resets.
	var kept: Dictionary = {}
	for key in s.purchased.keys():
		var n: TreeNode = TreeDB.get_node_def(StringName(str(key)))
		if n != null and n.branch == &"ember":
			kept[key] = s.purchased[key]
	s.purchased = kept

	s.t = 0.0
	s.motes = 0.0
	s.total_motes_this_run = 0.0
	s.contacts = []
	s.projectiles = []
	s.wildfire_lum = 0.0
	s.spawn_timer = 0.0
	s.fire_timer = 0.0
	s.douse_meter = 1.0
	s.dousing = false
	s.run_over = false
	s.run_end_reason = ""
	s.purchase_version += 1
	Stats.recompute(s)
	s.shields = Stats.max_shields

	EventBus.ember_banked.emit(gained, s.ember_count)
	EventBus.run_started.emit()
	SaveManager.save_game()
	return report

func retire() -> Dictionary:
	return bank_embers(true)

# --- feel ----------------------------------------------------------------

func hitstop(tier: int) -> void:
	_hitstop = maxf(_hitstop, Constants.HITSTOP_SECONDS * (1.0 + float(tier) * 0.15))
