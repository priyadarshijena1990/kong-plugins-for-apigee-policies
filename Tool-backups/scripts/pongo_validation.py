"""
pongo_validation.py

Provides the PongoValidationSummary class for validating plugins and summarizing results in a table.

Usage:
    from pongo_validation import PongoValidationSummary
    summary = PongoValidationSummary(ssh_client, remote_plugin_path)
    summary.validate_and_summarize(plugin_dirs)
"""
from .validation_runner import PongoValidator
from tabulate import tabulate
import os

class PongoValidationSummary:
    """
    Validates plugins and summarizes results in a table using PongoValidator.
    """
    def __init__(self, ssh_client, remote_plugin_path, local_mode=False):
        """
        Initialize PongoValidationSummary.
        :param ssh_client: Paramiko SSH client
        :param remote_plugin_path: Path to the remote Kong plugin directory
        :param local_mode: Boolean, if True, run in local mode (no actual SSH)
        """
        self.validator = PongoValidator(ssh_client, local_mode=local_mode)
        self.remote_plugin_path = remote_plugin_path

    def validate_and_summarize(self, plugin_dirs):
        """
        Validate each plugin, print a summary table, and generate an HTML report.
        :param plugin_dirs: List of plugin directory names
        :return: List of [plugin_name, status, reason]
        """
        results = []
        for plugin_name in plugin_dirs:
            plugin_dir = os.path.join(self.remote_plugin_path, plugin_name)
            out, err = self.validator.validate(plugin_dir)
            status = 'PASS' if '0 failed' in out else 'FAIL'
            reason = err.strip() or out.strip().split('\n')[-1]
            results.append([plugin_name, status, reason])
        
        # Print summary table to console
        print(tabulate(results, headers=['Plugin', 'Status', 'Reason'], tablefmt='github'))
        
        # Generate HTML report
        html_table = tabulate(results, headers=['Plugin', 'Status', 'Reason'], tablefmt='html')
        html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pongo Validation Summary</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
        tr:nth-child(even) {{ background-color: #f9f9f9; }}
        tr:hover {{ background-color: #f1f1f1; }}
    </style>
</head>
<body>
    <h1>Pongo Validation Summary</h1>
    {html_table}
</body>
</html>
"""
        report_path = os.path.join('reports', 'pongo_validation_summary.html')
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        print(f"HTML report generated at {report_path}")

        return results
