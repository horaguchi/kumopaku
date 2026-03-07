import sys
import os
import csv

CSV_FILE = 'localization.csv'
EXPECTED_COLUMNS = 4

def validate_localization_csv():
    """CSV全体の妥当性をチェックする。"""
    if not os.path.exists(CSV_FILE):
        print(f"Error: {CSV_FILE} not found.")
        return False

    is_valid = True
    try:
        with open(CSV_FILE, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            for i, row in enumerate(reader, start=1):
                # 空行チェック
                if not row:
                    print(f"L{i}: Error - Empty line detected.")
                    is_valid = False
                    continue

                # カラム数チェック
                if len(row) != EXPECTED_COLUMNS:
                    print(f"L{i}: Error - Expected {EXPECTED_COLUMNS} columns, but found {len(row)}: {row}")
                    is_valid = False

    except csv.Error as e:
        print(f"L{i}: CSV formatting error: {e}")
        is_valid = False
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        is_valid = False

    if is_valid:
        print("Success: All lines are valid.")
    else:
        print("Validation FAILED.")

    return is_valid

def add_localization_entry(key, en, ja, zh):
    """新しいエントリを追加、または既存のキーを更新する。"""

    # 事前バリデーション
    print(f"Validating {CSV_FILE} before adding/updating...")
    if not validate_localization_csv():
        print("Aborting due to existing CSV errors. Please fix the CSV first.")
        return

    try:
        rows = []
        updated = False

        # 既存の内容を読み込む
        if os.path.exists(CSV_FILE):
            with open(CSV_FILE, 'r', encoding='utf-8') as f:
                reader = csv.reader(f)
                for row in reader:
                    if row and row[0] == key:
                        rows.append([key, en, ja, zh])
                        updated = True
                        print(f"Key '{key}' already exists. Overwriting with new content...")
                    else:
                        rows.append(row)

        # キーが見つからなかった場合は末尾に追加
        if not updated:
            rows.append([key, en, ja, zh])

        # ファイルに書き出す
        with open(CSV_FILE, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f, quoting=csv.QUOTE_ALL, lineterminator='\n')
            writer.writerows(rows)

        if updated:
            print(f"Successfully UPDATED entry: {key}")
        else:
            print(f"Successfully ADDED entry: {key}")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    # バリデーションのみのモード
    if len(sys.argv) == 2 and sys.argv[1] == "--validate":
        validate_localization_csv()
        sys.exit(0)

    # 追加モード
    if len(sys.argv) != 5:
        print("Usage:")
        print("  Add:      python add_localization.py <KEY> <EN> <JA> <ZH>")
        print("  Validate: python add_localization.py --validate")
        sys.exit(1)

    key_arg, en_arg, ja_arg, zh_arg = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
    add_localization_entry(key_arg, en_arg, ja_arg, zh_arg)
