
"""
remote_transfer.py

Provides the RemoteTransfer class for SSH connections, SCP file transfers, and remote command execution.

Usage:
    from remote_transfer import RemoteTransfer
    rt = RemoteTransfer(server_ip, ssh_key_path, username)
    rt.connect()
    rt.copy_directory(local_dir, remote_dir)
    out, err = rt.run_command('ls -l')
    rt.close()
"""
import paramiko
from scp import SCPClient

class RemoteTransfer:
    """
    Handles SSH connections, SCP file transfers, and remote command execution for plugin deployment.
    """
    def __init__(self, server_ip, ssh_key_path, username='ubuntu'):
        """
        Initialize RemoteTransfer.
        :param server_ip: IP address of the remote server
        :param ssh_key_path: Path to the SSH private key
        :param username: SSH username (default: ubuntu)
        """
        self.server_ip = server_ip
        self.ssh_key_path = ssh_key_path
        self.username = username
        self.client = None

    def connect(self):
        """
        Establish an SSH connection to the remote server.
        """
        self.client = paramiko.SSHClient()
        self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.client.connect(self.server_ip, username=self.username, key_filename=self.ssh_key_path)

    def copy_directory(self, local_dir, remote_dir):
        """
        Copy a local directory to the remote server using SCP.
        :param local_dir: Path to the local directory
        :param remote_dir: Path to the destination directory on the server
        """
        with SCPClient(self.client.get_transport()) as scp:
            scp.put(local_dir, remote_dir, recursive=True)

    def run_command(self, command):
        """
        Run a shell command on the remote server.
        :param command: Command string to execute
        :return: Tuple of (stdout, stderr)
        """
        stdin, stdout, stderr = self.client.exec_command(command)
        return stdout.read().decode(), stderr.read().decode()

    def close(self):
        """
        Close the SSH connection if open.
        """
        if self.client:
            self.client.close()
