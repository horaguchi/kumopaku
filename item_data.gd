class_name ItemData
extends RefCounted

static var SKILLS: Array:
	get:
		return _combat_results.keys()
static var COMBAT_RESULTS: Dictionary:
	get:
		return _combat_results
static var _combat_results: Dictionary = _load_combat_results()
static func _load_combat_results() -> Dictionary:
	var path = "res://combat_results.json"
	if not FileAccess.file_exists(path):
		printerr("Combat results file not found: ", path)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		return json.data
	else:
		printerr("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return {}
