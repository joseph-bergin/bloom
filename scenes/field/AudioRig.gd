extends Node2D
## Lives in field space so AudioStreamPlayer2D children pan correctly
## relative to the listener at the origin.

func _ready() -> void:
	var listener := AudioListener2D.new()
	add_child(listener)
	listener.make_current()
