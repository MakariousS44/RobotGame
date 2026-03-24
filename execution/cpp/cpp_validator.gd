extends RefCounted

const FORBIDDEN_WORDS := {
	"using": "Using directives are not allowed.",
	"namespace": "Namespaces are not allowed.",
	"class": "Classes are not allowed in this environment.",
	"struct": "Structs are not allowed in this environment.",
	"template": "Templates are not allowed in this environment.",
	"new": "Dynamic allocation is not allowed.",
	"delete": "Dynamic allocation is not allowed.",
	"malloc": "Manual memory allocation is not allowed.",
	"free": "Manual memory allocation is not allowed.",
	"fstream": "File I/O is not allowed.",
	"ifstream": "File I/O is not allowed.",
	"ofstream": "File I/O is not allowed.",
	"system": "System calls are not allowed.",
	"fork": "Process control is not allowed.",
	"exec": "Process execution is not allowed.",
	"thread": "Threads are not allowed.",
	"filesystem": "Filesystem access is not allowed.",
	"socket": "Networking is not allowed.",
	"popen": "External process access is not allowed."
}

func validate(source: String) -> Dictionary:
	var errors: Array = []
	var lines := source.split("\n")

	for i in range(lines.size()):
		var line: String = lines[i]
		var trimmed := line.strip_edges()

		# Students do NOT write includes.
		if trimmed.begins_with("#"):
			errors.append({
				"line": i + 1,
				"column": 1,
				"message": "Do not write includes or preprocessor directives. They are provided automatically."
			})

		for word in FORBIDDEN_WORDS.keys():
			var idx := line.find(word)
			if idx != -1:
				errors.append({
					"line": i + 1,
					"column": idx + 1,
					"message": FORBIDDEN_WORDS[word]
				})

	if not source.contains("int main("):
		errors.append({
			"line": 1,
			"column": 1,
			"message": "Program must define int main()."
		})

	if source.contains("void main("):
		errors.append({
			"line": 1,
			"column": 1,
			"message": "Use int main(), not void main()."
		})

	return {
		"ok": errors.is_empty(),
		"errors": errors
	}
