import re

def count_skills():
    file_path = r'c:\Users\horah\Documents\kumopaku\item_data.gd'
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    start_match = re.search(r'const COMBAT_RESULTS = \{', content)
    if not start_match:
        return

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

    dict_str = content[start_idx:end_idx]
    # Simple count of top level keys like "SkillName": {
    # Match strings inside " " followed by : {
    keys = re.findall(r'"([^"]+)":\s*\{', dict_str)
    # The regex might find char keys too "A": {
    # We want only the skills.
    # Skills are at depth 1.

    # Let's just print them
    # Actually, the skills are followed by { and then "A": {
    # So we can look for strings at the beginning of lines after a tab
    skills = re.findall(r'\n\t"([^"]+)":\s*\{', dict_str)
    print(f"Total skills found: {len(skills)}")
    print(skills)

if __name__ == "__main__":
    count_skills()
