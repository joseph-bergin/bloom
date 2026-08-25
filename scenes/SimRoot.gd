extends Node
## The only Node that touches the simulation.

func _physics_process(delta: float) -> void:
	GameState.tick(delta)
