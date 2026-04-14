extends Node2D

signal level_complete


# === visual config ===
# tweakables so we're not hardcoding mystery numbers all over the place
@export var tile_width: int = 64
@export var tile_height: int = 32

@export var use_tilesheet_floor: bool = true
@export var use_tilesheet_walls: bool = true


@export var grid_color: Color = Color("d0d5c8")
@export var show_grid_overlay: bool = true
@export var wall_color: Color = Color(1, 0, 0, 1)
@export var board_shadow_color: Color = Color(0, 0, 0, 0.14)

# === scene references ===
# all the visual level layers live under WorldRoot
@onready var world_root: Node2D = $WorldRoot
@onready var camera: Camera2D = $Camera2D
@onready var player: Node2D = $WorldRoot/Player
@onready var FloorTiles: TileMapLayer = $WorldRoot/FloorMapLayer
@onready var WallTiles: TileMapLayer = $WorldRoot/WallMapLayer

# CAUTION: Do not change this is to scale to the floor size
const chunk_size = 2

# world data for public functions
var level_data: Dictionary = {}
var world_x_size : int = 10
var world_y_size : int = 10

# === scene lifecycle ===
# runs when this scene is instantiated into the tree
# this scene owns the camera, so it configures it here
func _ready() -> void:
	camera.enabled = true
	camera.make_current()


# ======= MAIN POINT: Build Rendition =======
## Builds a world given that JSON data (format: Reborg)
##
## INPUTS: A dictonary that describe the world (obj:description)
## OUTPUS: A render of the world given by dictionary
func build_level(data: Dictionary) -> void:
	level_data = data
	# IF NEEDED: enforce ordering
	FloorTiles.z_index = 0
	WallTiles.z_index  = 1
	#player.z_index     = 1
	
	# Generate the Floor Grid
	if data.has("cols") and data.has("rows"):
		var cols = int(data["cols"])
		var rows = int(data["rows"])
		
		world_x_size = cols
		world_y_size = rows
		print("Floor: ", cols,"x",rows)
		
		# Create the floor
		_build_floor(cols, rows)
		# Create the wall
		_build_walls(data, cols, rows)
		# Create the player
		_place_player(data, cols, rows)
		# Place goals
		_build_goal_cells(data, cols, rows)
		# Set the camera
		_center_camera(cols, rows)
	else:
		push_warning("JSON loaded, but 'cols' or 'rows' keys were missing!")

# ====== World Rendering Functions ======
## This builds the floor given the grid size
func _build_floor(cols: int,rows: int) -> void:
	# Loop through every x (column) and y (row) to fill the grid
	for x in range(cols):
		for y in range(rows):
			var grid_pos = Vector2i(x, y)
			# Draw your floor tile (Assuming source_id 0 and atlas coords 0,0)
			FloorTiles.set_cell(grid_pos, 8, Vector2i(0, 1))

## This builds the walls given its coordinate and face
func _build_walls(data: Dictionary, cols: int, rows: int) -> void:
	# Define how big each logical cell is in physical tiles
	cols = (cols) * chunk_size
	@warning_ignore("narrowing_conversion")
	rows = (rows+0.5) * chunk_size
	print("Scaled size: ", cols, ",", rows)

	# Generate the walls
	# The dictonary is formated as:
	#		 ["x-coords","y-coords"] : ["direction"]
	
	if data.has("walls"):
		var walls = Dictionary(data["walls"])
		for keys in walls:
			# Obtain wall position
			var wall_coords = keys.split(",")
			var x_coords = int(wall_coords[0])
			var y_coords = int(wall_coords[1])
			var grid_pos = Vector2((x_coords)*chunk_size - 1, rows - (y_coords)*chunk_size)
			
			# Obtain wall direction
			# CRITICAL: Reborg world only utilizes "east" and "north"
			# - This is optimize for Reborg world editor
			# - An array of size of 1, is either a wall facing "east" and "north"
			# - An array of size of 2, is a corner betwenn  "east" and "north" 
			var wall_directions = walls[keys]
			if wall_directions.size() == 1:
				# ONLY EAST WALL
				if wall_directions[0] == "east":
					WallTiles.set_cell(grid_pos, 44, Vector2i(6,1))
					
					grid_pos = Vector2(grid_pos[0], grid_pos[1]+1)
					WallTiles.set_cell(grid_pos, 44, Vector2i(6,1))
				# ONLY NORTH WALL
				else:
					
					WallTiles.set_cell(grid_pos, 44, Vector2i(4,1))
					
					grid_pos = Vector2(grid_pos[0]-1, grid_pos[1])
					WallTiles.set_cell(grid_pos, 44, Vector2i(4,1))
			# ONLY CORNER WALL
			else:
				var temp_pos = grid_pos
				grid_pos = Vector2(temp_pos[0]-1, temp_pos[1])
				WallTiles.set_cell(grid_pos, 44, Vector2i(4,1))
				
				grid_pos = Vector2(temp_pos[0], temp_pos[1])
				WallTiles.set_cell(grid_pos, 44, Vector2i(6,0))
				
				grid_pos = Vector2(temp_pos[0], temp_pos[1]+1)
				WallTiles.set_cell(grid_pos, 44, Vector2i(6,1))
				
			#Add a corner
			#find all cell that id
			var all_floor_cells: Array[Vector2i] = WallTiles.get_used_cells_by_id(44, Vector2i(4,1))
	
			# You can now loop through this array directly
			for cell in all_floor_cells:
				var other_wall = WallTiles.get_cell_atlas_coords(Vector2i(cell[0]-1,cell[1]-1))
				if other_wall == Vector2i(6,1):
					WallTiles.set_cell(Vector2i(cell[0]-1,cell[1]), 44, Vector2i(2,2))
	else:
		push_warning("JSON loaded, but 'walls' keys were missing!")

func _build_goal_cells(data: Dictionary, cols: int, rows: int) -> void:
	if not data.has("goal"):
		return
	var goal = data["goal"]
	if goal.has("possible_final_positions"):
		for pos in goal["possible_final_positions"]:
			if typeof(pos) == TYPE_ARRAY and pos.size() >= 2:
				var grid_pos = Vector2i((pos[0]) - 1, rows - (pos[1]))
				print(grid_pos)
				# Draw your floor tile (Assuming source_id 0 and atlas coords 0,0)
				FloorTiles.set_cell(grid_pos, 8, Vector2i(0, 0))
	if goal.has("position"):
		var pos = goal["position"]
		if typeof(pos) == TYPE_DICTIONARY:
			var grid_pos = Vector2i((int(pos.get("x", -1)) - 1), rows - (int(pos.get("y", -1))))
			print(grid_pos)
			# Draw your floor tile (Assuming source_id 0 and atlas coords 0,0)
			FloorTiles.set_cell(grid_pos, 8, Vector2i(0, 0))


func _is_goal_tile(gx: int, gy: int) -> void:
	pass
	#return goal_cells.has("%d,%d" % [gx, gy])

## Define and places the player at starting position
func _place_player(data: Dictionary, cols: int, rows: int) -> void:
	if data.has("robots"):

		var robots = level_data["robots"]
		if robots.is_empty():
			push_warning("JSON loaded, but 'robots' is empty!")
		else:
			# Determine the starting position given by the JSON
			var robot_info = robots[0]
			var innit_x: int = robot_info.get("x", 1)
			var innit_y: int = robot_info.get("y", 1)
			# Move to desired position
			# CAUTION: mantain chunk_size since floor are scale 2x
			var center_physical_x = ((cols * chunk_size) - (((cols * chunk_size)+2) - innit_x * chunk_size))
			var center_physical_y = ((rows * chunk_size) - (innit_y * chunk_size) + 2)
			
			# 5. Ask the TileMapLayer where that specific grid tile is in actual pixels
			var grid_pos = FloorTiles.map_to_local(Vector2i(center_physical_x, center_physical_y))
			# If offset is needed
			@warning_ignore("narrowing_conversion")
			var pixel_pos = Vector2i(grid_pos[0],grid_pos[1])
			
			# 6. Move the CharacterBody2D to those exact pixels!
			print("Start Position: ", innit_x, ",", innit_y, " Grid Postion: ", grid_pos, " Pixel Position: ", pixel_pos)
			player.initialize_from_level(robot_info, pixel_pos)
			#player.global_position = pixel_pos

## Centers the camera to the middle and zoom relative to the grid size.
func _center_camera(cols: int, rows: int) -> void:
	# 1. Find the 4 extreme corners of the isometric diamond grid
	# (Subtracting 1 because a 6x6 grid goes from index 0 to 5)
	var top_corner = FloorTiles.map_to_local(Vector2i(0, 0))
	var bottom_corner = FloorTiles.map_to_local(Vector2i(cols - 1, rows - 1))
	var right_corner = FloorTiles.map_to_local(Vector2i(cols - 1, 0))
	var left_corner = FloorTiles.map_to_local(Vector2i(0, rows - 1))

	# 2. Get the base pixel boundaries
	var min_x = left_corner.x
	var max_x = right_corner.x
	var min_y = top_corner.y
	var max_y = bottom_corner.y

	# 3. Add padding for the tile edges! 
	# map_to_local() returns the CENTER of the tile. If we don't add half 
	# of the tile's size, the camera will cut off the outer halves of the edge tiles.
	var half_tile = Vector2(FloorTiles.tile_set.tile_size) / 2.0
	min_x -= half_tile.x
	max_x += half_tile.x
	min_y -= half_tile.y
	max_y += half_tile.y

	# 4. Center the camera
	var center_x = (min_x + max_x) / 2.0
	var center_y = (min_y + max_y) / 2.0
	
	# Convert local coordinates back to global just in case the Node2D is moved
	camera.global_position = FloorTiles.to_global(Vector2(center_x, center_y))

	# Hardcode the zoom depending on the grid size
	# - Determine the zoom size byt an incresing grid interval of 5
	# - The starting zoom is 0.5
	# - The max zoom is 0.1
	var max_grid_size = max(cols, rows)
	
	# Determine on what interval of 5 we are on
	@warning_ignore("integer_division")
	var step = (int(max_grid_size) - 1) / 5
	
	# Determine a proper zoom between grid sizes
	var final_zoom = 1
	print("Grid Size Level: ", step)
	if step < 5:
		final_zoom = 0.15 - (step * 0.03)
	else:
		final_zoom = 0.1 - (step * 0.01)
	
	# CRITICAL: Put a floor. Camera zoom cannot be 0
	final_zoom = max(final_zoom, 0.01) 
	
	# Apply the zoom
	# # CRITICAL: Since this camera zoom is fixed recomend no bigger than 35X35 grid size
	camera.zoom = Vector2(final_zoom, final_zoom)

# === grid overlay ===
# visual helper for readability and debugging (not gameplay logic)
#func _build_grid() -> void:
	#for gx in range(1, cols + 1):
		#for gy in range(1, rows + 1):
			#var diamond := Line2D.new()
			#diamond.width = 1.0
			#diamond.default_color = grid_color
#
			#var c := _cell_center(gx, gy)
			#var top := c + Vector2(0, -tile_height / 2.0)
			#var right := c + Vector2(tile_width / 2.0, 0)
			#var bottom := c + Vector2(0, tile_height / 2.0)
			#var left := c + Vector2(-tile_width / 2.0, 0)
#
			#diamond.add_point(top)
			#diamond.add_point(right)
			#diamond.add_point(bottom)
			#diamond.add_point(left)
			#diamond.add_point(top)
#
			#grid_node.add_child(diamond)

# ======= public helpers =======

## Returns the proper position in realation to the floor grids.
## Input:  New grid position
## Output: Pixel position in relation to the grid position
func grid_position(x_pos: int, y_pos: int) -> Vector2:
	# Move to desired position
	# CAUTION: mantain chunk_size since floor are scale 2x
	var center_physical_x = ((world_x_size * chunk_size) - (((world_x_size * chunk_size)+2) - x_pos * chunk_size))
	var center_physical_y = ((world_y_size * chunk_size) - (y_pos * chunk_size) + 2)

	# 5. Ask the TileMapLayer where that specific grid tile is in actual pixels
	var grid_pos = FloorTiles.map_to_local(Vector2i(center_physical_x, center_physical_y))
	# If offset is needed
	@warning_ignore("narrowing_conversion")
	var pixel_pos = Vector2i(grid_pos[0],grid_pos[1]-25)
	print("New Position: ", x_pos, ",", y_pos, " Grid Postion: ", grid_pos, " Pixel Position: ", pixel_pos)
	return pixel_pos

## simple bounds check so the player doesn't walk off the map like a clown
func is_in_bounds(gx: int, gy: int) -> bool:
	return gx >= 1 and gx <= world_x_size and gy >= 1 and gy <= world_y_size

## Not so simple bound check so the player doesn't go through walls
func is_move_blocked(gx: int, gy: int, dir: String) -> bool:
	# Check if wall even exist
	if level_data.has("walls"):
		# Check the a wall withing a given cell
		var key := "%d,%d" % [gx, gy]
		print(key)
		if level_data["walls"].has(key):
			# Find if at least one wall face the player
			var direction = level_data["walls"][key]
			for d in direction:
				if str(d).to_lower() == dir:
					return true
	return false


func _cell_key(gx: int, gy: int) -> String:
	return "%d,%d" % [gx, gy]

## Check is there any wall facing the player
## Input: current position and direction
## Output: True(player face wall), False(player does not face wall)
func _check_wall(gx: int, gy: int, dir: String) -> bool:
	# Check if wall even exist
	if level_data.has("walls"):
		# Check the a wall withing a given cell
		var key := "%d,%d" % [gx, gy]
		if level_data["walls"].has(key):
			# Find if at least one wall face the player
			var direction = level_data["walls"][key]
			for d in direction:
				if str(d).to_lower() == dir:
					return true
	return false

# === win condition ===
func check_win_condition(gx: int, gy: int) -> void:
	if not level_data.has("goal"):
		return

	var goal = level_data["goal"]

	if goal.has("possible_final_positions"):
		for pos in goal["possible_final_positions"]:
			if typeof(pos) == TYPE_ARRAY and pos.size() >= 2:
				if int(pos[0]) == gx and int(pos[1]) == gy:
					level_complete.emit()
					return

	if goal.has("position"):
		var pos = goal["position"]
		if typeof(pos) == TYPE_DICTIONARY:
			if int(pos.get("x", -1)) == gx and int(pos.get("y", -1)) == gy:
				level_complete.emit()
