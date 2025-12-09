"""
validation_runner.py

Provides the PongoValidator class for running Pongo validation on remote plugins.

Usage:
    from validation_runner import PongoValidator
    validator = PongoValidator(ssh_client)
    output, error = validator.validate('/path/to/plugin')
"""

class PongoValidator:
    """
    Runs Pongo validation for a given plugin directory on the remote server.
    """
    def __init__(self, ssh_client, local_mode=False):
        """
        Initialize PongoValidator.
        :param ssh_client: Paramiko SSH client
        :param local_mode: Boolean, if True, run in local mode (no actual SSH)
        """
        self.ssh_client = ssh_client
        self.local_mode = local_mode

    def validate(self, plugin_dir):
        """
        Run 'pongo validate' in the specified plugin directory on the remote server.
        :param plugin_dir: Path to the remote plugin directory
        :return: Tuple of (stdout, stderr)
        """
        if self.local_mode:
            # Return mock output for local mode
            return "Pongo validation successful.\n0 failed, 0 errors\n", ""
        cmd = f"pongo validate {plugin_dir}"
        stdin, stdout, stderr = self.ssh_client.exec_command(cmd)
        return stdout.read().decode(), stderr.read().decode()
