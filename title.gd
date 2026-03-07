extends Control

const MASTER_BUS_INDEX := 0

@onready var play_button: Button = $VBoxContainer/Button
@onready var language_option: OptionButton = $VBoxContainer/LanguageOption
@onready var mute_button: Button = $MuteButton
@onready var unlocked_count_label: Label = $UnlockedCountLabel

func _ready() -> void:
	_init_language_option()
	_update_ui_text()
	_update_mute_button_text()
	_update_unlocked_count_label()

	if Global.newly_unlocked > 0:
		_play_unlock_animation()

func _update_unlocked_count_label():
	if Global.unlocked_skills_count > 0:
		unlocked_count_label.text = tr("★ ") + str(Global.unlocked_skills_count)
		unlocked_count_label.show()
	else:
		unlocked_count_label.hide()

const UnlockAnimationScene = preload("res://unlock_animation.tscn")

func _play_unlock_animation():
	var anim_scene = UnlockAnimationScene.instantiate()
	add_child(anim_scene)
	anim_scene.animation_finished.connect(_update_unlocked_count_label)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

const LANGUAGES = [
	{"name": "日本語", "code": "ja"},
	{"name": "English", "code": "en"},
	{"name": "简体中文", "code": "zh"}
]

func _init_language_option():
	language_option.clear()
	var current_locale = TranslationServer.get_locale()
	var current_idx = 0
	for i in range(LANGUAGES.size()):
		var lang = LANGUAGES[i]
		language_option.add_item(lang.name, i)
		if current_locale.begins_with(lang.code):
			current_idx = i
	language_option.selected = current_idx

func _on_language_option_item_selected(index: int) -> void:
	if index >= 0 and index < LANGUAGES.size():
		TranslationServer.set_locale(LANGUAGES[index].code)
		_update_ui_text()

func _on_mute_button_pressed():
	mute_button.release_focus()
	var is_muted = not AudioServer.is_bus_mute(MASTER_BUS_INDEX)
	AudioServer.set_bus_mute(MASTER_BUS_INDEX, is_muted)
	_update_mute_button_text()

func _update_mute_button_text():
	var is_muted = AudioServer.is_bus_mute(MASTER_BUS_INDEX)
	mute_button.text = tr("MSG_AUDIO_OFF") if is_muted else tr("MSG_AUDIO_ON")

func _update_ui_text():
	play_button.text = tr("PLAY")
	_update_mute_button_text()

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_LEFT:
			Global.unlocked_skills_count = 0
			Global.known_effectiveness = {}
			Global.save_data()
			_update_unlocked_count_label()
		elif event.keycode == KEY_RIGHT:
			var max_unlocks = ItemData.SKILLS.size() - 4
			if Global.unlocked_skills_count < max_unlocks:
				Global.unlocked_skills_count += 1
				Global.save_data()
				_update_unlocked_count_label()
