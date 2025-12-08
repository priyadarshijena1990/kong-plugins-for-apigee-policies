import argparse
import os
import re
from scripts.convert_md_to_html import convert_markdown_table_to_html_file

def update_all_todos(status):
    """
    Updates all todos in the list to the given status.
    """
    md_file = os.path.join("reports", "todo_list.md")
    html_file = os.path.join("reports", "todo_list.html")

    with open(md_file, "r") as f:
        lines = f.readlines()

    with open(md_file, "w") as f:
        for line in lines:
            if re.match(r"- \[[ x]\] \*\*", line):
                line = re.sub(r"\[[ x]\]", "[x]", line)
                line = re.sub(r": .*", f": {status}", line)
                f.write(line)
            else:
                f.write(line)

    convert_markdown_table_to_html_file(md_file, html_file)

def update_todo_list(plugin_name, status):
    """
    Updates the todo list in both Markdown and HTML formats.
    """
    md_file = os.path.join("reports", "todo_list.md")
    html_file = os.path.join("reports", "todo_list.html")

    # Read the Markdown file and update the status
    with open(md_file, "r") as f:
        lines = f.readlines()

    with open(md_file, "w") as f:
        for line in lines:
            if line.startswith(f"- [ ] **{plugin_name}**"):
                f.write(f"- [x] **{plugin_name}**: {status}\n")
            elif line.startswith(f"- [x] **{plugin_name}**"):
                f.write(f"- [x] **{plugin_name}**: {status}\n")
            else:
                f.write(line)

    # Convert the updated Markdown to HTML
    convert_markdown_table_to_html_file(md_file, html_file)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Update the todo list.")
    parser.add_argument("--all", action="store_true", help="Update all plugins.")
    parser.add_argument("status", help="The new status of the plugin.")
    parser.add_argument("plugin_name", nargs="?", default=None, help="The name of the plugin.")
    args = parser.parse_args()

    if args.all:
        update_all_todos(args.status)
    elif args.plugin_name:
        update_todo_list(args.plugin_name, args.status)
    else:
        print("Please provide a plugin name or use the --all flag.")
