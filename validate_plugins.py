from scripts.plugin_discovery import get_plugin_dirs
from scripts.place_plugins import PluginPlacer
from scripts.pongo_validation import PongoValidationSummary
from scripts.change_tracker import ChangeTracker
from scripts.remote_transfer import RemoteTransfer
"""
validate_plugins.py

Main orchestration script for enterprise-grade Kong plugin deployment and validation tool.
Uses modular scripts, robust logging, and OOP for maintainability and productization.
"""

import os
from scripts.logging_manager import get_logger
from scripts.config_context import CONFIG

class MockSSHClient:
    """
    A mock SSH client for local testing purposes.
    """
    def connect(self):
        pass

    def exec_command(self, command):
        mock_stdout = b"some output\n0 failed, 0 errors\n"
        mock_stderr = b""
        # For simplicity, returning BytesIO objects
        from io import BytesIO
        return None, BytesIO(mock_stdout), BytesIO(mock_stderr)

    def close(self):
        pass

# Enterprise orchestration class skeleton
class PluginDeploymentManager:
    """
    Coordinates the full plugin deployment and validation workflow.
    Handles connection, plugin placement, validation, and logging.
    """
    def __init__(self, local_mode=False):
        """
        Initialize PluginDeploymentManager.
        Loads config, sets up logging, and prepares dependencies.
        """
        self.logger = get_logger()
        self.config = CONFIG
        self.ssh_client = None
        self.local_mode = local_mode
        self.tracker = ChangeTracker('plugin_tracker.json')
        self.placer = None
        self.validation_summary = None

    def connect(self):
        """
        Establish SSH connection to the remote server and initialize placement/validation helpers.
        """
        if self.local_mode:
            self.logger.info("Running in local mode. Mocking SSH connection.")
            self.ssh_client = MockSSHClient()
            self.placer = PluginPlacer(self.ssh_client, self.config['remote_plugin_path'], self.tracker, local_mode=True)
            self.validation_summary = PongoValidationSummary(self.ssh_client, self.config['remote_plugin_path'], local_mode=True)
        else:
            self.logger.info(f"Connecting to remote server {self.config['server_ip']} as ubuntu...")
            try:
                self.ssh_client = RemoteTransfer(
                    self.config['server_ip'],
                    self.config['ssh_key_path'],
                    self.config.get('ssh_username', 'ubuntu')
                )
                self.ssh_client.connect()
                self.logger.info("Connected to remote server.")
                self.placer = PluginPlacer(self.ssh_client.client, self.config['remote_plugin_path'], self.tracker)
                self.validation_summary = PongoValidationSummary(self.ssh_client.client, self.config['remote_plugin_path'])
            except Exception as e:
                self.logger.error(f"Could not connect to server: {e}")
                raise

    def deploy_and_validate_plugins(self):
        """
        Discover plugins, place/update as needed, and run validation summary.
        """
        self.logger.info("Discovering plugins in local directory...")
        plugin_dirs = get_plugin_dirs(self.config['plugin_path'])
        updated_plugins = []
        for plugin in plugin_dirs:
            local_plugin_dir = os.path.join(self.config['plugin_path'], plugin)
            self.logger.info(f"Processing plugin: {plugin}")
            try:
                self.placer.place_or_update(local_plugin_dir)
                updated_plugins.append(plugin)
            except Exception as e:
                self.logger.error(f"{plugin}: {str(e)}")
        if updated_plugins:
            self.logger.info("Running Pongo validation summary for updated plugins...")
            self.validation_summary.validate_and_summarize(updated_plugins)
        else:
            self.logger.info("No plugins were updated. Nothing to validate.")

    def close(self):
        """
        Close SSH connection and clean up resources.
        """
        if self.ssh_client:
            self.ssh_client.close()
            self.logger.info("SSH connection closed.")
        self.logger.info("Closing resources ...")

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Kong Plugin Deployment and Validation Tool")
    parser.add_argument("--local", action="store_true", help="Run in local mode without SSH connection")
    args = parser.parse_args()

    manager = PluginDeploymentManager(local_mode=args.local)
    manager.logger.info("==== Kong Plugin Deployment Tool Started ====")
    try:
        manager.connect()
        manager.deploy_and_validate_plugins()
    except Exception as e:
        manager.logger.error(f"Fatal error: {e}")
    finally:
        manager.close()
        manager.logger.info("==== Kong Plugin Deployment Tool Finished ====")

if __name__ == '__main__':
    main()

