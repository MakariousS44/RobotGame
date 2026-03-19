extends Control

# References to UI elements in the scene.
# These are used to read user code, display output, and show the game preview.
@onready var editor: CodeEdit = $VBoxContainer/HSplitContainer/Editor
@onready var game_view: SubViewportContainer = $VBoxContainer/HSplitContainer/GameView
@onready var game_subviewport: SubViewport = $VBoxContainer/HSplitContainer/GameView/SubViewport
@onready var output_box: RichTextLabel = $VBoxContainer/Output
@onready var status_label: Label = $VBoxContainer/HBoxContainer/StatusLabel
@onready var validate_button: Button = $VBoxContainer/HBoxContainer/ValidateButton
@onready var run_button: Button = $VBoxContainer/HBoxContainer/RunButton


# Pipeline components.
# Each piece handles one stage of processing student code.
# MainUI connects them together but does not implement their logic.
var validator = preload("res://scripts/pipeline/student_validator.gd").new()
var generator = preload("res://scripts/pipeline/source_generator.gd").new()
var compiler = preload("res://scripts/pipeline/compiler_driver.gd").new()
var translator = preload("res://scripts/pipeline/command_translator.gd").new()
var executor = preload("res://scripts/pipeline/command_executor.gd").new()

# World Components
var world_loader = preload("res://scripts/worlds/world_loader.gd").new()
var reeborg_adapter = preload("res://scripts/worlds/reeborg_adapter.gd").new()

# Game preview scene and references.
# This is the small test world shown inside the UI.
var game_test_scene = preload("res://scenes/GameTest.tscn")
var game_instance = null
var player_node = null


func _ready() -> void:
	status_label.text = "Ready"
	editor.text = "int main() {\n    move();\n}\n"
	editor.grab_focus()

	_setup_editor()
	_setup_syntax_highlighting()

	# Connect UI buttons to their handlers.
	if not validate_button.pressed.is_connected(_on_validate_button_pressed):
		validate_button.pressed.connect(_on_validate_button_pressed)

	if not run_button.pressed.is_connected(_on_run_button_pressed):
		run_button.pressed.connect(_on_run_button_pressed)

	# Load the test scene into the viewport.
	_load_game_test_scene()


func _load_game_test_scene() -> void:
	print("Loading GameTest...")
	game_instance = game_test_scene.instantiate()
	game_subviewport.add_child(game_instance)
	player_node = game_instance.get_node("Player")

	var raw = world_loader.load_world("res://scripts/worlds/levels/test.json")

	if not raw.ok:
		print("World load failed: ", raw.error)
		return

	var world_data = reeborg_adapter.convert(raw.world)

	if game_instance.has_method("load_world_data"):
		game_instance.load_world_data(world_data)

	print("Loaded: ", game_instance)
	print("Player: ", player_node)


func _setup_editor() -> void:
	# Basic editor behavior and formatting settings.
	editor.highlight_current_line = true
	editor.draw_control_chars = false
	editor.indent_automatic = true
	editor.indent_use_spaces = true
	editor.indent_size = 4


func _setup_syntax_highlighting() -> void:
	var highlighter := CodeHighlighter.new()

	# Standard C++ keywords.
	var keywords := [
		"int", "double", "float", "bool", "char", "void",
		"if", "else", "while", "for", "return",
		"true", "false", "break", "continue"
	]

	for word in keywords:
		highlighter.add_keyword_color(word, Color(0.40, 0.70, 1.00))

	# Functions provided by the game environment.
	# These are visually distinct so users can recognize the API.
	var robot_funcs := [
		"move", "turn_left", "pick_beeper", "put_beeper",
		"front_is_clear", "beepers_present", "print"
	]

	for func_name in robot_funcs:
		highlighter.add_keyword_color(func_name, Color(0.80, 0.60, 1.00))

	# General token coloring.
	highlighter.number_color = Color(0.95, 0.65, 0.30)
	highlighter.symbol_color = Color(0.85, 0.85, 0.85)
	highlighter.function_color = Color(0.95, 0.85, 0.45)
	highlighter.member_variable_color = Color(0.85, 0.85, 0.85)

	# Strings
	highlighter.add_color_region("\"", "\"", Color(0.60, 0.90, 0.60), false)
	highlighter.add_color_region("'", "'", Color(0.60, 0.90, 0.60), false)

	# Comments
	highlighter.add_color_region("//", "", Color(0.50, 0.50, 0.50), true)
	highlighter.add_color_region("/*", "*/", Color(0.50, 0.50, 0.50), false)

	editor.syntax_highlighter = highlighter


func _on_validate_button_pressed() -> void:
	status_label.text = "Validating..."
	output_box.clear()
	_append_section_header("Validation")

	# Allow the UI to update before heavy work begins.
	await get_tree().process_frame

	var validation := validator.validate(editor.text)

	if not validation.ok:
		for err in validation.errors:
			output_box.append_text("[Error] Line %d: %s\n" % [err.line, err.message])
		status_label.text = "❌ Validation Failed"
		return

	var generated := generator.generate(editor.text)
	compiler.prepare_build_files(generated.generated_source)

	var build := compiler.compile_program()
	if not build.ok:
		output_box.append_text(compiler.remap_diagnostics(build.output, generated.line_offset) + "\n")
		status_label.text = "❌ Compile Failed"
		return

	output_box.append_text("No validation or compile errors found.\n")
	status_label.text = "✅ Ready to Run"


func _on_run_button_pressed() -> void:
	status_label.text = "▶ Running..."
	output_box.clear()
	_append_section_header("Run")

	# Same flow as validation, but followed by execution.
	await get_tree().process_frame

	var validation := validator.validate(editor.text)

	if not validation.ok:
		for err in validation.errors:
			output_box.append_text("[Error] Line %d: %s\n" % [err.line, err.message])
		status_label.text = "❌ Validation Failed"
		return

	var generated := generator.generate(editor.text)
	compiler.prepare_build_files(generated.generated_source)

	var build := compiler.compile_program()
	if not build.ok:
		output_box.append_text(compiler.remap_diagnostics(build.output, generated.line_offset) + "\n")
		status_label.text = "❌ Compile Failed"
		return

	var run_result := compiler.run_program()
	if not run_result.ok:
		output_box.append_text(run_result.output + "\n")
		status_label.text = "❌ Runtime Error"
		return

	# Show raw program output for transparency and debugging.
	if run_result.output.strip_edges() == "":
		output_box.append_text("(Program finished with no output)\n")
	else:
		output_box.append_text(run_result.output + "\n")

	status_label.text = "✅ Done"

	# Convert runtime output into commands and apply them to the world.
	_process_command_output(run_result.output)


func _process_command_output(raw_output: String) -> void:
	# Step 1: translate raw runtime text into structured commands.
	var result := translator.translate_runtime_output(raw_output)

	var commands: Array = result.commands
	var normal_output_lines: Array = result.normal_output_lines
	var warnings: Array = result.warnings

	# Step 2: display normal console output separately.
	if normal_output_lines.size() > 0:
		output_box.append_text("\n--- Console Output ---\n")
		for normal_line in normal_output_lines:
			output_box.append_text(normal_line + "\n")

	# Step 3: display translation warnings if any appear.
	if warnings.size() > 0:
		output_box.append_text("\n--- Translator Warnings ---\n")
		for warning in warnings:
			output_box.append_text("[Warning] %s\n" % warning)

	# Step 4: show the structured command list.
	output_box.append_text("\n--- Translated IR ---\n")
	output_box.append_text(JSON.stringify(commands, "\t") + "\n")

	# Step 5: execute commands in the game world.
	executor.execute(commands, player_node, get_tree())


func _append_section_header(title: String) -> void:
	output_box.append_text("=== %s ===\n" % title)
