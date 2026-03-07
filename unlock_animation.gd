extends ColorRect

signal animation_finished

var _tw: Tween
var _is_animating: bool = true

@onready var title_lbl: Label = $VBoxContainer/TitleLabel
@onready var new_skill_lbl: Label = $VBoxContainer/NewSkillLabel
@onready var all_skills_lbl: RichTextLabel = $VBoxContainer/AllSkillsLabel
@onready var btn: Button = $Button

func _ready():
	z_index = 100

	var newly_unlocked_items = []
	var newly_idx = Global.INITIAL_SKILL_POOL_SIZE + Global.unlocked_skills_count - Global.newly_unlocked
	for i in range(Global.newly_unlocked):
		if newly_idx + i < ItemData.SKILLS.size():
			newly_unlocked_items.append(ItemData.SKILLS[newly_idx + i])

	var joined_skills = ""
	for s in newly_unlocked_items:
		if joined_skills != "": joined_skills += ", "
		joined_skills += tr(s)
	new_skill_lbl.text = joined_skills

	var all_unlocked_str = tr("MSG_UNLOCKED_SKILLS")
	for i in range(Global.INITIAL_SKILL_POOL_SIZE, Global.INITIAL_SKILL_POOL_SIZE + Global.unlocked_skills_count):
		if i < ItemData.SKILLS.size():
			all_unlocked_str += tr(ItemData.SKILLS[i]) + "  "
	all_skills_lbl.text = all_unlocked_str

	_tw = create_tween()
	_tw.tween_property(self , "color", Color(0, 0, 0, 0.9), 0.5)
	_tw.tween_property(title_lbl, "modulate", Color.WHITE, 0.5)
	_tw.tween_interval(0.2)
	_tw.tween_property(new_skill_lbl, "modulate", Color.WHITE, 0.5)
	_tw.tween_interval(0.5)
	_tw.tween_property(all_skills_lbl, "modulate", Color.WHITE, 0.5)
	_tw.finished.connect(func(): _is_animating = false)

	btn.pressed.connect(_on_action)

func _input(event: InputEvent) -> void:
	var is_valid_key = event is InputEventKey and event.pressed and not event.is_echo()
	var is_valid_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed

	if is_valid_key or is_valid_click:
		_on_action()
		get_viewport().set_input_as_handled()

func _on_action() -> void:
	if _is_animating:
		if _tw and _tw.is_valid():
			_tw.kill()
		_is_animating = false
		self.color = Color(0, 0, 0, 0.9)
		title_lbl.modulate = Color.WHITE
		new_skill_lbl.modulate = Color.WHITE
		all_skills_lbl.modulate = Color.WHITE
	else:
		animation_finished.emit()
		queue_free()
