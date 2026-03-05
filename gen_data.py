import random
import os

random.seed(42)

enemies = {}
for i in range(26):
    char = chr(ord('A') + i)
    if i < 5: lvl, min_f, max_f, agro = 1, 1, 2, 3
    elif i < 10: lvl, min_f, max_f, agro = 2, 2, 3, 4
    elif i < 15: lvl, min_f, max_f, agro = 3, 3, 4, 5
    elif i < 20: lvl, min_f, max_f, agro = 4, 4, 5, 6
    else: lvl, min_f, max_f, agro = 5, 5, 5, 7
    enemies[char] = {'lvl': lvl, 'min_f': min_f, 'max_f': max_f, 'agro': agro}

# Write enemy_data.gd
with open('enemy_data.gd', 'w', encoding='utf-8') as f:
    f.write('class_name EnemyData\n')
    f.write('extends RefCounted\n\n')
    f.write('const ENEMIES = {\n')
    for char, d in enemies.items():
        skill_name = random.choice(['噛みつき', 'ひっかき', '体当たり', '飛びかかり', '毒液'])
        f.write(f'    "{char}": {{ "level": {d["lvl"]}, "min_floor": {d["min_f"]}, "max_floor": {d["max_f"]}, "agro_range": {d["agro"]}, "skill": "{skill_name}" }},\n')
    f.write('}\n')

skills = [
    '殴る', '斬る', '突く', '撃つ', '燃やす', '凍らせる', '罠', '呪う', '祈る', '逃げる',
    '説得', '隠れる', '騙す', '威圧', '媚びる', '買収', '毒', '歌う', '踊る', '気合'
]
win_counts = {1: 18, 2: 14, 3: 10, 4: 6, 5: 2}
win_map = {}
for char, d in enemies.items():
    lvl = d['lvl']
    wins = win_counts[lvl]
    skill_wins = [True]*wins + [False]*(20-wins)
    random.shuffle(skill_wins)
    win_map[char] = dict(zip(skills, skill_wins))

# Write item_data.gd
with open('item_data.gd', 'w', encoding='utf-8') as f:
    f.write('class_name ItemData\n')
    f.write('extends RefCounted\n\n')
    f.write('const SKILLS = [\n')
    for s in skills:
        f.write(f'    "{s}",\n')
    f.write(']\n\n')
    f.write('const COMBAT_RESULTS = {\n')
    for s in skills:
        f.write(f'    "{s}": {{\n')
        for char in enemies.keys():
            is_win = win_map[char][s]
            is_win_str = 'true' if is_win else 'false'
            msg = f'{s}で攻撃し、勝利した！' if is_win else f'{s}が効かず、敗北した...'
            f.write(f'        "{char}": {{ "win": {is_win_str}, "message": "{msg}" }},\n')
        f.write('    },\n')
    f.write('}\n')

print(f'Generated enemy_data.gd and item_data.gd in {os.getcwd()}')
