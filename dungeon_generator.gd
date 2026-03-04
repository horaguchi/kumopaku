class_name DungeonGenerator
extends RefCounted

const WIDTH = 32
const HEIGHT = 9

# {
#   "grid": [ ["#", ...], ... ], # 16x9の文字列配列の配列 (#: 壁, .: 床)
#   "start_pos": Vector2,
#   "stairs_pos": Vector2,
#   "items": [ Vector2, ... ],
#   "enemies": [ Vector2, ... ]
# }
static func generate(floor_num: int) -> Dictionary:
	var grid := []
	for y in range(HEIGHT):
		var row := []
		for x in range(WIDTH):
			row.append("#")
		grid.append(row)

	# 酔歩法で床 "." を掘る
	var x = randi_range(1, WIDTH - 2)
	var y = randi_range(1, HEIGHT - 2)
	var carved_cells := []

	var target_cells = 65 # 床の数

	# 無限ループ防止用のカウンター
	var failsafe = 0
	while carved_cells.size() < target_cells and failsafe < 2000:
		failsafe += 1
		if grid[y][x] == "#":
			grid[y][x] = "."
			carved_cells.append(Vector2(x, y))

		var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		dirs.shuffle()
		for d in dirs:
			var nx = x + int(d.x)
			var ny = y + int(d.y)
			# 周囲1マスは壁として残す
			if nx >= 1 and nx < WIDTH - 1 and ny >= 1 and ny < HEIGHT - 1:
				x = nx
				y = ny
				break

	# シャッフルして各エンティティの配置を決める
	carved_cells.shuffle()

	var start_pos = carved_cells.pop_back()
	var stairs_pos = carved_cells.pop_back()

	var num_items = randi_range(2, 4)
	var items = []
	for i in range(num_items):
		if carved_cells.size() > 0:
			items.append(carved_cells.pop_back())

	var num_enemies = 2 + floor_num # フロアがあがると敵が増える
	var enemies = []
	for i in range(num_enemies):
		if carved_cells.size() > 0:
			enemies.append(carved_cells.pop_back())

	return {
		"grid": grid,
		"start_pos": start_pos,
		"stairs_pos": stairs_pos,
		"items": items,
		"enemies": enemies
	}
