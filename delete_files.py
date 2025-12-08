import os
import sys

def delete_files(file_paths):
    deleted_count = 0
    errors = []
    for file_path in file_paths:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                print(f"Successfully deleted: {file_path}")
                deleted_count += 1
            else:
                print(f"File not found, skipping: {file_path}")
        except OSError as e:
            error_message = f"Error deleting {file_path}: {e}"
            print(error_message, file=sys.stderr)
            errors.append(error_message)
    return deleted_count, errors

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python delete_files.py <file_path1> [file_path2 ...]", file=sys.stderr)
        sys.exit(1)

    files_to_delete = sys.argv[1:]
    deleted, errors = delete_files(files_to_delete)

    if errors:
        sys.exit(1) # Indicate failure if any errors occurred
    else:
        sys.exit(0)