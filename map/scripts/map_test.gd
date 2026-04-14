extends Node2D

# Set the tiles mappings
@onready var FloorTiles: TileMapLayer = $FloorTileMap
@onready var WallTiles: TileMapLayer = $WallTileMap

@onready var camera: Camera2D = $Camera2D

const MapLoader = preload("res://map/scripts/map_loader.gd")
const PlayerChar = preload("res://player/player.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	build_level("res://data/campaign_levels/wallstest.json")

func build_level(file_path: String):
	# Instantiate and use the map loader
	var loader = MapLoader.new()
	
	var result = loader.load(file_path)
	
	# Verify the JSON using the dictionary structure you defined
	if not result["ok"]:
		# If it failed, print the error to the Godot debugger and stop
		push_error("Failed to load map: ", result["error"])
		return
		
	print("JSON verified and loaded successfully!")
	var level_data = result["definition"]
	
	# 5. Send the verified data to be drawn
	generate_floors(level_data)
	generate_walls(level_data)
	spawn_robot(0,10)
	
func generate_floors(data: Dictionary):
	# Generate the Floor Grid
	if data.has("cols") and data.has("rows"):
		var cols = int(data["cols"])
		var rows = int(data["rows"])
		print("Floor: ", cols,"x",rows)
		
		# Define how big each logical cell is in physical tiles
		var chunk_size = 1
		cols = (cols) * chunk_size
		rows = (rows) * chunk_size
		
		# Loop through every x (column) and y (row) to fill the grid
		for x in range(cols):
			for y in range(rows):
				var grid_pos = Vector2i(x, y)
				# Draw your floor tile (Assuming source_id 0 and atlas coords 0,0)
				FloorTiles.set_cell(grid_pos, 8, Vector2i(0, 1))
		
		# Set the camera to show the whole area
		focus_camera_on_grid(cols, rows)
	else:
		push_warning("JSON loaded, but 'cols' or 'rows' keys were missing!")

func generate_walls(data: Dictionary):
	# Generate the given chunk coord floors
	var cols = 0
	var rows = 0
	var chunk_size = 2
	
	if data.has("cols") and data.has("rows"):
		cols = int(data["cols"])
		rows = int(data["rows"])
		print("Floor: ", cols,"x",rows)
		
		# Define how big each logical cell is in physical tiles
		cols = (cols) * chunk_size
		rows = (rows+0.5) * chunk_size
	
	else:
		push_warning("JSON loaded, but 'cols' or 'rows' keys were missing!")

	# Generate the walls
	# The dictonary is formated as:
	#		 ["x-coords","y-coords"] : ["direction"]
	
	if data.has("walls"):
		var walls = Dictionary(data["walls"])
		for keys in walls:
			print(keys)
			# Obtain wall position
			var wall_coords = keys.split(",")
			var x_coords = int(wall_coords[0])
			var y_coords = int(wall_coords[1])
			print("x: ", x_coords, " y: ", y_coords)
			var grid_pos = Vector2((x_coords)*chunk_size - 1, rows - (y_coords)*chunk_size)
			
			# Obtain wall direction
			# CRITICAL: Reborg world only utilizes "east" and "north"
			# - This is optimize for Reborg world editor
			# - An array of size of 1, is either a wall facing "east" and "north"
			# - An array of size of 2, is a corner betwenn  "east" and "north" 
			var wall_directions = walls[keys]
			print(wall_directions)
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
			

func spawn_robot(logical_x: int, logical_y: int):
	# 2. Create an instance of the character
	var robot = PlayerChar.instantiate()
	
	# 3. Add it to the scene tree (make sure to add it BEFORE setting global_position)
	add_child(robot)
	robot.z_index = 1
	
	# --- THE POSITIONING MATH ---
	
	# 4. Find the center tile of your 3x3 chunk
	# If chunk_size is 3, the center tile is always at offset +1, +1
	var chunk_size = 2
	var center_physical_x = (logical_x * chunk_size)
	var center_physical_y = (logical_y * chunk_size)
	
	# 5. Ask the TileMapLayer where that specific grid tile is in actual pixels
	var pixel_pos = FloorTiles.map_to_local(Vector2i(center_physical_x, center_physical_y))
	pixel_pos = Vector2i(pixel_pos[0],pixel_pos[1]-90)
	
	# 6. Move the CharacterBody2D to those exact pixels!
	robot.global_position = pixel_pos
	

	# Determine east-north wall
func focus_camera_on_grid(cols: int, rows: int):
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
	var step = (int(max_grid_size) - 1) / 3
	
	# Determine a proper zoom between grid sizes
	var final_zoom = 1
	print("Grid Size Level: ", step)
	if step < 4:
		final_zoom = 0.5 - (step * 0.1)
	else:
		final_zoom = 0.2 - (step * 0.01)
	
	# CRITICAL: Put a floor. Camera zoom cannot be 0
	final_zoom = max(final_zoom, 0.1) 
	
	# Apply the zoom
	# # CRITICAL: Since this camera zoom is fixed recomend no bigger than 35X35 grid size
	camera.zoom = Vector2(final_zoom, final_zoom)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
