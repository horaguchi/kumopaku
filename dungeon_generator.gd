class_name DungeonGenerator
extends RefCounted

static func generate(floor_num: int) -> Dictionary:
	var result = {}
	while result.is_empty():
		result = _try_generate(floor_num)
	return result

static func _try_generate(floor_num: int) -> Dictionary:
	# 階層に応じたパラメータ設定
	# 階が進むにつれ、マップサイズ、部屋数、部屋のサイズが増加していく
	var width = 36 + (floor_num - 1) * 6
	var height = 10 + (floor_num - 1)

	var straightness := 0.75
	var sparseness := 0.90
	var add_loops := 0.50

	var room_count = 4 + (floor_num - 1)
	var room_width_min := 4
	var room_width_max := 9
	var room_height_min := 3
	var room_height_max := 7

	var map := []
	for i in range(height):
		var line := []
		for j in range(width):
			line.append(" ")
		map.append(line)

	_maze(map, width, height, straightness, sparseness, add_loops)
	_put_rooms(map, width, height, room_count, [room_width_min, room_width_max], [room_height_min, room_height_max])

	if not _is_fully_connected(map, width, height):
		return {}

	var carved_cells := []
	for y in range(height):
		for x in range(width):
			var c = map[y][x]
			if c == ".":
				# アイテムやエンティティを配置可能な場所（床のみ）
				carved_cells.append(Vector2(x, y))

	carved_cells.shuffle()

	var start_pos = Vector2.ZERO
	var stairs_pos = Vector2.ZERO
	if carved_cells.size() >= 2:
		start_pos = carved_cells.pop_back()
		stairs_pos = carved_cells.pop_back()

	var num_items = randi_range(2, 4)
	var items = []
	for i in range(num_items):
		if carved_cells.size() > 0:
			items.append(carved_cells.pop_back())

	var num_enemies = randi_range(4 + floor_num, 6 + int(floor_num * 2))
	var enemies = []
	for i in range(num_enemies):
		if carved_cells.size() > 0:
			enemies.append(carved_cells.pop_back())

	return {
		"grid": map,
		"start_pos": start_pos,
		"stairs_pos": stairs_pos,
		"items": items,
		"enemies": enemies
	}

static func _put_rooms(map: Array, width: int, height: int, room_count: int, x_range: Array, y_range: Array):
	var rooms := []
	for i in range(room_count):
		var rw = randi_range(x_range[0], x_range[1])
		var rh = randi_range(y_range[0], y_range[1])
		_make_room(map, width, height, rw, rh, rooms)

static func _make_room(map: Array, width: int, height: int, room_w: int, room_h: int, rooms: Array):
	var bx = -1
	var by = -1
	var bx2 = -1
	var by2 = -1
	var best = width * height * 1000

	for i in range(height - room_h + 1):
		for j in range(width - room_w + 1):
			var overlap = false
			for room in rooms:
				if room[0] - room_w < j and j <= room[2] and room[1] - room_h < i and i <= room[3]:
					overlap = true
					break

			var temp = best if overlap else _search_weight(map, width, height, j, i, j + room_w - 1, i + room_h - 1)
			if temp > 0 and temp < best: # In JS it was `if (temp && temp < best)`, so temp > 0 since it returns overlap + corridor which is > 0
				best = temp
				bx = j
				by = i
				bx2 = j + room_w - 1
				by2 = i + room_h - 1

	if best == width * height * 1000 or bx == -1:
		return

	for i in range(by, by2 + 1):
		var line = map[i]
		for j in range(bx, bx2 + 1):
			if i == by or i == by2:
				line[j] = "-"
			elif j == bx or j == bx2:
				line[j] = "|"
			else:
				line[j] = "."

	_draw_door(map, width, height, bx, by, bx2, by2)
	rooms.append([bx, by, bx2, by2])

static func _draw_door(map: Array, width: int, height: int, x: int, y: int, x2: int, y2: int):
	var l_before = false
	var r_before = false

	for i in range(y, y2 + 1):
		# 四隅は除外する (i == y または i == y2 の時は角なのでスキップ)
		if i == y or i == y2:
			l_before = false
			r_before = false
			continue

		var line = map[i]
		if not l_before and x != 0 and (line[x - 1] == "#" or line[x - 1] == "+"):
			line[x] = "+"
			l_before = true
		else:
			l_before = false

		if not r_before and x2 != width - 1 and (line[x2 + 1] == "#" or line[x2 + 1] == "+"):
			line[x2] = "+"
			r_before = true
		else:
			r_before = false

	var before = false
	if y != 0:
		var line = map[y - 1]
		for j in range(x, x2 + 1):
			# 四隅は除外する
			if j == x or j == x2:
				before = false
				continue

			if not before and (line[j] == "#" or line[j] == "+"):
				map[y][j] = "+"
				before = true
			else:
				before = false

	before = false
	if y2 != height - 1:
		var line = map[y2 + 1]
		for j in range(x, x2 + 1):
			# 四隅は除外する
			if j == x or j == x2:
				before = false
				continue

			if not before and (line[j] == "#" or line[j] == "+"):
				map[y2][j] = "+"
				before = true
			else:
				before = false

static func _search_weight(map: Array, width: int, height: int, x: int, y: int, x2: int, y2: int) -> int:
	var overlap = 0
	var corridor = 0

	for i in range(y, y2 + 1):
		var line = map[i]
		if i != y and i != y2:
			corridor += (1 if x != 0 and line[x - 1] == "#" else 100 if x != 0 and line[x - 1] == "+" else 0) + \
						(1 if x2 != width - 1 and line[x2 + 1] == "#" else 100 if x2 != width - 1 and line[x2 + 1] == "+" else 0)
		else:
			corridor += (200 if x != 0 and line[x - 1] == "#" else 400 if x != 0 and line[x - 1] == "+" else 0) + \
						(200 if x2 != width - 1 and line[x2 + 1] == "#" else 400 if x2 != width - 1 and line[x2 + 1] == "+" else 0)

		for j in range(x, x2 + 1):
			match line[j]:
				"#": overlap += 3
				".", "|", "-", "+": overlap += 100
				_: pass

	if y != 0:
		var line = map[y - 1]
		for j in range(x, x2 + 1):
			if j != x and j != x2:
				corridor += 1 if line[j] == "#" else 100 if line[j] == "+" else 0
			else:
				corridor += 200 if line[j] == "#" else 400 if line[j] == "+" else 0

	if y2 != height - 1:
		var line = map[y2 + 1]
		for j in range(x, x2 + 1):
			if j != x and j != x2:
				corridor += 1 if line[j] == "#" else 100 if line[j] == "+" else 0
			else:
				corridor += 200 if line[j] == "#" else 400 if line[j] == "+" else 0

	return overlap + corridor if corridor > 0 else 0

static func _maze(map: Array, width: int, height: int, straightness: float, sparseness: float, add_loops: float):
	var wei := []
	for i in range(height):
		var line := []
		for j in range(width):
			line.append(0)
		wei.append(line)

	var corridor_list := []
	var dead_end_list := []

	var cx = randi() % width
	var cy = randi() % height
	map[cy][cx] = "#"
	_update_weight(cx, cy, wei, width, height, false)
	corridor_list.append([cx, cy])

	while corridor_list.size() > 0:
		var key = randi() % corridor_list.size()
		cx = corridor_list[key][0]
		cy = corridor_list[key][1]

		var way = _check_next(cx, cy, wei, width, height, false)
		while way["arr"].size() > 0:
			var straight = _search_straight(cx, cy, wei)
			var chosen = 0

			if (way["next"] & straight) != 0 and randf() < straightness and straight != 0:
				chosen = straight
			else:
				chosen = way["arr"].pick_random()

			match chosen:
				1: cy -= 1
				2: cx += 1
				4: cy += 1
				8: cx -= 1

			map[cy][cx] = "#"
			_update_weight(cx, cy, wei, width, height, false)
			key = corridor_list.size()
			corridor_list.append([cx, cy])

			way = _check_next(cx, cy, wei, width, height, false)

		if _search_straight(cx, cy, wei) != 0:
			dead_end_list.append([cx, cy])

		corridor_list.remove_at(key)

	var sparse_count = dead_end_list.size() - int(dead_end_list.size() * sparseness)
	while dead_end_list.size() > sparse_count:
		var key = randi() % dead_end_list.size()
		cx = dead_end_list[key][0]
		cy = dead_end_list[key][1]
		dead_end_list.remove_at(key)
		map[cy][cx] = " "
		_update_weight(cx, cy, wei, width, height, true)

		var w_val = wei[cy][cx] & (2 + 8 + 32 + 128)
		match w_val:
			2: cy -= 1
			8: cx += 1
			32: cy += 1
			128: cx -= 1

		if _search_straight(cx, cy, wei) != 0:
			dead_end_list.append([cx, cy])

	for key in range(dead_end_list.size()):
		if randf() < add_loops:
			continue
		cx = dead_end_list[key][0]
		cy = dead_end_list[key][1]

		var way = _check_next(cx, cy, wei, width, height, true)
		while way["arr"].size() > 0:
			var straight = _search_straight(cx, cy, wei)
			var chosen = 0

			if (way["next"] & straight) != 0 and randf() < straightness and straight != 0:
				chosen = straight
			else:
				chosen = way["arr"].pick_random()

			match chosen:
				1: cy -= 1
				2: cx += 1
				4: cy += 1
				8: cx -= 1

			map[cy][cx] = "#"
			_update_weight(cx, cy, wei, width, height, false)
			way = _check_next(cx, cy, wei, width, height, true)

	return wei

static func _check_next(x: int, y: int, wei: Array, width: int, height: int, loop: bool) -> Dictionary:
	var next_val = 0
	var way_arr = []

	if y != 0 and ((wei[y - 1][x] & (1 + 2 + 4 + 8 + 128 + 256)) == 0 or (loop and (wei[y - 1][x] & (1 + 8 + 128)) == 0 and (wei[y - 1][x] & 2) != 0)):
		next_val += 1
		way_arr.append(1)
	if x != width - 1 and ((wei[y][x + 1] & (1 + 2 + 4 + 8 + 16 + 32)) == 0 or (loop and (wei[y][x + 1] & (1 + 2 + 32)) == 0 and (wei[y][x + 1] & 8) != 0)):
		next_val += 2
		way_arr.append(2)
	if y != height - 1 and ((wei[y + 1][x] & (1 + 8 + 16 + 32 + 64 + 128)) == 0 or (loop and (wei[y + 1][x] & (1 + 8 + 128)) == 0 and (wei[y + 1][x] & 32) != 0)):
		next_val += 4
		way_arr.append(4)
	if x != 0 and ((wei[y][x - 1] & (1 + 2 + 32 + 64 + 128 + 256)) == 0 or (loop and (wei[y][x - 1] & (1 + 2 + 32)) == 0 and (wei[y][x - 1] & 128) != 0)):
		next_val += 8
		way_arr.append(8)

	return {"next": next_val, "arr": way_arr}

static func _search_straight(x: int, y: int, wei: Array) -> int:
	match wei[y][x]:
		3, 263: return 4
		9, 29: return 8
		33, 113: return 1
		129, 449: return 2
		7: return 8 if (wei[y - 1][x + 1] & 2) != 0 else 4
		13: return 4 if (wei[y - 1][x + 1] & 8) != 0 else 8
		25: return 1 if (wei[y + 1][x + 1] & 8) != 0 else 8
		49: return 8 if (wei[y + 1][x + 1] & 32) != 0 else 1
		97: return 2 if (wei[y + 1][x - 1] & 32) != 0 else 1
		193: return 1 if (wei[y + 1][x - 1] & 128) != 0 else 2
		385: return 4 if (wei[y - 1][x - 1] & 128) != 0 else 2
		259: return 2 if (wei[y - 1][x - 1] & 2) != 0 else 4
		_: return 0

static func _update_weight(x: int, y: int, wei: Array, width: int, height: int, erase: bool):
	var sign_val = -1 if erase else 1
	wei[y][x] += 1 * sign_val
	if y != 0:
		wei[y - 1][x] += 32 * sign_val
	if x != width - 1 and y != 0:
		wei[y - 1][x + 1] += 64 * sign_val
	if x != width - 1:
		wei[y][x + 1] += 128 * sign_val
	if x != width - 1 and y != height - 1:
		wei[y + 1][x + 1] += 256 * sign_val
	if y != height - 1:
		wei[y + 1][x] += 2 * sign_val
	if x != 0 and y != height - 1:
		wei[y + 1][x - 1] += 4 * sign_val
	if x != 0:
		wei[y][x - 1] += 8 * sign_val
	if x != 0 and y != 0:
		wei[y - 1][x - 1] += 16 * sign_val

static func _is_fully_connected(map: Array, width: int, height: int) -> bool:
	var walkable_count = 0
	var start_pos := Vector2(-1, -1)

	for y in range(height):
		for x in range(width):
			var c = map[y][x]
			if c == "." or c == "#" or c == "+":
				walkable_count += 1
				if start_pos.x == -1:
					start_pos = Vector2(x, y)

	if walkable_count == 0:
		return true

	var visited := {}
	var queue := [start_pos]
	visited[start_pos] = true
	var connected_count = 0

	while queue.size() > 0:
		var curr = queue.pop_front()
		connected_count += 1

		var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		for d in dirs:
			var nx = int(curr.x + d.x)
			var ny = int(curr.y + d.y)
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				var c = map[ny][nx]
				if (c == "." or c == "#" or c == "+") and not visited.has(Vector2(nx, ny)):
					visited[Vector2(nx, ny)] = true
					queue.append(Vector2(nx, ny))

	return connected_count == walkable_count
