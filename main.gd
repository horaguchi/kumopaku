class_name Main
extends Node2D

const DungeonGeneratorData = preload("res://dungeon_generator.gd")
const EnemyDataMap = preload("res://enemy_data.gd")
const ItemDataMap = preload("res://item_data.gd")

# --- UI Nodes ---
var title_screen: Control
var game_screen: Control
var map_label: Label
var message_log: RichTextLabel
var skill_container: VBoxContainer
var skill_buttons: Array[Button] = []

# --- Game State ---
var current_floor := 1
var player_pos := Vector2.ZERO
var player_skills: Array[String] = ["殴る"]
var active_skill_index := 0
var map_data := {}
var is_skill_replace_mode := false
var temp_new_skill := ""

func _ready() -> void:
	_setup_ui()
	_show_title_screen()

func _setup_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Monospace", "Courier New", "Consolas"])

	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.size = get_viewport_rect().size
	add_child(title_screen)

	var title_vbox = VBoxContainer.new()
	title_vbox.set_anchors_preset(Control.PRESET_CENTER)
	title_screen.add_child(title_vbox)

	var title_label := Label.new()
	title_label.text = "Rogue-like Text Game"
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_vbox.add_child(title_label)

	var play_button := Button.new()
	play_button.text = "プレイ"
	play_button.add_theme_font_override("font", font)
	play_button.add_theme_font_size_override("font_size", 32)
	play_button.pressed.connect(_start_game)
	title_vbox.add_child(play_button)

	game_screen = Control.new()
	game_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_screen.size = get_viewport_rect().size
	game_screen.visible = false
	add_child(game_screen)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_screen.add_child(hbox)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_vbox)

	map_label = Label.new()
	map_label.add_theme_font_override("font", font)
	map_label.add_theme_font_size_override("font_size", 38)
	map_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_vbox.add_child(map_label)

	message_log = RichTextLabel.new()
	message_log.add_theme_font_override("normal_font", font)
	message_log.custom_minimum_size = Vector2(0, 200)
	message_log.scroll_following = true
	left_vbox.add_child(message_log)

	skill_container = VBoxContainer.new()
	skill_container.custom_minimum_size = Vector2(250, 0)
	hbox.add_child(skill_container)

	for i in range(4):
		var btn = Button.new()
		btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 24)
		btn.visible = false
		btn.pressed.connect(func(): _on_skill_button_pressed(i))
		skill_container.add_child(btn)
		skill_buttons.append(btn)

func _show_title_screen():
	title_screen.visible = true
	game_screen.visible = false

func _start_game():
	title_screen.visible = false
	game_screen.visible = true
	current_floor = 1
	player_skills.clear()
	player_skills.append("殴る")
	active_skill_index = 0
	message_log.text = ""
	_log_message("ダンジョンに入った...")
	_load_floor()

func _load_floor():
	_log_message(str(current_floor) + "F に到達した。")
	map_data = DungeonGeneratorData.generate(current_floor)
	player_pos = map_data.start_pos

	var available_enemies = []
	for e_char in EnemyDataMap.ENEMIES.keys():
		var d = EnemyDataMap.ENEMIES[e_char]
		if d.min_floor <= current_floor and d.max_floor >= current_floor:
			available_enemies.append(e_char)

	for i in range(map_data.enemies.size()):
		var e_pos = map_data.enemies[i]
		var e_char = ""
		if available_enemies.size() > 0:
			e_char = available_enemies.pick_random()
		else:
			e_char = "A"
		map_data.enemies[i] = {"pos": e_pos, "char": e_char}

	_update_ui()

func _log_message(msg: String):
	message_log.text += "> " + msg + "\n"

func _update_ui():
	_update_map()
	_update_skills()

func _update_map():
	if map_data.is_empty(): return
	var grid: Array = map_data.grid.duplicate(true)

	if map_data.has("stairs_pos"):
		grid[map_data.stairs_pos.y][map_data.stairs_pos.x] = ">"

	for item_pos in map_data.items:
		grid[item_pos.y][item_pos.x] = "?"

	for enemy in map_data.enemies:
		grid[enemy.pos.y][enemy.pos.x] = enemy.char

	grid[player_pos.y][player_pos.x] = "@"

	var map_str = ""
	for y in range(DungeonGeneratorData.HEIGHT):
		var row_str = ""
		for x in range(DungeonGeneratorData.WIDTH):
			row_str += grid[y][x]
		map_str += row_str + "\n"

	map_label.text = map_str

func _update_skills():
	for i in range(4):
		skill_buttons[i].visible = false
		skill_buttons[i].remove_theme_color_override("font_color")

	for i in range(player_skills.size()):
		skill_buttons[i].visible = true
		skill_buttons[i].text = player_skills[i]
		if i == active_skill_index:
			skill_buttons[i].text = "[*] " + player_skills[i]
			skill_buttons[i].add_theme_color_override("font_color", Color.YELLOW)

	if is_skill_replace_mode:
		skill_buttons[3].visible = true
		skill_buttons[3].text = "[NEW] " + temp_new_skill
		skill_buttons[3].add_theme_color_override("font_color", Color.GREEN)

func _on_skill_button_pressed(idx: int):
	# ボタンのフォーカスを外さないとキー入力が吸われる
	skill_buttons[idx].release_focus()

	if is_skill_replace_mode:
		if idx < 3 and idx < player_skills.size():
			_log_message(player_skills[idx] + " を捨て、「" + temp_new_skill + "」をセットした。")
			player_skills[idx] = temp_new_skill
			is_skill_replace_mode = false
			temp_new_skill = ""
			_update_ui()
			_process_enemies_turn()
		elif idx == 3:
			_log_message("「" + temp_new_skill + "」を諦めた。")
			is_skill_replace_mode = false
			temp_new_skill = ""
			_update_ui()
			_process_enemies_turn()
	else:
		if idx < player_skills.size():
			active_skill_index = idx
			_log_message("有効スキルを「" + player_skills[idx] + "」に変更した。")
			_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not game_screen.visible or is_skill_replace_mode: return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP or event.keycode == KEY_W:
			_move(Vector2.UP)
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			_move(Vector2.DOWN)
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_move(Vector2.LEFT)
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_move(Vector2.RIGHT)

func _move(dir: Vector2):
	var next_pos = player_pos + dir

	if map_data.grid[next_pos.y][next_pos.x] == "#":
		return

	var hit_enemy_idx = -1
	for i in range(map_data.enemies.size()):
		if map_data.enemies[i].pos == next_pos:
			hit_enemy_idx = i
			break

	if hit_enemy_idx != -1:
		_combat(hit_enemy_idx)
		_process_enemies_turn()
		return

	player_pos = next_pos

	var picked_item_idx = -1
	for i in range(map_data.items.size()):
		if map_data.items[i] == player_pos:
			picked_item_idx = i
			break

	if picked_item_idx != -1:
		map_data.items.remove_at(picked_item_idx)
		var new_skill = ItemDataMap.SKILLS.pick_random()
		_log_message("アイテムを拾った！「" + new_skill + "」を見つけた。")
		if player_skills.size() < 3:
			player_skills.append(new_skill)
		else:
			is_skill_replace_mode = true
			temp_new_skill = new_skill
			_log_message("スキルがいっぱいだ。左のリストから捨てるスキルをクリックするか、一番下をクリックして新しいスキルを捨ててくれ。")
			_update_ui()
			return

	if player_pos == map_data.stairs_pos:
		if current_floor == 5:
			_log_message("全てのフロアを制覇した！ゲームクリア！！")
			map_data.clear()
			_update_ui()
			_game_over()
			return
		else:
			current_floor += 1
			_load_floor()
			return

	_process_enemies_turn()

func _process_enemies_turn():
	if map_data.is_empty(): return
	var indices_to_remove = []
	for i in range(map_data.enemies.size()):
		var enemy = map_data.enemies[i]
		var e_char = enemy.char
		var enemy_data = EnemyDataMap.ENEMIES[e_char]

		var dist = abs(enemy.pos.x - player_pos.x) + abs(enemy.pos.y - player_pos.y)

		if dist <= enemy_data.agro_range:
			# XかYで近づく
			var dx = sign(player_pos.x - enemy.pos.x)
			var dy = sign(player_pos.y - enemy.pos.y)
			var n_pos = enemy.pos

			if dx != 0 and map_data.grid[enemy.pos.y][enemy.pos.x + dx] != "#":
				n_pos.x += dx
			elif dy != 0 and map_data.grid[enemy.pos.y + dy][enemy.pos.x] != "#":
				n_pos.y += dy

			# 味方同士の衝突は省略。文字ベースなので無視。
			enemy.pos = n_pos

			if enemy.pos == player_pos:
				_log_message("敵 " + e_char + " の " + enemy_data.skill + " 攻撃！")
				var is_player_dead = _combat(i)
				if is_player_dead:
					return # 戦闘で死んだら終了
				else:
					indices_to_remove.append(i)

	# プレイヤーの反撃で死んだ敵を消す(敵から接触してきた場合)
	for i in range(indices_to_remove.size() - 1, -1, -1):
		map_data.enemies.remove_at(indices_to_remove[i])

	_update_ui()

func _combat(enemy_idx: int) -> bool:
	var enemy = map_data.enemies[enemy_idx]
	var e_char = enemy.char
	var skill = player_skills[active_skill_index]
	var result = ItemDataMap.COMBAT_RESULTS[skill][e_char]

	_log_message(result.message)

	if result.win:
		_log_message("敵 " + e_char + " を倒した！")
		# プレイヤーから発信された攻撃ならここで削除
		if player_pos != enemy.pos:
			map_data.enemies.remove_at(enemy_idx)
		return false # 死亡していない
	else:
		_log_message("あなたは死んでしまった... GAME OVER")
		map_data.clear()
		_update_ui()
		call_deferred("_game_over")
		return true

func _game_over():
	await get_tree().create_timer(3.0).timeout
	_show_title_screen()
