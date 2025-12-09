import unittest
from unittest.mock import MagicMock
from scripts.validation_runner import PongoValidator
from scripts.pongo_validation import PongoValidationSummary
import os

class MockSSHClient:
    def __init__(self, stdout_data="", stderr_data=""):
        self._stdout_data = stdout_data.encode('utf-8')
        self._stderr_data = stderr_data.encode('utf-8')

    def exec_command(self, command):
        mock_stdin = MagicMock()
        mock_stdout = MagicMock()
        mock_stderr = MagicMock()

        mock_stdout.read.return_value = self._stdout_data
        mock_stderr.read.return_value = self._stderr_data

        return mock_stdin, mock_stdout, mock_stderr

class TestPongoValidator(unittest.TestCase):
    def test_validate_success(self):
        mock_client = MockSSHClient(stdout_data="Pongo validation successful.\n0 failed, 0 errors\n")
        validator = PongoValidator(mock_client)
        stdout, stderr = validator.validate(os.path.join('tmp', 'plugin'))
        self.assertIn("0 failed", stdout)
        self.assertEqual("", stderr)

    def test_validate_failure(self):
        mock_client = MockSSHClient(stdout_data="Pongo validation failed.\n1 failed, 0 errors\n", stderr_data="Error details")
        validator = PongoValidator(mock_client)
        stdout, stderr = validator.validate(os.path.join('tmp', 'plugin'))
        self.assertIn("1 failed", stdout)
        self.assertIn("Error details", stderr)

    def test_validate_local_mode_success(self):
        mock_client = MockSSHClient() # Not used in local mode, but required by constructor
        validator = PongoValidator(mock_client, local_mode=True)
        stdout, stderr = validator.validate(os.path.join('tmp', 'plugin'))
        self.assertIn("0 failed", stdout)
        self.assertEqual("", stderr)

class TestPongoValidationSummary(unittest.TestCase):
    def test_summarize_single_plugin_pass(self):
        mock_client = MockSSHClient(stdout_data="Pongo validation successful.\n0 failed, 0 errors\n")
        summary = PongoValidationSummary(mock_client, os.path.join('remote', 'plugin', 'path'))
        results = summary.validate_and_summarize(["test-plugin"])
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0][0], "test-plugin")
        self.assertEqual(results[0][1], "PASS")
        self.assertIn("0 failed", results[0][2])

    def test_summarize_single_plugin_fail(self):
        mock_client = MockSSHClient(stdout_data="Pongo validation failed.\n1 failed, 0 errors\n", stderr_data="Error details for failure.")
        summary = PongoValidationSummary(mock_client, os.path.join('remote', 'plugin', 'path'))
        results = summary.validate_and_summarize(["test-plugin-fail"])
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0][0], "test-plugin-fail")
        self.assertEqual(results[0][1], "FAIL")
        self.assertIn("Error details for failure.", results[0][2])

    def test_summarize_multiple_plugins(self):
        # This mock client will be used for all plugins
        # In a real scenario, you might want more granular control for each plugin
        mock_client = MockSSHClient(stdout_data="Pongo validation successful.\n0 failed, 0 errors\n")
        summary = PongoValidationSummary(mock_client, os.path.join('remote', 'plugin', 'path'))
        
        # Override exec_command for specific scenarios if needed
        def custom_exec_command(command):
            if "test-plugin-fail" in command:
                return MagicMock(), MagicMock(read=lambda: b"1 failed, 0 errors"), MagicMock(read=lambda: b"Specific failure")
            return MagicMock(), MagicMock(read=lambda: b"0 failed, 0 errors"), MagicMock(read=lambda: b"")
        
        mock_client.exec_command = custom_exec_command

        results = summary.validate_and_summarize(["test-plugin-pass", "test-plugin-fail"])
        self.assertEqual(len(results), 2)
        
        self.assertEqual(results[0][0], "test-plugin-pass")
        self.assertEqual(results[0][1], "PASS")
        self.assertIn("0 failed", results[0][2])

        self.assertEqual(results[1][0], "test-plugin-fail")
        self.assertEqual(results[1][1], "FAIL")
        self.assertIn("Specific failure", results[1][2])

    def test_summarize_local_mode(self):
        mock_client = MockSSHClient() # Not used in local mode, but required by constructor
        summary = PongoValidationSummary(mock_client, os.path.join('remote', 'plugin', 'path'), local_mode=True)
        results = summary.validate_and_summarize(["test-plugin-local"])
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0][0], "test-plugin-local")
        self.assertEqual(results[0][1], "PASS")
        self.assertIn("0 failed", results[0][2])

if __name__ == '__main__':
    unittest.main()
