extends RefCounted

# Loads a JSON file from disk and returns parsed data.
# This does not interpret the data, it only reads and validates it.
func load_world(path: String) -> Dictionary:
	# Ensure the file exists before trying to open it.
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"error": "World file not found: %s" % path
		}

	var file := FileAccess.open(path, FileAccess.READ)

	# File failed to open.
	if file == null:
		return {
			"ok": false,
			"error": "Could not open world file: %s" % path
		}

	var text := file.get_as_text()

	# Parse JSON content.
	var json := JSON.new()
	var parse_result := json.parse(text)

	if parse_result != OK:
		return {
			"ok": false,
			"error": "Invalid JSON in world file: %s" % path
		}

	var data = json.data

	# Ensure the top-level structure is a dictionary.
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"error": "World JSON must be an object."
		}

	return {
		"ok": true,
		"world": data
	}
