import unittest
import os
import tempfile
import shutil
import time
from unittest.mock import MagicMock, patch

# Assuming the project root is in sys.path when tests are run by run_tests.py
from scripts.place_plugins import PluginPlacer
from scripts.remote_transfer import RemoteTransfer
from scripts.validation_runner import PongoValidator
from scripts.change_tracker import ChangeTracker

class TestPluginPlacer(unittest.TestCase):

    def setUp(self):
        self.mock_ssh_client = MagicMock()
        self.mock_tracker = MagicMock(spec=ChangeTracker)
        self.remote_plugin_path = "/usr/local/kong/plugins"
        
        # Create a temporary local directory for plugin files
        self.local_temp_dir = tempfile.mkdtemp()
        self.local_plugin_dir = os.path.join(self.local_temp_dir, "my-plugin")
        os.makedirs(self.local_plugin_dir)
        self.handler_file = os.path.join(self.local_plugin_dir, "handler.lua")
        with open(self.handler_file, "w") as f:
            f.write("local _ = require 'kong.singletons'\nreturn { version = '1.0.0' }")
        
        # Mock PongoValidator to control its output
        self.mock_validator = MagicMock(spec=PongoValidator)
        self.mock_validator.validate.return_value = ("Pongo validation successful.\n0 failed, 0 errors\n", "")
        
        # Patch the PongoValidator constructor within PluginPlacer
        patcher = patch('scripts.place_plugins.PongoValidator', return_value=self.mock_validator)
        self.mock_pongo_validator_constructor = patcher.start()
        self.addCleanup(patcher.stop)
        
        # Mock RemoteTransfer.copy_directory
        patcher = patch('scripts.place_plugins.RemoteTransfer')
        self.mock_remote_transfer_constructor = patcher.start()
        self.addCleanup(patcher.stop)
        # Ensure that the instance returned by the constructor also has a mock for copy_directory
        self.mock_remote_transfer_instance = MagicMock()
        self.mock_remote_transfer_constructor.return_value = self.mock_remote_transfer_instance

    def tearDown(self):
        shutil.rmtree(self.local_temp_dir)

    def _create_remote_mock_sftp_stat_result(self, mtime):
        """Helper to create a mock stat result for SFTP."""
        stat_result = MagicMock()
        stat_result.st_mtime = mtime
        stat_result.st_mode = 16877 # octal for directory (drwxr-xr-x)
        return stat_result
    
    def _create_remote_mock_sftp_attr_file(self, filename, mtime):
        attr = MagicMock()
        attr.filename = filename
        attr.st_mtime = mtime
        attr.st_mode = 33188 # octal for regular file (-rw-r--r--)
        return attr

    # --- Test plugin_needs_update method ---

    def test_plugin_needs_update_local_mode(self):
        placer = PluginPlacer(self.mock_ssh_client, self.remote_plugin_path, self.mock_tracker, local_mode=True)
        self.assertTrue(placer.plugin_needs_update(self.local_plugin_dir, "ignored/remote/path"))

    @patch('os.path.getmtime')
    @patch('os.walk')
    def test_plugin_needs_update_remote_local_newer(self, mock_os_walk, mock_getmtime):
        """Test remote mode when local plugin is newer."""
        # Setup local mtime to be newer
        mock_getmtime.return_value = time.time() + 100 # Local is newer
        mock_os_walk.return_value = [
            (self.local_plugin_dir, [], ["handler.lua"])
        ]
        
        # Mock remote SFTP
        mock_sftp = MagicMock()
        self.mock_ssh_client.open_sftp.return_value = mock_sftp
        mock_sftp.stat.return_value = self._create_remote_mock_sftp_stat_result(time.time()) # Remote is older
        mock_sftp.listdir_attr.return_value = [
            self._create_remote_mock_sftp_attr_file("handler.lua", time.time())
        ]
        
        placer = PluginPlacer(self.mock_ssh_client, self.remote_plugin_path, self.mock_tracker)
        self.assertTrue(placer.plugin_needs_update(self.local_plugin_dir, os.path.join(self.remote_plugin_path, "my-plugin")))
        mock_sftp.close.assert_called_once()

    @patch('os.path.getmtime')
    @patch('os.walk')
    def test_plugin_needs_update_remote_remote_newer(self, mock_os_walk, mock_getmtime):
        """Test remote mode when remote plugin is newer or same age."""
        # Setup local mtime to be older or same
        mock_getmtime.return_value = time.time() - 100 
        mock_os_walk.return_value = [
            (self.local_plugin_dir, [], ["handler.lua"])
        ]
        
        # Mock remote SFTP
        mock_sftp = MagicMock()
        self.mock_ssh_client.open_sftp.return_value = mock_sftp
        mock_sftp.stat.return_value = self._create_remote_mock_sftp_stat_result(time.time()) # Remote is newer
        mock_sftp.listdir_attr.return_value = [
            self._create_remote_mock_sftp_attr_file("handler.lua", time.time())
        ]

        placer = PluginPlacer(self.mock_ssh_client, self.remote_plugin_path, self.mock_tracker)
        self.assertFalse(placer.plugin_needs_update(self.local_plugin_dir, os.path.join(self.remote_plugin_path, "my-plugin")))
        mock_sftp.close.assert_called_once()

    @patch('os.path.getmtime')
    @patch('os.walk')
    def test_plugin_needs_update_remote_remote_does_not_exist(self, mock_os_walk, mock_getmtime):
        """Test remote mode when remote plugin directory does not exist."""
        mock_getmtime.return_value = time.time()
        mock_os_walk.return_value = [
            (self.local_plugin_dir, [], ["handler.lua"])
        ]
        
        mock_sftp = MagicMock()
        self.mock_ssh_client.open_sftp.return_value = mock_sftp
        # Simulate IOError for stat and listdir_attr if remote dir doesn't exist
        mock_sftp.stat.side_effect = IOError
        mock_sftp.listdir_attr.side_effect = IOError 

        placer = PluginPlacer(self.mock_ssh_client, self.remote_plugin_path, self.mock_tracker)
        self.assertTrue(placer.plugin_needs_update(self.local_plugin_dir, os.path.join(self.remote_plugin_path, "non-existent-plugin")))
        mock_sftp.close.assert_called_once()

    # --- Test place_or_update method ---

    def test_place_or_update_local_mode(self):
        """Test place_or_update in local mode."""
        placer = PluginPlacer(self.mock_ssh_client, self.remote_plugin_path, self.mock_tracker, local_mode=True)
        
        with patch('builtins.print') as mock_print:
            placer.place_or_update(self.local_plugin_dir)
            
            self.mock_tracker.update.assert_called_once_with("my-plugin", self.local_plugin_dir)
            self.mock_ssh_client.exec_command.assert_not_called() # No SSH commands in local mode
            self.mock_validator.validate.assert_called_once()
            mock_print.assert_any_call("[INFO] Placed/updated plugin: my-plugin")
            mock_print.assert_any_call("Pongo validation successful.\n0 failed, 0 errors\n")


    @patch('scripts.place_plugins.PluginPlacer.plugin_needs_update', return_value=True)
    def test_place_or_update_remote_update_needed(self, mock_needs_update):
        """Test place_or_update in remote mode when update is needed."""
        placer = PluginPlacer(self.mock_ssh_client, self.remote_plugin_path, self.mock_tracker)
        
        with patch('builtins.print') as mock_print:
            placer.place_or_update(self.local_plugin_dir)
            
            # Verify SSH commands
            self.mock_ssh_client.exec_command.assert_any_call(f"sudo rm -rf {os.path.join(self.remote_plugin_path, 'my-plugin')}")
            self.mock_remote_transfer_constructor.assert_called_once_with(None, None) # RemoteTransfer init
            self.mock_remote_transfer_instance.client = self.mock_ssh_client # client is assigned
            self.mock_remote_transfer_instance.copy_directory.assert_called_once_with(self.local_plugin_dir, self.remote_plugin_path)
            self.mock_ssh_client.exec_command.assert_any_call(f"sudo chown -R kong:kong {os.path.join(self.remote_plugin_path, 'my-plugin')}")
            
            self.mock_tracker.update.assert_called_once_with("my-plugin", self.local_plugin_dir)
            self.mock_validator.validate.assert_called_once()
            mock_print.assert_any_call("[INFO] Placed/updated plugin: my-plugin")

    @patch('scripts.place_plugins.PluginPlacer.plugin_needs_update', return_value=False)
    def test_place_or_update_remote_no_update_needed(self, mock_needs_update):
        """Test place_or_update in remote mode when no update is needed."""
        placer = PluginPlacer(self.mock_ssh_client, self.remote_plugin_path, self.mock_tracker)
        
        with patch('builtins.print') as mock_print:
            placer.place_or_update(self.local_plugin_dir)
            
            self.mock_ssh_client.exec_command.assert_not_called() # No rm or chown
            self.mock_remote_transfer_instance.copy_directory.assert_not_called() # No copy
            
            self.mock_tracker.update.assert_not_called() # No update to tracker
            self.mock_validator.validate.assert_called_once() # Validator should still run
            mock_print.assert_any_call("[SKIP] my-plugin: No changes since last sync.")

    @patch('scripts.place_plugins.PluginPlacer.plugin_needs_update', return_value=True)
    def test_place_or_update_remote_rm_error(self, mock_needs_update):
        """Test error during remote rm command."""
        self.mock_ssh_client.exec_command.side_effect = [
            (None, MagicMock(read=lambda: b""), MagicMock(read=lambda: b"Permission denied")), # rm error
            (None, MagicMock(read=lambda: b""""""'), MagicMock(read=lambda: b""""""')) # chown (not reached)
        ]
        placer = PluginPlacer(self.mock_ssh_client, self.remote_plugin_path, self.mock_tracker)
        
        with patch('builtins.print') as mock_print:
            with self.assertRaises(Exception): # Expecting an exception to be raised
                placer.place_or_update(self.local_plugin_dir)
            
            mock_print.assert_any_call("[INFO] Placed/updated plugin: my-plugin")
            # The exact error message printed by the exec_command might vary,
            # but we expect an exception to be raised due to the exec_command error handling within the placer.
            # We are primarily testing that an error propagates or is handled.

    @patch('scripts.place_plugins.PluginPlacer.plugin_needs_update', return_value=True)
    def test_place_or_update_remote_chown_error(self, mock_needs_update):
        """Test error during remote chown command."""
        self.mock_ssh_client.exec_command.side_effect = [
            (None, MagicMock(read=lambda: b""""""'), MagicMock(read=lambda: b""""""')), # rm success
            (None, MagicMock(read=lambda: b""""""'), MagicMock(read=lambda: b"chown error")) # chown error
        ]
        placer = PluginPlacer(self.mock_ssh_client, self.remote_plugin_path, self.mock_tracker)
        
        with patch('builtins.print') as mock_print:
            with self.assertRaises(Exception): # Expecting an exception to be raised
                placer.place_or_update(self.local_plugin_dir)
            mock_print.assert_any_call("[INFO] Placed/updated plugin: my-plugin")
