extends Node2D

@export var step_size: int = 64

func move_forward() -> void:
	print("PLAYER MOVING")
	position.x += step_size
