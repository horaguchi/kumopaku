extends Control

const MASTER_BUS_INDEX := 0

@onready var play_button: Button = $VBoxContainer/Button
@onready var language_option: OptionButton = $VBoxContainer/LanguageOption
@onready var skills_button: Button = $VBoxContainer/SkillsButton
@onready var mute_button: Button = $MuteButton
@onready var unlocked_count_label: Label = $UnlockedCountLabel

@onready var skill_list_modal: Panel = $SkillListModal
@onready var skill_grid: HFlowContainer = $SkillListModal/ScrollContainer/SkillGrid
@onready var skill_detail_modal: Panel = $SkillDetailModal
@onready var skill_name_label: RichTextLabel = $SkillDetailModal/VBoxContainer/SkillNameLabel
@onready var favorite_button: Button = $SkillDetailModal/VBoxContainer/FavoriteButton
@onready var effectiveness_list: VBoxContainer = $SkillDetailModal/VBoxContainer/ScrollContainer/EffectivenessList
@onready var close_list_button: Button = $SkillListModal/CloseListButton
@onready var close_detail_button: Button = $SkillDetailModal/VBoxContainer/CloseDetailButton

var current_viewing_skill: String = ""
const EnemyDataMap = preload("res://enemy_data.gd")

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
	anim_scene.animation_finished.connect(_on_unlock_animation_finished)

func _on_unlock_animation_finished():
	Global.newly_unlocked = 0
	_update_unlocked_count_label()

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
	skills_button.text = tr("SKILLS")
	close_list_button.text = tr("CLOSE")
	close_detail_button.text = tr("BACK")
	_update_mute_button_text()
	if current_viewing_skill != "":
		_update_favorite_button()

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
			var max_unlocks = ItemData.SKILLS.size() - Global.INITIAL_SKILL_POOL_SIZE
			if Global.unlocked_skills_count < max_unlocks:
				Global.unlocked_skills_count += 1
				Global.save_data()
				_update_unlocked_count_label()

func _on_skills_button_pressed() -> void:
	_populate_skill_list()
	skill_list_modal.show()

func _populate_skill_list() -> void:
	for child in skill_grid.get_children():
		child.queue_free()

	var max_items = clampi(Global.INITIAL_SKILL_POOL_SIZE + Global.unlocked_skills_count, Global.INITIAL_SKILL_POOL_SIZE, ItemData.SKILLS.size())
	for i in range(max_items):
		var skill_name = ItemData.SKILLS[i]
		var btn = Button.new()
		btn.text = tr(skill_name)
		btn.add_theme_font_size_override("font_size", 24)
		if Global.favorite_skill == skill_name:
			btn.text = "★ " + btn.text
			btn.add_theme_color_override("font_color", Color.YELLOW)
		btn.pressed.connect(func(): _show_skill_detail(skill_name))
		skill_grid.add_child(btn)

func _show_skill_detail(skill_name: String) -> void:
	current_viewing_skill = skill_name
	skill_list_modal.hide()
	skill_detail_modal.show()
	_update_favorite_button()

	var t_skill = tr(skill_name)
	if Global.favorite_skill == skill_name:
		skill_name_label.text = "[center][color=yellow]★[/color] " + t_skill + "[/center]"
	else:
		skill_name_label.text = "[center]" + t_skill + "[/center]"

	for child in effectiveness_list.get_children():
		child.queue_free()

	for e_char in EnemyDataMap.ENEMIES.keys():
		var key = skill_name + "_" + e_char
		var edata = EnemyDataMap.ENEMIES[e_char]
		var lbl = RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.add_theme_font_size_override("normal_font_size", 24)

		var t_enemy = tr(edata.name)
		if Global.known_effectiveness.has(key):
			var win = Global.known_effectiveness[key]
			var color = "green" if win else "red"
			var res_text = "WIN" if win else "LOSS"
			lbl.text = "[color=%s]%s[/color] VS %s" % [color, res_text, t_enemy]
		else:
			lbl.text = "[color=gray]? VS %s[/color]" % t_enemy

		effectiveness_list.add_child(lbl)

func _on_favorite_pressed() -> void:
	if Global.favorite_skill == current_viewing_skill:
		Global.favorite_skill = ""
	else:
		Global.favorite_skill = current_viewing_skill
	Global.save_data()
	_update_favorite_button()

	var t_skill = tr(current_viewing_skill)
	if Global.favorite_skill == current_viewing_skill:
		skill_name_label.text = "[center][color=yellow]★[/color] " + t_skill + "[/center]"
	else:
		skill_name_label.text = "[center]" + t_skill + "[/center]"

func _update_favorite_button() -> void:
	if Global.favorite_skill == current_viewing_skill:
		favorite_button.text = tr("REMOVE_FAVORITE")
	else:
		favorite_button.text = tr("ADD_FAVORITE")

func _on_close_list_pressed() -> void:
	skill_list_modal.hide()

func _on_close_detail_pressed() -> void:
	skill_detail_modal.hide()
	_populate_skill_list()
	skill_list_modal.show()
