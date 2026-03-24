extends Node2D

# === visual config ===
# tweakables so we're not hardcoding mystery numbers all over the place
@export var tile_width: int = 64
@export var tile_height: int = 32

@export var floor_color: Color = Color("6d8f58")
@export var floor_color_alt: Color = Color("769862")
@export var grid_color: Color = Color("d0d5c8")
@export var wall_color: Color = Color("f5ead7")
@export var board_shadow_color: Color = Color(0, 0, 0, 0.14)


# === scene references ===
# all the visual level layers live under WorldRoot
@onready var world_root: Node2D = $WorldRoot
@onready var floor_node: Node2D = $WorldRoot/Floor
@onready var grid_node: Node2D = $WorldRoot/Grid
@onready var walls_node: Node2D = $WorldRoot/Walls
@onready var objects_node: Node2D = $WorldRoot/Objects
@onready var player: Node2D = $WorldRoot/Player
@onready var camera: Camera2D = $Camera2D


# === loaded level state ===
# this is already-usable level data, not raw JSON
var level_data: Dictionary = {}
var rows: int = 0
var cols: int = 0


# === scene lifecycle ===
# runs when this scene is instantiated into the tree
# this scene owns the camera, so it configures it here
func _ready() -> void:
	camera.enabled = true
	camera.make_current()


# === main entry point ===
# outside code gives this scene a level definition dictionary
# this file then builds the full playable board from it
func build_level(data: Dictionary) -> void:
	level_data = data
	rows = data.get("rows", 10)
	cols = data.get("cols", 10)

	# wipe old visuals so we don't stack levels on top of each other
	_clear_children(floor_node)
	_clear_children(grid_node)
	_clear_children(walls_node)
	_clear_children(objects_node)

	# enforce consistent draw order
	floor_node.z_index = 0
	grid_node.z_index = 1
	walls_node.z_index = 2
	objects_node.z_index = 3
	player.z_index = 10

	_build_board_shadow()
	_build_floor()
	_build_grid()
	_place_player()
	_build_walls()
	_center_camera()


# === board shadow ===
# purely visual polish so the board doesn't feel like it’s floating in void
func _build_board_shadow() -> void:
	var shadow := Polygon2D.new()

	var top := _cell_center(1, rows)
	var right := _cell_center(1, 1)
	var bottom := _cell_center(cols, 1)
	var left := _cell_center(cols, rows)

	shadow.polygon = PackedVector2Array([
		top + Vector2(0, 18),
		right + Vector2(0, 18),
		bottom + Vector2(0, 18),
		left + Vector2(0, 18)
	])
	shadow.color = board_shadow_color
	shadow.z_index = -1

	floor_node.add_child(shadow)


# === floor tiles ===
# builds the base surface of the level using isometric diamonds
func _build_floor() -> void:
	for gx in range(1, cols + 1):
		for gy in range(1, rows + 1):
			var tile := Polygon2D.new()

			tile.polygon = PackedVector2Array([
				Vector2(0, -tile_height / 2.0),
				Vector2(tile_width / 2.0, 0),
				Vector2(0, tile_height / 2.0),
				Vector2(-tile_width / 2.0, 0)
			])

			# alternating colors so the board doesn't look dead
			tile.color = floor_color if (gx + gy) % 2 == 0 else floor_color_alt
			tile.position = _cell_center(gx, gy)

			floor_node.add_child(tile)


# === grid overlay ===
# visual helper for readability and debugging (not gameplay logic)
func _build_grid() -> void:
	for gx in range(1, cols + 1):
		for gy in range(1, rows + 1):
			var diamond := Line2D.new()
			diamond.width = 1.0
			diamond.default_color = grid_color

			var c := _cell_center(gx, gy)
			var top := c + Vector2(0, -tile_height / 2.0)
			var right := c + Vector2(tile_width / 2.0, 0)
			var bottom := c + Vector2(0, tile_height / 2.0)
			var left := c + Vector2(-tile_width / 2.0, 0)

			diamond.add_point(top)
			diamond.add_point(right)
			diamond.add_point(bottom)
			diamond.add_point(left)
			diamond.add_point(top)

			grid_node.add_child(diamond)


# === player placement ===
# decides WHERE the player goes
# the player script decides how it behaves and looks
func _place_player() -> void:
	if not level_data.has("robots"):
		return

	var robots = level_data["robots"]
	if robots.is_empty():
		return

	var robot = robots[0]
	var gx: int = robot.get("x", 1)
	var gy: int = robot.get("y", 1)
	var world_pos := _cell_center(gx, gy)

	# pass this level_scene into the player so it can query bounds and positions cleanly
	if player.has_method("initialize_from_level"):
		player.initialize_from_level(robot, world_pos)


# === walls ===
# reads wall data and draws directional wall segments
func _build_walls() -> void:
	if not level_data.has("walls"):
		return

	for key in level_data["walls"].keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 2:
			continue

		var gx := int(parts[0])
		var gy := int(parts[1])
		var directions = level_data["walls"][key]

		for dir in directions:
			_add_wall_segment(gx, gy, dir)


func _add_wall_segment(gx: int, gy: int, dir: String) -> void:
	var c := _cell_center(gx, gy)

	var top := c + Vector2(0, -tile_height / 2.0)
	var right := c + Vector2(tile_width / 2.0, 0)
	var bottom := c + Vector2(0, tile_height / 2.0)
	var left := c + Vector2(-tile_width / 2.0, 0)

	var wall := Line2D.new()
	wall.width = 5.0
	wall.default_color = wall_color

	match dir:
		"north":
			wall.add_point(top)
			wall.add_point(right)
		"east":
			wall.add_point(right)
			wall.add_point(bottom)
		"south":
			wall.add_point(bottom)
			wall.add_point(left)
		"west":
			wall.add_point(left)
			wall.add_point(top)
		_:
			return

	walls_node.add_child(wall)


# === camera framing ===
# centers and zooms the camera so the entire board fits on screen
func _center_camera() -> void:
	camera.enabled = true
	camera.make_current()

	var top := _cell_center(1, rows)
	var bottom := _cell_center(cols, 1)
	var left := _cell_center(cols, rows)
	var right := _cell_center(1, 1)

	var min_x = min(top.x, bottom.x, left.x, right.x)
	var max_x = max(top.x, bottom.x, left.x, right.x)
	var min_y = min(top.y, bottom.y, left.y, right.y)
	var max_y = max(top.y, bottom.y, left.y, right.y)

	var world_width = max_x - min_x
	var world_height = max_y - min_y

	camera.position = Vector2(
		min_x + world_width / 2.0,
		min_y + world_height / 2.0
	)

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		camera.zoom = Vector2.ONE
		return

	var zoom_x = viewport_size.x / world_width
	var zoom_y = viewport_size.y / world_height
	var fit_zoom = min(zoom_x, zoom_y) * 0.85

	camera.zoom = Vector2(fit_zoom, fit_zoom)


# === coordinate system ===
# converts grid coordinates into isometric world positions
func _cell_center(gx: int, gy: int) -> Vector2:
	var grid_x := float(cols - gx)
	var grid_y := float(rows - gy)

	var iso_x := (grid_x - grid_y) * (tile_width / 2.0)
	var iso_y := (grid_x + grid_y) * (tile_height / 2.0)

	var offset_x := cols * tile_width * 0.5
	var offset_y := tile_height * 1.5

	return Vector2(iso_x + offset_x, iso_y + offset_y)


# === helpers ===
# removes all children from a node (used for rebuilding levels)
func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


# === public helpers ===
# these are used by runtime systems like the player

# converts grid coordinates into world space position
func grid_to_world_position(gx: int, gy: int) -> Vector2:
	return _cell_center(gx, gy)

# simple bounds check so the player doesn't walk off the map like a clown
func is_in_bounds(gx: int, gy: int) -> bool:
	return gx >= 1 and gx <= cols and gy >= 1 and gy <= rows
