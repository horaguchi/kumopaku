import sys
import os
import csv

MAIN_CSV = 'localization.csv'
HEADER = ['keys', 'en', 'ja', 'zh', 'ru', 'es', 'pt', 'de', 'ko']
EXPECTED_COLUMNS = len(HEADER)


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


def expand_row(row):
    """既存の行を最新のヘッダー数に合わせて拡張する。"""
    if not row:
        return row
    if len(row) < EXPECTED_COLUMNS:
        return row + [""] * (EXPECTED_COLUMNS - len(row))
    return row[:EXPECTED_COLUMNS]


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

                # カラム数チェック (バリデーション時は厳密にチェック)
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


def migrate_csv_to_new_format(target_csv):
    """既存の CSV を新しい 9 列フォーマットに変換する。"""
    if not os.path.exists(target_csv):
        return

    # すでに最新フォーマットかチェック
    try:
        with open(target_csv, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            header = next(reader, None)
            if header == HEADER:
                return # すでに最新
    except:
        pass

    print(f"Migrating {target_csv} to new {EXPECTED_COLUMNS}-column format...")
    try:
        rows = []
        with open(target_csv, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            for row in reader:
                if not row: continue
                if row[0] == 'keys':
                    rows.append(HEADER) # ヘッダーを最新のものに置き換え
                else:
                    rows.append(expand_row(row))

        with open(target_csv, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f, quoting=csv.QUOTE_ALL, lineterminator='\n')
            writer.writerows(rows)
        print(f"Migration successful for {target_csv}.")
    except Exception as e:
        print(f"Migration failed for {target_csv}: {e}")


def add_localization_entry(key, en, ja, zh, ru, es, pt, de, ko):
    """新しいエントリを追加、または既存のキーを更新する。"""

    target_csv = get_csv_file_for_key(key)

    # 既存ファイルがあれば、まずは形式をアップグレード
    if os.path.exists(target_csv):
        migrate_csv_to_new_format(target_csv)

    try:
        rows = []
        updated = False
        header_exists = False
        new_entry = [key, en, ja, zh, ru, es, pt, de, ko]

        # 既存の内容を読み込む
        if os.path.exists(target_csv):
            with open(target_csv, 'r', encoding='utf-8') as f:
                reader = csv.reader(f)
                for row in reader:
                    if not row: continue
                    if row[0] == 'keys':
                        header_exists = True
                        rows.append(HEADER)
                        continue
                    
                    if row[0] == key:
                        rows.append(new_entry)
                        updated = True
                        print(f"Key '{key}' already exists. Overwriting with new content...")
                    else:
                        rows.append(expand_row(row))

        # ヘッダーがない場合は先頭に追加
        if not header_exists:
            rows.insert(0, HEADER)

        # キーが見つからなかった場合は末尾に追加
        if not updated:
            rows.append(new_entry)

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
    # 全バリデーション
    if len(sys.argv) == 2 and sys.argv[1] == "--validate":
        validate_all()
        sys.exit(0)

    # 全マイグレーション（既存の全ファイルを新形式に変換）
    if len(sys.argv) == 2 and sys.argv[1] == "--migrate-all":
        import glob
        files = [MAIN_CSV] + sorted(glob.glob('localization_msg_*.csv'))
        for f in files:
            migrate_csv_to_new_format(f)
        sys.exit(0)

    # 追加モード
    if len(sys.argv) != 10:
        print("Usage:")
        print(f"  Add:      python add_localization.py <KEY> <EN> <JA> <ZH> <RU> <ES> <PT> <DE> <KO>")
        print("  Validate: python add_localization.py --validate")
        print("  Migrate:  python add_localization.py --migrate-all")
        sys.exit(1)

    key_arg = sys.argv[1]
    args = sys.argv[2:] # en, ja, zh, ru, es, pt, de, ko
    add_localization_entry(key_arg, *args)
