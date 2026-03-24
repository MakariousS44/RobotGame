extends RefCounted

func generate(student_source: String) -> Dictionary:
	var header := """#include <iostream>
#include <string>
#include "robot.hpp"

"""

	return {
		"generated_source": header + student_source,
		"line_offset": 4
	}
