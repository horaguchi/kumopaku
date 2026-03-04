class_name Main
extends Control

const DungeonGeneratorData = preload("res://dungeon_generator.gd")
const EnemyDataMap = preload("res://enemy_data.gd")
const ItemDataMap = preload("res://item_data.gd")

# --- UI Nodes ---
@onready var map_label: Label = $HBoxContainer/LeftVBox/MapLabel
@onready var message_log: RichTextLabel = $HBoxContainer/LeftVBox/MessageLog
@onready var skill_container: VBoxContainer = $HBoxContainer/SkillContainer
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
	for i in range(4):
		var btn = skill_container.get_child(i) as Button
		btn.pressed.connect(func(): _on_skill_button_pressed(i))
		skill_buttons.append(btn)

	call_deferred("_start_game")

func _start_game():
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
			row_str += str(grid[y][x])
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
	if is_skill_replace_mode: return

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

	if next_pos.x < 0 or next_pos.x >= DungeonGeneratorData.WIDTH or next_pos.y < 0 or next_pos.y >= DungeonGeneratorData.HEIGHT:
		return

	var c = map_data.grid[next_pos.y][next_pos.x]
	if not (c == "#" or c == "+" or c == "."):
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

			if dx != 0:
				var nx = enemy.pos.x + dx
				if nx >= 0 and nx < DungeonGeneratorData.WIDTH:
					var cx = map_data.grid[enemy.pos.y][nx]
					if cx == "#" or cx == "+" or cx == ".":
						n_pos.x += dx
			elif dy != 0:
				var ny = enemy.pos.y + dy
				if ny >= 0 and ny < DungeonGeneratorData.HEIGHT:
					var cy = map_data.grid[ny][enemy.pos.x]
					if cy == "#" or cy == "+" or cy == ".":
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
	get_tree().change_scene_to_file("res://title.tscn")
