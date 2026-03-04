extends Control

const MASTER_BUS_INDEX := 0

@onready var play_button: Button = $VBoxContainer/Button
@onready var language_option: OptionButton = $VBoxContainer/LanguageOption
@onready var mute_button: Button = $MuteButton

func _ready() -> void:
	_init_language_option()
	_update_ui_text()
	_update_mute_button_text()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _init_language_option():
	language_option.clear()
	language_option.add_item("日本語", 0)
	language_option.add_item("English", 1)
	language_option.add_item("简体中文", 2)

	# 現在のロケールに合わせて初期選択を同期
	var current_locale = TranslationServer.get_locale()
	if current_locale.begins_with("en"):
		language_option.selected = 1
	elif current_locale.begins_with("zh"):
		language_option.selected = 2
	else:
		language_option.selected = 0

func _on_language_option_item_selected(index: int) -> void:
	var next_locale = "ja"
	match index:
		0: next_locale = "ja"
		1: next_locale = "en"
		2: next_locale = "zh"

	TranslationServer.set_locale(next_locale)
	_update_ui_text()

func _on_mute_button_pressed():
	mute_button.release_focus()
	var is_muted = not AudioServer.is_bus_mute(MASTER_BUS_INDEX)
	AudioServer.set_bus_mute(MASTER_BUS_INDEX, is_muted)
	_update_mute_button_text()

func _update_mute_button_text():
	var is_muted = AudioServer.is_bus_mute(MASTER_BUS_INDEX)
	mute_button.text = "🔇 OFF" if is_muted else "🔊 ON"

func _update_ui_text():
	play_button.text = tr("PLAY")
