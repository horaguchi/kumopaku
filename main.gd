class_name Main
extends Control

const DungeonGeneratorData = preload("res://dungeon_generator.gd")

const MASTER_BUS_INDEX := 0

# --- Game Balance ---
const FOV_RADIUS = 7

# --- Map Display Colors ---
const COLOR_PLAYER = "yellow"
const COLOR_WIN = "green"
const COLOR_LOSS = "red"
const COLOR_UNKNOWN = "magenta"
const COLOR_DISCOVERED = "#cccccc"

# --- UI Nodes ---
@onready var map_label: RichTextLabel = $MainVBox/HBoxContainer/LeftVBox/MapScroll/MapLabel
@onready var message_log: RichTextLabel = $MainVBox/MessageLog
@onready var skill_container: VBoxContainer = $MainVBox/HBoxContainer/SkillContainer
@onready var return_to_title_button: Button = $MainVBox/HBoxContainer/SkillContainer/ReturnToTitleButton
@onready var floor_label: Label = $MainVBox/HBoxContainer/SkillContainer/FloorLabel
var skill_buttons: Array[Button] = []

# --- Game State ---
var current_floor := 1
var player_pos := Vector2.ZERO
var player_skills: Array[String] = ["Punch"]
var active_skill_index := 0
var map_data := {}
var is_skill_replace_mode := false
var temp_new_skill := ""

# --- Message Log Queue ---
var message_queue: Array[String] = []
var is_printing_message := false
signal messages_finished
var is_processing_action := false

# --- Audio ---
@onready var audio_player: AudioStreamPlayer = $DialogPlayer
@onready var walk_audio_player: AudioStreamPlayer = $WalkPlayer
@onready var mute_button: Button = $MainVBox/MuteButton

# --- Movement Repeat ---
var move_delay := 0.15
var move_timer := 0.0

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_Q and not map_data.is_empty():
			if is_processing_action: return
			_execute_give_up()
		elif event.keycode == KEY_E and not map_data.is_empty():
			if is_processing_action: return
			_execute_debug_next_floor()

func _execute_give_up():
	_set_action_state(true)
	_log_message(tr("MSG_GAME_OVER"))
	await _wait_messages_done()
	map_data.clear()
	_update_ui()
	_game_over()
	_set_action_state(false)

func _execute_debug_next_floor():
	_set_action_state(true)
	if current_floor == 5:
		_log_message(tr("MSG_GAME_CLEAR"))
		await _wait_messages_done()
		map_data.clear()
		_update_ui()
		_game_over(true)
	else:
		current_floor += 1
		Global.save_data()
		await _load_floor()
	_set_action_state(false)

func _process(delta: float) -> void:
	if is_skill_replace_mode: return
	if is_processing_action: return

	if move_timer > 0:
		move_timer -= delta
		return

	var dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_K):
		dir = Vector2.UP
	elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_J):
		dir = Vector2.DOWN
	elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_H):
		dir = Vector2.LEFT
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_L):
		dir = Vector2.RIGHT

	if dir != Vector2.ZERO:
		move_timer = move_delay
		_execute_movement(dir)

func _ready() -> void:
	mute_button.pressed.connect(_on_mute_button_pressed)
	return_to_title_button.pressed.connect(_on_return_to_title_pressed)
	# AudioServerの状態に合わせてボタン表示を同期
	_update_mute_button_text()

	var buttons_in_group = get_tree().get_nodes_in_group("skill_buttons")
	for i in range(buttons_in_group.size()):
		var btn = buttons_in_group[i] as Button
		btn.pressed.connect(func(): _on_skill_button_pressed(i))
		skill_buttons.append(btn)

	call_deferred("_start_game")

func _get_random_skill() -> String:
	var max_items = clampi(Global.INITIAL_SKILL_POOL_SIZE + Global.unlocked_skills_count, Global.INITIAL_SKILL_POOL_SIZE, ItemData.SKILLS.size())
	var available = ItemData.SKILLS.slice(0, max_items)
	return available.pick_random()

func _on_mute_button_pressed():
	mute_button.release_focus()
	var is_muted = not AudioServer.is_bus_mute(MASTER_BUS_INDEX)
	AudioServer.set_bus_mute(MASTER_BUS_INDEX, is_muted)
	_update_mute_button_text()

func _update_mute_button_text():
	var is_muted = AudioServer.is_bus_mute(MASTER_BUS_INDEX)
	mute_button.text = tr("MSG_AUDIO_OFF") if is_muted else tr("MSG_AUDIO_ON")

func _start_game():
	_set_action_state(true)
	current_floor = 1
	player_skills.clear()
	if Global.favorite_skill != "":
		player_skills.append(Global.favorite_skill)
	else:
		player_skills.append(_get_random_skill())
	active_skill_index = 0
	return_to_title_button.visible = false
	message_log.text = ""
	_log_message(tr("MSG_ENTER_DUNGEON"))
	await _wait_messages_done()
	await _load_floor()
	_set_action_state(false)

func _load_floor():
	_log_message(tr("MSG_REACH_FLOOR").format({"floor": current_floor}))
	await _wait_messages_done()

	map_data = DungeonGeneratorData.generate(current_floor)
	player_pos = map_data.start_pos

	var available_enemies = []
	for e_char in EnemyData.ENEMIES.keys():
		var d = EnemyData.ENEMIES[e_char]
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
	message_queue.append(msg)
	if not is_printing_message:
		_process_message_queue()

func _wait_messages_done():
	if is_printing_message or not message_queue.is_empty():
		await messages_finished

func _process_message_queue():
	is_printing_message = true
	_set_ui_buttons_disabled(true)

	while not message_queue.is_empty():
		var msg = message_queue.pop_front()

		for msg_char in msg:
			message_log.text += msg_char
			# サウンドを再生 (一文字ごと)
			if msg_char != " " and msg_char != "　":
				audio_player.play()
			# 次の文字を表示する前に少し待つ
			await get_tree().create_timer(0.02).timeout

		message_log.text += "\n"

	is_printing_message = false
	_set_ui_buttons_disabled(false)
	messages_finished.emit()

func _set_ui_buttons_disabled(disabled: bool) -> void:
	for btn in skill_buttons:
		btn.disabled = disabled
	return_to_title_button.disabled = disabled
	mute_button.disabled = disabled

func _set_action_state(active: bool):
	is_processing_action = active

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

	var active_skill = player_skills[active_skill_index] if player_skills.size() > 0 else ""

	for enemy in map_data.enemies:
		var e_char = enemy.char
		var key = active_skill + "_" + e_char
		var mapped_char = e_char
		if active_skill != "":
			var color: String
			if Global.known_effectiveness.has(key):
				color = COLOR_WIN if Global.known_effectiveness[key] else COLOR_LOSS
			else:
				color = COLOR_UNKNOWN
			mapped_char = "[color=%s]%s[/color]" % [color, e_char]
		grid[enemy.pos.y][enemy.pos.x] = mapped_char

	grid[player_pos.y][player_pos.x] = "[color=%s]@[/color]" % COLOR_PLAYER

	var fov_visible = _compute_fov()

	var map_str = ""
	var max_y = grid.size()
	var max_x = grid[0].size()

	for y in range(max_y):
		var row_str = ""
		var current_color = ""
		for x in range(max_x):
			if fov_visible[y][x]:
				if current_color != "":
					row_str += "[/color]"
					current_color = ""
				row_str += str(grid[y][x])
			elif map_data.discovered[y][x]:
				if current_color != COLOR_DISCOVERED:
					if current_color != "": row_str += "[/color]"
					row_str += "[color=%s]" % COLOR_DISCOVERED
					current_color = COLOR_DISCOVERED
				var t = map_data.grid[y][x]
				if map_data.has("stairs_pos") and map_data.stairs_pos == Vector2(x, y):
					t = ">"
				row_str += t
			else:
				if current_color != "":
					row_str += "[/color]"
					current_color = ""
				row_str += " "
		if current_color != "":
			row_str += "[/color]"
		map_str += row_str + "\n"

	map_label.text = map_str

func _compute_fov() -> Array:
	var max_y = map_data.grid.size()
	var max_x = map_data.grid[0].size()

	if not map_data.has("discovered"):
		map_data.discovered = []
		for y in range(max_y):
			var arr = []
			arr.resize(max_x)
			arr.fill(false)
			map_data.discovered.append(arr)

	var fov_visible = []
	for y in range(max_y):
		var arr = []
		arr.resize(max_x)
		arr.fill(false)
		fov_visible.append(arr)

	var p_x = int(player_pos.x)
	var p_y = int(player_pos.y)

	fov_visible[p_y][p_x] = true
	map_data.discovered[p_y][p_x] = true

	for i in range(-FOV_RADIUS, FOV_RADIUS + 1):
		for j in range(-FOV_RADIUS, FOV_RADIUS + 1):
			if i == -FOV_RADIUS or i == FOV_RADIUS or j == -FOV_RADIUS or j == FOV_RADIUS:
				var target_x = p_x + i
				var target_y = p_y + j
				var line = _get_line(p_x, p_y, target_x, target_y)
				for p in line:
					var px = int(p.x)
					var py = int(p.y)
					if px < 0 or px >= max_x or py < 0 or py >= max_y:
						break

					if (px - p_x) * (px - p_x) + (py - p_y) * (py - p_y) > FOV_RADIUS * FOV_RADIUS:
						break

					fov_visible[py][px] = true
					map_data.discovered[py][px] = true

					var c = map_data.grid[py][px]
					if c == "-" or c == "|" or c == " ":
						break

	return fov_visible

func _get_line(x0: int, y0: int, x1: int, y1: int) -> Array:
	var points = []
	var dx = abs(x1 - x0)
	var sx = 1 if x0 < x1 else -1
	var dy = - abs(y1 - y0)
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy

	var cx = x0
	var cy = y0

	while true:
		points.append(Vector2(cx, cy))
		if cx == x1 and cy == y1:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy

	return points

func _update_skills():
	floor_label.text = tr("MSG_FLOOR_LABEL").format({"floor": current_floor})
	for i in range(4):
		skill_buttons[i].visible = false
		skill_buttons[i].remove_theme_color_override("font_color")

	for i in range(player_skills.size()):
		skill_buttons[i].visible = true
		skill_buttons[i].text = tr(player_skills[i])
		if i == active_skill_index:
			skill_buttons[i].text = "[*] " + tr(player_skills[i])
			skill_buttons[i].add_theme_color_override("font_color", Color.YELLOW)

	if is_skill_replace_mode:
		skill_buttons[3].visible = true
		skill_buttons[3].text = "[NEW] " + tr(temp_new_skill)
		skill_buttons[3].add_theme_color_override("font_color", Color.GREEN)
	elif not map_data.is_empty() and map_data.has("stairs_pos") and player_pos == map_data.stairs_pos:
		skill_buttons[3].visible = true
		skill_buttons[3].text = tr("DESC_GO_DOWN")
		skill_buttons[3].add_theme_color_override("font_color", Color.CYAN)

func _on_skill_button_pressed(idx: int):
	# ボタンのフォーカスを外さないとキー入力が吸われる
	skill_buttons[idx].release_focus()
	if map_data.is_empty() or is_processing_action: # ゲームオーバー時の押下処理をスキップ
		return

	_set_action_state(true)
	await _handle_skill_button(idx)
	_set_action_state(false)

func _handle_skill_button(idx: int):
	if is_skill_replace_mode:
		if idx < 3 and idx < player_skills.size():
			_log_message(tr("MSG_REPLACE_SKILL").format({"old": tr(player_skills[idx]), "new": tr(temp_new_skill)}))
			await _wait_messages_done()
			player_skills[idx] = temp_new_skill
			is_skill_replace_mode = false
			temp_new_skill = ""
			_update_ui()
			await _process_enemies_turn()
		elif idx == 3:
			_log_message(tr("MSG_GIVE_UP_SKILL").format({"skill": tr(temp_new_skill)}))
			await _wait_messages_done()
			is_skill_replace_mode = false
			temp_new_skill = ""
			_update_ui()
			await _process_enemies_turn()
	elif map_data.has("stairs_pos") and player_pos == map_data.stairs_pos and idx == 3:
		# 階段の上にいて「下に降りる」を押した
		if current_floor == 5:
			_log_message(tr("MSG_GAME_CLEAR"))
			await _wait_messages_done()
			map_data.clear()
			_update_ui()
			_game_over(true)
		else:
			current_floor += 1
			Global.save_data()
			await _load_floor()
	else:
		if idx < player_skills.size():
			active_skill_index = idx
			_log_message(tr("MSG_CHANGE_SKILL").format({"skill": tr(player_skills[idx])}))
			await _wait_messages_done()
			_update_ui()

func _execute_movement(dir: Vector2):
	_set_action_state(true)
	await _move(dir)
	_set_action_state(false)

func _move(dir: Vector2):
	var next_pos = player_pos + dir

	if map_data.is_empty() or not map_data.has("grid"): return
	var max_y = map_data.grid.size()
	var max_x = map_data.grid[0].size()

	if next_pos.x < 0 or next_pos.x >= max_x or next_pos.y < 0 or next_pos.y >= max_y:
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
		await _combat(hit_enemy_idx)
		if not map_data.is_empty():
			await _process_enemies_turn()
		return

	if player_pos != next_pos:
		player_pos = next_pos
		walk_audio_player.play()
		_update_ui() # 移動直後に画面反映
		await get_tree().create_timer(0.05).timeout

	var picked_item_idx = -1
	for i in range(map_data.items.size()):
		if map_data.items[i] == player_pos:
			picked_item_idx = i
			break

	if picked_item_idx != -1:
		map_data.items.remove_at(picked_item_idx)
		var new_skill = _get_random_skill()
		_log_message(tr("MSG_FIND_SKILL").format({"skill": tr(new_skill)}))
		await _wait_messages_done()

		if player_skills.size() < 3:
			player_skills.append(new_skill)
			_update_ui()
		else:
			is_skill_replace_mode = true
			temp_new_skill = new_skill
			_log_message(tr("MSG_SKILL_FULL"))
			await _wait_messages_done()
			_update_ui()
			return

	if map_data.has("stairs_pos") and player_pos == map_data.stairs_pos:
		_log_message(tr("MSG_FIND_STAIRS"))
		await _wait_messages_done()
		_update_ui() # スキルボタンを表示するためにUIを更新

	if not is_skill_replace_mode:
		await _process_enemies_turn()

func _process_enemies_turn():
	if map_data.is_empty(): return
	var indices_to_remove = []
	for i in range(map_data.enemies.size()):
		var enemy = map_data.enemies[i]
		var e_char = enemy.char
		var enemy_data = EnemyData.ENEMIES[e_char]

		var dist = abs(enemy.pos.x - player_pos.x) + abs(enemy.pos.y - player_pos.y)

		if dist <= enemy_data.agro_range:
			# XかYで近づく
			var dx = sign(player_pos.x - enemy.pos.x)
			var dy = sign(player_pos.y - enemy.pos.y)
			var n_pos = enemy.pos

			var max_y = map_data.grid.size()
			var max_x = map_data.grid[0].size()

			var try_positions = []
			if dx != 0:
				try_positions.append(Vector2(enemy.pos.x + dx, enemy.pos.y))
			if dy != 0:
				try_positions.append(Vector2(enemy.pos.x, enemy.pos.y + dy))

			for t_pos in try_positions:
				if t_pos.x >= 0 and t_pos.x < max_x and t_pos.y >= 0 and t_pos.y < max_y:
					var c = map_data.grid[t_pos.y][t_pos.x]
					if c == "#" or c == "+" or c == ".":
						var has_enemy = false
						if t_pos != player_pos:
							for j in range(map_data.enemies.size()):
								if i != j and map_data.enemies[j].pos == t_pos:
									has_enemy = true
									break
						if not has_enemy:
							n_pos = t_pos
							break

			enemy.pos = n_pos

			if enemy.pos == player_pos:
				_log_message(tr("MSG_ENEMY_ATTACK").format({"name": tr(enemy_data.name), "skill": tr(enemy_data.skill)}))
				await _wait_messages_done()

				var is_player_dead = await _combat(i)
				if is_player_dead:
					return # 戦闘で死んだら終了
				else:
					indices_to_remove.append(i)

	# プレイヤーの反撃で死んだ敵を消す(敵から接触してきた場合)
	for i in range(indices_to_remove.size() - 1, -1, -1):
		map_data.enemies.remove_at(indices_to_remove[i])

	if not map_data.is_empty():
		_update_ui()

func _combat(enemy_idx: int) -> bool:
	var enemy = map_data.enemies[enemy_idx]
	var e_char = enemy.char
	var enemy_data = EnemyData.ENEMIES[e_char]
	var skill = player_skills[active_skill_index]
	var result = ItemData.COMBAT_RESULTS[skill][e_char]

	Global.known_effectiveness[skill + "_" + e_char] = result.win

	_log_message(tr(result.message))
	await _wait_messages_done()

	if result.win:
		_log_message(tr("MSG_DEFEAT_ENEMY").format({"name": tr(enemy_data.name)}))
		await _wait_messages_done()

		# プレイヤーから発信された攻撃ならここで削除
		if player_pos != enemy.pos:
			map_data.enemies.remove_at(enemy_idx)

		_update_ui()
		return false # 死亡していない
	else:
		_log_message(tr("MSG_GAME_OVER"))
		await _wait_messages_done()

		map_data.clear()
		_update_ui()
		_game_over(false)
		return true

func _game_over(is_clear: bool = false):
	var unlock_amount = current_floor
	if is_clear:
		unlock_amount = 6

	if Global.INITIAL_SKILL_POOL_SIZE + Global.unlocked_skills_count < ItemData.SKILLS.size():
		Global.unlock_next(unlock_amount)
	else:
		Global.save_data()
	return_to_title_button.text = tr("MSGUI_RETURN_TITLE")
	return_to_title_button.visible = true

func _on_return_to_title_pressed():
	get_tree().change_scene_to_file("res://title.tscn")
