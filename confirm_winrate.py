import re
import os

def parse_enemy_data(file_path):
    enemies = {}
    if not os.path.exists(file_path):
        return enemies
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    # Match "ID": { ..., "level": N, ... }
    matches = re.finditer(r'"([A-Z])":\s*\{[^}]*"level":\s*(\d+)', content)
    for m in matches:
        enemies[m.group(1)] = int(m.group(2))
    return enemies

def parse_combat_results(file_path):
    import json
    if not os.path.exists(file_path):
        return {}, 0

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        num_skills = len(data)
        enemy_wins = {eid: 0 for eid in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"}

        for skill_results in data.values():
            if isinstance(skill_results, dict):
                for eid, result in skill_results.items():
                    if isinstance(result, dict) and result.get("win") == True:
                        enemy_wins[eid] = enemy_wins.get(eid, 0) + 1

        return enemy_wins, num_skills
    except Exception as e:
        print(f"Error: Failed to parse {file_path}. {e}")
        return {}, 0

def main():
    # Look for data files in the current working directory
    enemy_file = 'enemy_data.gd'
    item_file = 'combat_results.json'

    if not os.path.exists(enemy_file) or not os.path.exists(item_file):
        print(f"Error: Missing data files in current directory.")
        print(f"Required: {enemy_file} and {item_file}")
        return

    enemies = parse_enemy_data(enemy_file)
    enemy_wins, num_skills = parse_combat_results(item_file)

    if not enemies or num_skills == 0:
        print("Error: Could not parse data files.")
        return

    print(f"Analysis of Combat Balance")
    print(f"Total Skills: {num_skills}")
    print("-" * 40)

    level_stats = {} # level -> [wins, total_possible]

    # Target rates for display
    targets = {1: 90, 2: 70, 3: 50, 4: 30, 5: 10}

    for eid, level in enemies.items():
        wins = enemy_wins.get(eid, 0)
        if level not in level_stats:
            level_stats[level] = [0, 0]
        level_stats[level][0] += wins
        level_stats[level][1] += num_skills

    print(f"{'Level':<10} | {'Wins/Total':<15} | {'Actual %':<10} | {'Target %':<10}")
    print("-" * 55)

    for level in sorted(level_stats.keys()):
        wins, total = level_stats[level]
        rate = (wins / total) * 100 if total > 0 else 0
        target = targets.get(level, 0)
        print(f"LV{level:<8} | {wins:<5}/{total:>5} | {rate:>8.1f}% | {target:>8}%")

if __name__ == "__main__":
    main()
