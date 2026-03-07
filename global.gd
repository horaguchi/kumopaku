extends Node

const SAVE_PATH = "user://save_data.cfg"

var unlocked_skills_count: int = 0
var newly_unlocked: int = 0
var known_effectiveness: Dictionary = {}

func _ready():
	load_data()

func save_data():
	var config = ConfigFile.new()
	config.set_value("game", "unlocked", unlocked_skills_count)
	config.set_value("game", "known_effectiveness", known_effectiveness)
	config.save(SAVE_PATH)

func load_data():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		unlocked_skills_count = config.get_value("game", "unlocked", 0)
		known_effectiveness = config.get_value("game", "known_effectiveness", {})
	else:
		unlocked_skills_count = 0
		known_effectiveness = {}

func unlock_next() -> bool:
	unlocked_skills_count += 1
	newly_unlocked += 1
	save_data()
	return true
