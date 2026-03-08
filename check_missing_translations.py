import json
import csv
import glob
import os

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
COMBAT_RESULTS_JSON = os.path.join(PROJECT_DIR, "combat_results.json")
OUTPUT_FILE = os.path.join(PROJECT_DIR, "result.txt")

LANGUAGES = ["en", "ja", "zh", "ru", "es", "pt", "de", "ko"]

# --- Step 1: combat_results.json から全メッセージキーを収集 ---
with open(COMBAT_RESULTS_JSON, encoding="utf-8") as f:
    combat = json.load(f)

required_keys = set()
for skill, enemies in combat.items():
    for enemy, data in enemies.items():
        msg_key = data.get("message", "")
        if msg_key:
            required_keys.add(msg_key)

print(f"[INFO] combat_results.json から {len(required_keys)} 件のメッセージキーを抽出")

# --- Step 2: localization_msg_*.csv から翻訳済みキーと各言語の状況を収集 ---
csv_files = sorted(glob.glob(os.path.join(PROJECT_DIR, "localization_msg_*.csv")))
print(f"[INFO] {len(csv_files)} 件の CSV ファイルを読み込み中...")

# { key: { lang: translated_text } }
translations = {}

for csv_path in csv_files:
    with open(csv_path, encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames  # ["keys", "en", "ja", ...]
        for row in reader:
            key = row.get("keys", "").strip()
            if not key:
                continue
            if key not in translations:
                translations[key] = {}
            for lang in LANGUAGES:
                if lang in row:
                    val = row[lang].strip()
                    if val:
                        translations[key][lang] = val

# --- Step 3: 不足しているキー・言語を特定 ---
missing = []  # [(key, [missing_langs])]
completely_missing = []  # キー自体がない

for key in sorted(required_keys):
    if key not in translations:
        completely_missing.append(key)
    else:
        missing_langs = [lang for lang in LANGUAGES if lang not in translations[key] or not translations[key][lang]]
        if missing_langs:
            missing.append((key, missing_langs))

# --- Step 4: result.txt に出力 ---
with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write("=" * 70 + "\n")
    f.write("未翻訳キー チェック結果\n")
    f.write("=" * 70 + "\n\n")

    f.write(f"対象キー数 (combat_results.json): {len(required_keys)}\n")
    f.write(f"CSVファイル数: {len(csv_files)}\n\n")

    # --- 完全に存在しないキー ---
    f.write(f"【キー自体が存在しない】 {len(completely_missing)} 件\n")
    f.write("-" * 70 + "\n")
    if completely_missing:
        for key in completely_missing:
            f.write(f"  {key}\n")
    else:
        f.write("  (なし)\n")
    f.write("\n")

    # --- 一部言語が不足しているキー ---
    f.write(f"【一部言語が不足】 {len(missing)} 件\n")
    f.write("-" * 70 + "\n")
    if missing:
        for key, langs in missing:
            f.write(f"  {key}  [不足: {', '.join(langs)}]\n")
    else:
        f.write("  (なし)\n")
    f.write("\n")

    total_issues = len(completely_missing) + len(missing)
    f.write("=" * 70 + "\n")
    f.write(f"合計問題数: {total_issues} 件\n")
    f.write("=" * 70 + "\n")

print(f"[DONE] result.txt に書き込みました")
print(f"  完全欠落キー: {len(completely_missing)} 件")
print(f"  一部言語不足: {len(missing)} 件")
