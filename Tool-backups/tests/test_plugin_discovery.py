import unittest
import os
import tempfile
import shutil
from unittest.mock import patch, MagicMock

# Assuming the project root is in sys.path when tests are run by run_tests.py
from scripts.plugin_discovery import get_plugin_dirs

class TestPluginDiscovery(unittest.TestCase):

    def setUp(self):
        # Create a temporary directory for testing plugin discovery
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        # Clean up the temporary directory after tests
        shutil.rmtree(self.test_dir)

    def _create_mock_plugin_dir(self, parent_dir, plugin_name, files_to_create=None):
        """Helper to create a mock plugin directory structure."""
        plugin_path = os.path.join(parent_dir, plugin_name)
        os.makedirs(plugin_path, exist_ok=True)
        if files_to_create:
            for f in files_to_create:
                with open(os.path.join(plugin_path, f), 'w') as temp_file:
                    temp_file.write("mock content")
        return plugin_path

    def test_discover_plugins_normal_case(self):
        """Test discovery with multiple valid plugins."""
        self._create_mock_plugin_dir(self.test_dir, "plugin_a", ["handler.lua"])
        self._create_mock_plugin_dir(self.test_dir, "plugin_b", ["schema.lua"])
        self._create_mock_plugin_dir(self.test_dir, "plugin_c", ["handler.lua", "schema.lua"])

        plugins = get_plugin_dirs(self.test_dir)
        self.assertIn("plugin_a", plugins)
        self.assertIn("plugin_b", plugins)
        self.assertIn("plugin_c", plugins)
        self.assertEqual(len(plugins), 3)

    def test_discover_plugins_empty_directory(self):
        """Test discovery in an empty directory."""
        plugins = get_plugin_dirs(self.test_dir)
        self.assertEqual(len(plugins), 0)

    def test_discover_plugins_no_lua_files(self):
        """Test discovery in directories without handler.lua or schema.lua."""
        self._create_mock_plugin_dir(self.test_dir, "not_a_plugin", ["some_file.txt"])
        self._create_mock_plugin_dir(self.test_dir, "another_dir", ["config.json"])

        plugins = get_plugin_dirs(self.test_dir)
        self.assertEqual(len(plugins), 0)

    def test_discover_plugins_mixed_content(self):
        """Test discovery with a mix of valid and invalid plugin directories."""
        self._create_mock_plugin_dir(self.test_dir, "valid_plugin_1", ["handler.lua"])
        self._create_mock_plugin_dir(self.test_dir, "invalid_plugin_1", ["README.md"])
        self._create_mock_plugin_dir(self.test_dir, "valid_plugin_2", ["schema.lua"])
        
        plugins = get_plugin_dirs(self.test_dir)
        self.assertIn("valid_plugin_1", plugins)
        self.assertIn("valid_plugin_2", plugins)
        self.assertEqual(len(plugins), 2)

    def test_discover_plugins_nested_directories_ignored(self):
        """Test that nested directories are not treated as top-level plugins."""
        plugin_path = self._create_mock_plugin_dir(self.test_dir, "top_level_plugin", ["handler.lua"])
        self._create_mock_plugin_dir(plugin_path, "nested_dir", ["schema.lua"]) # This should not be found

        plugins = get_plugin_dirs(self.test_dir)
        self.assertIn("top_level_plugin", plugins)
        self.assertNotIn("nested_dir", plugins)
        self.assertEqual(len(plugins), 1)

    @patch('os.listdir')
    @patch('os.path.isdir')
    def test_os_calls_mocked(self, mock_isdir, mock_listdir):
        """Test that os.listdir and os.path.isdir are called correctly."""
        # Setup mock behavior
        def listdir_side_effect(path):
            if path == "/mock/path":
                return ["plugin_a", "file.txt"]
            elif path == os.path.join("/mock/path", "plugin_a"):
                return ["handler.lua"]
            return []

        mock_listdir.side_effect = listdir_side_effect
        mock_isdir.side_effect = lambda x: x == os.path.join("/mock/path", "plugin_a")

        plugins = get_plugin_dirs("/mock/path")

        self.assertIn("plugin_a", plugins)
        self.assertEqual(len(plugins), 1)
        mock_listdir.assert_any_call("/mock/path")
        mock_listdir.assert_any_call(os.path.join("/mock/path", "plugin_a"))
        mock_isdir.assert_any_call(os.path.join("/mock/path", "plugin_a"))
