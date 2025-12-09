
import markdown
import os

def convert_markdown_table_to_html_file(md_file_path, html_file_path):
    """
    Reads a Markdown file, converts its table content to an HTML table,
    and writes it to a new HTML file.
    """
    try:
        with open(md_file_path, 'r', encoding='utf-8') as f:
            md_content = f.read()
    except FileNotFoundError:
        print(f"Error: Markdown file '{md_file_path}' not found.")
        return

    # Basic conversion from Markdown to HTML.
    # Markdown tables are usually parsed correctly by markdown library.
    # We will wrap it in a basic HTML structure.
    html_body = markdown.markdown(md_content, extensions=['tables'])

    # Add some basic HTML boilerplate for a complete document
    html_template = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pongo Validation Solutions - Action Plan</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
        tr:nth-child(even) {{ background-color: #f9f9f9; }}
        tr:hover {{ background-color: #f1f1f1; }}
        h1, h2, h3 {{ color: #333; }}
        pre {{ background-color: #eee; padding: 10px; border-radius: 5px; overflow-x: auto; }}
        code {{ font-family: monospace; }}
    </style>
</head>
<body>
    {html_body}
</body>
</html>
"""

    try:
        with open(html_file_path, 'w', encoding='utf-8') as f:
            f.write(html_template)
        print(f"Successfully converted '{md_file_path}' to '{html_file_path}'.")
    except IOError as e:
        print(f"Error writing HTML file '{html_file_path}': {e}")

if __name__ == "__main__":
    md_file = os.path.join("reports", "todo_list.md")
    html_file = os.path.join("reports", "todo_list.html")
    
    convert_markdown_table_to_html_file(md_file, html_file)
