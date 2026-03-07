extends Node

const SAVE_PATH = "user://save_data.cfg"
const INITIAL_SKILL_POOL_SIZE = 4

var unlocked_skills_count: int = 0
var newly_unlocked: int = 0
var known_effectiveness: Dictionary = {}
var favorite_skill: String = ""

func _ready():
	load_data()

func save_data():
	var config = ConfigFile.new()
	config.set_value("game", "unlocked", unlocked_skills_count)
	config.set_value("game", "known_effectiveness", known_effectiveness)
	config.set_value("game", "favorite_skill", favorite_skill)
	config.save(SAVE_PATH)

func load_data():
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		printerr("Failed to load save data, file may be corrupt. Error code: %s" % error)

	unlocked_skills_count = config.get_value("game", "unlocked", 0)
	known_effectiveness = config.get_value("game", "known_effectiveness", {})
	favorite_skill = config.get_value("game", "favorite_skill", "")

func unlock_next() -> void:
	unlocked_skills_count += 1
	newly_unlocked += 1
	save_data()
