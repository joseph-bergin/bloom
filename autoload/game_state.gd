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
	if paused or s.run_over or s.phase == GameStateData.Phase.UPGRADING:
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
	Levels.tick(s, delta)

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
	if not n.is_infinite() and rank_of(n.id) >= n.max_rank:
		return false
	if not requirements_met(n):
		return false
	return s.motes >= next_cost(n)

## Visible only once the prerequisites are bought. This used to show one
## step past the *buyable* frontier, which meant you could see nodes whose
## parent you had not unlocked yet — the tree spoiled its own shape.
func is_revealed(n: TreeNode) -> bool:
	return rank_of(n.id) > 0 or requirements_met(n)

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

# --- run lifecycle -------------------------------------------------------

## Called when the player is done shopping between levels.
func begin_next_level() -> bool:
	return Levels.begin_next(s)

func upgrading() -> bool:
	return s.phase == GameStateData.Phase.UPGRADING

## A fresh run: the tree unbuilds and the ladder starts over. Nothing carries
## except the best level reached, which is the score.
func restart_run() -> void:
	var best: int = maxi(s.best_level, s.level)
	s.purchased.clear()
	s.motes = 0.0
	s.total_motes_this_run = 0.0
	s.contacts = [] as Array[Contact]
	s.projectiles = [] as Array[Projectile]
	s.wildfire_lum = 0.0
	s.spawn_timer = 0.0
	s.fire_timer = 0.0
	s.douse_meter = 1.0
	s.dousing = false
	s.run_over = false
	s.run_end_reason = ""
	s.t = 0.0
	s.aim_auto = true
	Levels.reset(s)
	s.best_level = best
	s.purchase_version += 1
	Stats.recompute(s)
	s.shields = Stats.max_shields
	SaveManager.save_game()
	EventBus.run_started.emit()

# --- feel ----------------------------------------------------------------

func hitstop(tier: int) -> void:
	_hitstop = maxf(_hitstop, Constants.HITSTOP_SECONDS * (1.0 + float(tier) * 0.15))
