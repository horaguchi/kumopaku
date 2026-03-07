import json
import re

def extract_combat_results(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # COMBAT_RESULTS の中身を抽出
    match = re.search(r'const COMBAT_RESULTS = \{(.*)\}\n\n', content, re.DOTALL)
    if not match:
        # 最後の } の後に改行がない場合のフォールバック
        match = re.search(r'const COMBAT_RESULTS = \{(.*)\}', content, re.DOTALL)

    if not match:
        print("COMBAT_RESULTS not found")
        return None

    # 簡易的なパース（GDScriptの辞書をJSON互換にする）
    # 1. win: true -> "win": true
    # 2. win: false -> "win": false
    # 3. message: "..." -> "message": "..."
    # 4. "A": -> "A":

    data_str = match.group(1).strip()

    # キーをクォートで囲む（すでに囲まれているものもあるが、一貫性を持たせる）
    # "SkillName": {...} -> そのまま
    # "A": {...} -> そのまま

    # キーの置換 (win: -> "win":, message: -> "message":)
    data_str = re.sub(r'(\bwin\b):', r'"win":', data_str)
    data_str = re.sub(r'(\bmessage\b):', r'"message":', data_str)

    # GDScriptの辞書は最後がカンマで終わることがあるので、JSONとしては不正になる場合がある
    # }, } -> }, }
    # }, ] -> }, ]
    # ここでは json.loads が通るように調整する必要があるが、
    # 複雑なパースを避けるため、一旦ファイルに書き出してから Python の辞書として評価し、
    # その後 json.dump する

    # 安全な辞書評価のために、true/false を定義
    true = True
    false = False

    # 辞書として文字列を評価
    # 注意: 文字列の中に特殊な文字が含まれている場合は修正が必要
    try:
        combat_results = eval("{" + data_str + "}")
        return combat_results
    except Exception as e:
        print(f"Error evaluating dictionary: {e}")
        return None

file_path = r'c:\Users\horah\Documents\kumopaku\item_data.gd'
results = extract_combat_results(file_path)

if results:
    with open(r'c:\Users\horah\Documents\kumopaku\combat_results.json', 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=4)
    print("Successfully exported to combat_results.json")
else:
    print("Failed to export")
