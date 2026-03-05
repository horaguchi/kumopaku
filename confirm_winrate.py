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

def parse_item_data(file_path):
    if not os.path.exists(file_path):
        return {}, 0
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the COMBAT_RESULTS dictionary content
    # We look for the first '{' after 'const COMBAT_RESULTS =' and find the matching '}'
    start_match = re.search(r'const COMBAT_RESULTS = \{', content)
    if not start_match:
        return {}, 0

    start_idx = start_match.end() - 1
    depth = 0
    end_idx = -1
    for i in range(start_idx, len(content)):
        if content[i] == '{': depth += 1
        elif content[i] == '}':
            depth -= 1
            if depth == 0:
                end_idx = i + 1
                break

    if end_idx == -1:
        return {}, 0

    dict_str = content[start_idx:end_idx]

    # Clean up GDScript-specific syntax to make it valid JSON
    # 1. Remove trailing commas (valid in GDScript, invalid in JSON)
    dict_str = re.sub(r',\s*(?=[}\]])', '', dict_str)

    # 2. Convert any single quotes to double quotes (if any exist)
    # Note: This is a simple replacement and might break if strings contain escaped quotes,
    # but in our current item_data.gd we only use double quotes.
    # dict_str = dict_str.replace("'", '"')

    try:
        import json
        data = json.loads(dict_str)

        num_skills = len(data)
        enemy_wins = {eid: 0 for eid in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"}

        for skill_results in data.values():
            if isinstance(skill_results, dict):
                for eid, result in skill_results.items():
                    if isinstance(result, dict) and result.get("win") == True:
                        enemy_wins[eid] = enemy_wins.get(eid, 0) + 1

        return enemy_wins, num_skills
    except Exception as e:
        print(f"Error: Failed to parse item_data.gd as JSON. {e}")
        return {}, 0

def main():
    # Look for data files in the current working directory
    enemy_file = 'enemy_data.gd'
    item_file = 'item_data.gd'

    if not os.path.exists(enemy_file) or not os.path.exists(item_file):
        print(f"Error: Missing data files in current directory.")
        print(f"Required: {enemy_file} and {item_file}")
        return

    enemies = parse_enemy_data(enemy_file)
    enemy_wins, num_skills = parse_item_data(item_file)

    if not enemies or num_skills == 0:
        print("Error: Could not parse data files. Check if they are valid Godot scripts.")
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
