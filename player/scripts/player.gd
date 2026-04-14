extends Node2D

signal lose_triggered(reason: String)

# === player config ===
# movement timing + visual tuning
@export var move_duration: float = 0.3
@export var use_sprite_visual: bool = true
@export var player_texture: Texture2D = preload("res://assets/textures/kenney_isometric-miniature-prototype/Characters/Human/Human_0_Idle0.png")
@export var rotate_sprite_with_facing: bool = false
@export var snap_sprite_to_pixels: bool = true
@export var auto_trim_player_region: bool = true
@export var trim_alpha_padding_px: int = 2
@export var show_player_shadow: bool = false

# optional orientation mapping for incoming JSON _orientation values
# default assumes 0=east, 1=north, 2=west, 3=south
@export var orientation_0_facing: String = "north"
@export var orientation_1_facing: String = "west"
@export var orientation_2_facing: String = "south"
@export var orientation_3_facing: String = "east"

# fallback debug marker colors (used when sprite mode is disabled)
@export var player_color: Color = Color("7a4df3")
@export var player_shadow_color: Color = Color(0, 0, 0, 0.18)

# === player state ===
# logical grid position + facing direction
var grid_x: int = 1
var grid_y: int = 1
var facing: String = "north"
var _trim_region_cache: Dictionary = {}
var _has_lost: bool = false


func _ready() -> void:
	pass


# === level setup ===
# called when a level is loaded
# this file owns player state + player appearance, so setup happens here now
func initialize_from_level(robot_data: Dictionary, world_pos: Vector2) -> void:
	_has_lost = false
	grid_x = robot_data.get("x", 1)
	grid_y = robot_data.get("y", 1)
	
	# Starting numerical player facing
	var start_face: int = robot_data.get("_orientation", 1)
	print("Direction: ", start_face)
	match start_face:
		0:
			facing = "east"
			$AnimatedSprite2D.play("Idle_N")
		1:
			facing = "north"
			$AnimatedSprite2D.play("Idle_E")
		2:
			facing = "west"
			$AnimatedSprite2D.play("Idle_S")
		3:
			facing = "east"
			$AnimatedSprite2D.play("Idle_W")

	position = world_pos


# === world lookup ===
# finds the outer world/view node so the player can ask things like:
# "am i in bounds?" or "where is this tile in world space?"
func _get_world() -> Node:
	var world_root = get_parent()
	if world_root == null:
		return null
	return world_root.get_parent()


# === movement ===
# updates logical grid coords first, then tweens to the matching world position
func move_forward() -> void:
	var world = _get_world()
	var next_x = grid_x
	var next_y = grid_y
	print("Move to:", facing)
	match facing:
		"east":
			next_y -= 1
			$AnimatedSprite2D.play("Run_N")
		"west":
			next_y += 1
			$AnimatedSprite2D.play("Run_W")
		"north":
			next_x += 1  
			$AnimatedSprite2D.play("Run_N")
		"south":
			next_x -= 1  
			$AnimatedSprite2D.play("Run_S")

	# lose if the player attempts to leave the playable floor
	#if world.has_method("is_in_bounds"):
		#if not world.is_in_bounds(next_x, next_y):
			#_trigger_lose("You lose: attempted to move outside the floor.")
			#return
			
	# lose on attempted move through a wall edge
	if world.has_method("is_move_blocked"):
		print(world.is_move_blocked(grid_x,grid_y,facing))
		if world.is_move_blocked(grid_x, grid_y, facing):
			_trigger_lose("You lose: attempted to move through a wall.")
			return

	grid_x = next_x
	grid_y = next_y

	if world.has_method("grid_position"):
		var target_pos: Vector2 = world.grid_position(grid_x, grid_y)
		var tween = create_tween()
		tween.tween_property(self, "position", target_pos, move_duration)
		
	match facing:
		"east":
			$AnimatedSprite2D.play("Idle_E")
		"west":
			$AnimatedSprite2D.play("Idle_W")
		"north":
			$AnimatedSprite2D.play("Idle_N")
		"south":
			$AnimatedSprite2D.play("Idle_S")

	if world.has_method("check_win_condition"):
		world.check_win_condition(grid_x, grid_y)


func _trigger_lose(reason: String) -> void:
	if _has_lost:
		return
	_has_lost = true
	emit_signal("lose_triggered", reason)


# === turning ===
# just changes facing for now
# later could also rotate sprite/marker visually if desired
func turn_left() -> void:
	match facing:
		"east":
			facing = "north"
			$AnimatedSprite2D.play("Idle_N")
		"north":
			facing = "west"
			$AnimatedSprite2D.play("Idle_W")
		"west":
			facing = "south"
			$AnimatedSprite2D.play("Idle_S")
		"south":
			facing = "east"
			$AnimatedSprite2D.play("Idle_E")
	print(facing)

# IMPORTANT: No turn right functions

# === object interaction stubs ===
# world behavior for objects is still placeholder-ish,
# so for now the robot just asks the world if it knows how to handle it
func pick_object() -> void:
	var world = _get_world()
	if world == null:
		return
	if world.has_method("remove_object_at"):
		world.remove_object_at(grid_x, grid_y)


func put_object() -> void:
	var world = _get_world()
	if world == null:
		return
	if world.has_method("place_object_at"):
		world.place_object_at(grid_x, grid_y)
