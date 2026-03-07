import sys
import os
import csv

MAIN_CSV = 'localization.csv'
EXPECTED_COLUMNS = 4
HEADER = ['keys', 'en', 'ja', 'zh']


def get_csv_file_for_key(key):
    """
    キーに応じて書き込む CSV ファイルパスを返す。
    MSG_C_X*** 形式のキーは localization_msg_x.csv へ。
    それ以外は localization.csv へ。
    """
    if key.startswith('MSG_C_') and len(key) > 6:
        letter = key[6].lower()
        return f'localization_msg_{letter}.csv'
    return MAIN_CSV


def validate_localization_csv(csv_file=None):
    """CSV全体の妥当性をチェックする。csv_file を指定しない場合は MAIN_CSV を使用。"""
    target = csv_file or MAIN_CSV
    if not os.path.exists(target):
        print(f"Error: {target} not found.")
        return False

    is_valid = True
    i = 0
    try:
        with open(target, 'r', encoding='utf-8') as f:
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
        print(f"Success: All lines in {target} are valid.")
    else:
        print(f"Validation FAILED for {target}.")

    return is_valid


def validate_all():
    """MAIN_CSV と全ての localization_msg_*.csv を検証する。"""
    files_to_check = [MAIN_CSV]
    import glob
    files_to_check += sorted(glob.glob('localization_msg_*.csv'))

    all_valid = True
    for f in files_to_check:
        if not validate_localization_csv(f):
            all_valid = False
    return all_valid


def add_localization_entry(key, en, ja, zh):
    """新しいエントリを追加、または既存のキーを更新する。"""

    target_csv = get_csv_file_for_key(key)

    # 事前バリデーション
    print(f"Validating {target_csv} before adding/updating...")
    if not validate_localization_csv(target_csv):
        print("Aborting due to existing CSV errors. Please fix the CSV first.")
        return

    try:
        rows = []
        updated = False
        header_exists = False

        # 既存の内容を読み込む
        if os.path.exists(target_csv):
            with open(target_csv, 'r', encoding='utf-8') as f:
                reader = csv.reader(f)
                for row in reader:
                    if row and row[0] == 'keys':
                        header_exists = True
                    if row and row[0] == key:
                        rows.append([key, en, ja, zh])
                        updated = True
                        print(f"Key '{key}' already exists. Overwriting with new content...")
                    else:
                        rows.append(row)

        # サブファイルにヘッダーがない場合は先頭に追加
        if not header_exists and target_csv != MAIN_CSV:
            rows.insert(0, HEADER)

        # キーが見つからなかった場合は末尾に追加
        if not updated:
            rows.append([key, en, ja, zh])

        # ファイルに書き出す
        with open(target_csv, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f, quoting=csv.QUOTE_ALL, lineterminator='\n')
            writer.writerows(rows)

        if updated:
            print(f"Successfully UPDATED entry: {key} -> {target_csv}")
        else:
            print(f"Successfully ADDED entry: {key} -> {target_csv}")

    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    # バリデーションのみのモード
    if len(sys.argv) == 2 and sys.argv[1] == "--validate":
        validate_all()
        sys.exit(0)

    # 追加モード
    if len(sys.argv) != 5:
        print("Usage:")
        print("  Add:      python add_localization.py <KEY> <EN> <JA> <ZH>")
        print("  Validate: python add_localization.py --validate")
        sys.exit(1)

    key_arg, en_arg, ja_arg, zh_arg = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
    add_localization_entry(key_arg, en_arg, ja_arg, zh_arg)
