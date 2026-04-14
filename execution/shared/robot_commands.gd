extends RefCounted

# =============================================================================
# COMMAND REGISTRY
# To add a new function, add one entry here. Everything else is automatic.
#
# Fields:
#   name     - function name used in student code
#   cmd      - [CMD] tag for action output. null for sensors (no output)
#   returns  - "" for void actions, "bool" for sensor functions
#   cpp_body - array of C++ lines inside the function body
#   py_body  - array of Python lines inside the function body
# =============================================================================

const COMMAND_DEFS := [
	# === actions ===
	{
		"name": "move",
		"cmd": "MOVE",
		"returns": "",
		"cpp_body": [
			'if (_facing == "north") _ry++;',
			'else if (_facing == "south") _ry--;',
			'else if (_facing == "east")  _rx++;',
			'else if (_facing == "west")  _rx--;',
		],
		"py_body": [
			"if _facing == 'north': _ry += 1",
			"elif _facing == 'south': _ry -= 1",
			"elif _facing == 'east': _rx += 1",
			"elif _facing == 'west': _rx -= 1",
		],
	},
	{
		"name": "turn_left",
		"cmd": "TURN_LEFT",
		"returns": "",
		"cpp_body": ["_facing = _left_of(_facing);"],
		"py_body":  ["_facing = _left_of(_facing)"],
	},
	{
		"name": "turn_right",
		"cmd": "TURN_RIGHT",
		"returns": "",
		"cpp_body": ["_facing = _right_of(_facing);"],
		"py_body":  ["_facing = _right_of(_facing)"],
	},
	{
		"name": "pick_object",
		"cmd": "PICK_OBJECT",
		"returns": "",
		"cpp_body": [],
		"py_body":  [],
	},
	{
		"name": "put_object",
		"cmd": "PUT_OBJECT",
		"returns": "",
		"cpp_body": [],
		"py_body":  [],
	},

	# === sensors ===
	{
		"name": "front_is_clear",
		"cmd": null,
		"returns": "bool",
		"cpp_body": ["return !_move_blocked(_rx, _ry, _facing);"],
		"py_body":  ["return not _move_blocked(_rx, _ry, _facing)"],
	},
	{
		"name": "right_is_clear",
		"cmd": null,
		"returns": "bool",
		"cpp_body": ["return !_move_blocked(_rx, _ry, _right_of(_facing));"],
		"py_body":  ["return not _move_blocked(_rx, _ry, _right_of(_facing))"],
	},
	{
		"name": "left_is_clear",
		"cmd": null,
		"returns": "bool",
		"cpp_body": ["return !_move_blocked(_rx, _ry, _left_of(_facing));"],
		"py_body":  ["return not _move_blocked(_rx, _ry, _left_of(_facing))"],
	},
	{
		"name": "wall_in_front",
		"cmd": null,
		"returns": "bool",
		"cpp_body": ["return _move_blocked(_rx, _ry, _facing);"],
		"py_body":  ["return _move_blocked(_rx, _ry, _facing)"],
	},
	{
		"name": "wall_on_right",
		"cmd": null,
		"returns": "bool",
		"cpp_body": ["return _move_blocked(_rx, _ry, _right_of(_facing));"],
		"py_body":  ["return _move_blocked(_rx, _ry, _right_of(_facing))"],
	},
	{
		"name": "wall_on_left",
		"cmd": null,
		"returns": "bool",
		"cpp_body": ["return _move_blocked(_rx, _ry, _left_of(_facing));"],
		"py_body":  ["return _move_blocked(_rx, _ry, _left_of(_facing))"],
	},
	{
		"name": "is_facing_north",
		"cmd": null,
		"returns": "bool",
		"cpp_body": ['return _facing == "north";'],
		"py_body":  ["return _facing == 'north'"],
	},
	{
		"name": "at_goal",
		"cmd": null,
		"returns": "bool",
		"cpp_body": ['return _rx == _goal_x && _ry == _goal_y;'],
		"py_body": ["return _rx == _goal_x and _ry == _goal_y"],
	},
]


# filter only action commands (used by syntax highlighter and macros)
var COMMANDS: Array:
	get:
		return COMMAND_DEFS.filter(func(d): return d.cmd != null)


# === python api ===
func get_python_api(world_state: Dictionary = {}) -> String:
	var rx: int        = world_state.get("x", 1)
	var ry: int        = world_state.get("y", 1)
	var facing: String = world_state.get("facing", "north")
	var rows: int      = world_state.get("rows", 10)
	var cols: int      = world_state.get("cols", 10)
	var walls          = world_state.get("walls", {})

	var wn := _collect_walls(walls, "north")
	var we := _collect_walls(walls, "east")
	var ws := _collect_walls(walls, "south")
	var ww := _collect_walls(walls, "west")

	var lines: Array = [
		"import traceback as _tb",
		"",
		"# === injected game state ===",
		"_rx = %d" % rx,
		"_ry = %d" % ry,
		"_facing = '%s'" % facing,
		"_rows = %d" % rows,
		"_cols = %d" % cols,
		"_goal_x = %d" % world_state.get("goal_x", -1),
		"_goal_y = %d" % world_state.get("goal_y", -1),
		"_walls_north = %s" % _python_set(wn),
		"_walls_east  = %s" % _python_set(we),
		"_walls_south = %s" % _python_set(ws),
		"_walls_west  = %s" % _python_set(ww),
		"",
		"# === state helpers ===",
		"def _right_of(d):",
		"    return {'north':'east','east':'south','south':'west','west':'north'}[d]",
		"",
		"def _left_of(d):",
		"    return {'north':'west','west':'south','south':'east','east':'north'}[d]",
		"",
		"def _move_blocked(x, y, d):",
		"    global _rows, _cols",
		"    nx, ny = x, y",
		"    if d == 'north': ny += 1",
		"    elif d == 'south': ny -= 1",
		"    elif d == 'east': nx += 1",
		"    elif d == 'west': nx -= 1",
		"    if nx < 1 or nx > _cols or ny < 1 or ny > _rows: return True",
		"    key = '%d,%d' % (x, y)",
		"    nkey = '%d,%d' % (nx, ny)",
		"    if d == 'north' and (key in _walls_north or nkey in _walls_south): return True",
		"    if d == 'south' and (key in _walls_south or nkey in _walls_north): return True",
		"    if d == 'east'  and (key in _walls_east  or nkey in _walls_west):  return True",
		"    if d == 'west'  and (key in _walls_west  or nkey in _walls_east):  return True",
		"    return False",
		"",
		"# === generated functions ===",
	]

	for def in COMMAND_DEFS:
		if def.returns == "bool":
			lines.append("def %s():" % def.name)
			lines.append("    global _rx, _ry, _facing")
			for body_line in def.py_body:
				lines.append("    " + body_line)
			lines.append("")
		else:
			var needs_state: bool = def.py_body.size() > 0
			lines.append("def %s():" % def.name)
			if needs_state:
				lines.append("    global _rx, _ry, _facing")
			lines.append("    _frame = _tb.extract_stack()[-2]")
			lines.append("    print('[CMD] %s [LINE] ' + str(_frame.lineno))" % def.cmd)
			for body_line in def.py_body:
				lines.append("    " + body_line)
			lines.append("")

	return "\n".join(lines)


# === c++ header ===
func get_cpp_header() -> String:
	var lines: Array = ["#pragma once", ""]
	for def in COMMAND_DEFS:
		if def.returns == "bool":
			lines.append("bool %s();" % def.name)
		else:
			lines.append("void %s(int __src_line = 0);" % def.name)
	return "\n".join(lines)


# === c++ source with injected state ===
func get_cpp_source(world_state: Dictionary = {}) -> String:
	var rx: int        = world_state.get("x", 1)
	var ry: int        = world_state.get("y", 1)
	var facing: String = world_state.get("facing", "north")
	var rows: int      = world_state.get("rows", 10)
	var cols: int      = world_state.get("cols", 10)
	var walls          = world_state.get("walls", {})

	var wn := _collect_walls(walls, "north")
	var we := _collect_walls(walls, "east")
	var ws := _collect_walls(walls, "south")
	var ww := _collect_walls(walls, "west")

	var lines: Array = [
		'#include "robot.hpp"',
		"#include <iostream>",
		"#include <string>",
		"#include <set>",
		"",
		"// === injected game state ===",
		"static int _rx = %d;" % rx,
		"static int _ry = %d;" % ry,
		'static std::string _facing = "%s";' % facing,
		"static int _rows = %d;" % rows,
		"static int _cols = %d;" % cols,
		"static int _goal_x = %d;" % world_state.get("goal_x", -1),
		"static int _goal_y = %d;" % world_state.get("goal_y", -1),
		"static const std::set<std::string> _walls_north = { %s };" % _cpp_set(wn),
		"static const std::set<std::string> _walls_east  = { %s };" % _cpp_set(we),
		"static const std::set<std::string> _walls_south = { %s };" % _cpp_set(ws),
		"static const std::set<std::string> _walls_west  = { %s };" % _cpp_set(ww),
		"",
		"// === state helpers ===",
		"static std::string _right_of(const std::string& d) {",
		'    if (d == "north") return "east";',
		'    if (d == "east")  return "south";',
		'    if (d == "south") return "west";',
		'    return "north";',
		"}",
		"",
		"static std::string _left_of(const std::string& d) {",
		'    if (d == "north") return "west";',
		'    if (d == "west")  return "south";',
		'    if (d == "south") return "east";',
		'    return "north";',
		"}",
		"",
		"static std::string _cell_key(int x, int y) {",
		"    return std::to_string(x) + \",\" + std::to_string(y);",
		"}",
		"",
		"static bool _move_blocked(int x, int y, const std::string& d) {",
		"    int nx = x, ny = y;",
		'    if (d == "north") ny++;',
		'    else if (d == "south") ny--;',
		'    else if (d == "east")  nx++;',
		'    else if (d == "west")  nx--;',
		"    if (nx < 1 || nx > _cols || ny < 1 || ny > _rows) return true;",
		"    auto key  = _cell_key(x, y);",
		"    auto nkey = _cell_key(nx, ny);",
		'    if (d == "north" && (_walls_north.count(key) || _walls_south.count(nkey))) return true;',
		'    if (d == "south" && (_walls_south.count(key) || _walls_north.count(nkey))) return true;',
		'    if (d == "east"  && (_walls_east.count(key)  || _walls_west.count(nkey)))  return true;',
		'    if (d == "west"  && (_walls_west.count(key)  || _walls_east.count(nkey)))  return true;',
		"    return false;",
		"}",
		"",
		"// === generated functions ===",
	]

	for def in COMMAND_DEFS:
		if def.returns == "bool":
			lines.append("bool %s() { %s }" % [def.name, def.cpp_body[0]])
		else:
			lines.append("void %s(int __src_line) {" % def.name)
			lines.append('    std::cout << "[CMD] %s [LINE] " << __src_line << std::endl;' % def.cmd)
			for body_line in def.cpp_body:
				lines.append("    " + body_line)
			lines.append("}")
			lines.append("")

	return "\n".join(lines)


# === c++ macros ===
func get_cpp_macros() -> String:
	var lines: Array = []
	for def in COMMAND_DEFS:
		if def.returns != "bool":
			lines.append("#define %s() %s(__LINE__)" % [def.name, def.name])
	return "\n".join(lines)


# === helpers ===
func _collect_walls(walls: Dictionary, dir: String) -> Array:
	var result := []
	for key in walls.keys():
		var directions = walls[key]
		if typeof(directions) == TYPE_ARRAY:
			for d in directions:
				if str(d).to_lower() == dir:
					result.append(key)
					break
	return result


func _cpp_set(keys: Array) -> String:
	if keys.is_empty():
		return ""
	var parts := []
	for k in keys:
		parts.append('"%s"' % k)
	return ", ".join(parts)


func _python_set(keys: Array) -> String:
	if keys.is_empty():
		return "set()"
	var parts := []
	for k in keys:
		parts.append('"%s"' % k)
	return "{%s}" % ", ".join(parts)
