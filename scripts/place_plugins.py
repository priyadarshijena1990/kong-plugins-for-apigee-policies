
import os
from .remote_transfer import RemoteTransfer
from .validation_runner import PongoValidator
from .change_tracker import ChangeTracker

class PluginPlacer:
    """
    Handles placement and update of custom Lua plugin directories on the remote server.
    Ensures correct ownership, change tracking, and validation.
    """
    def __init__(self, ssh_client, remote_plugin_path, tracker, local_mode=False):
        """
        Initialize PluginPlacer.
        :param ssh_client: Paramiko SSH client
        :param remote_plugin_path: Path to the remote Kong plugin directory
        :param tracker: ChangeTracker instance
        """
        self.ssh_client = ssh_client
        self.remote_plugin_path = remote_plugin_path
        self.tracker = tracker
        self.local_mode = local_mode
        self.validator = PongoValidator(ssh_client, local_mode=local_mode)

    def plugin_needs_update(self, local_plugin_dir, remote_plugin_dir):
        """
        Check if the local plugin is newer than the remote plugin by comparing mtimes.
        :param local_plugin_dir: Path to the local plugin directory
        :param remote_plugin_dir: Path to the remote plugin directory
        :return: True if update is needed, False otherwise
        """
        if self.local_mode:
            return True # In local mode, always simulate an update
        local_mtime = max(os.path.getmtime(os.path.join(root, f))
                          for root, _, files in os.walk(local_plugin_dir) for f in files)
        
        remote_mtime = 0
        try:
            sftp = self.ssh_client.open_sftp()
            
            # Helper to recursively find the max modification time
            def get_remote_max_mtime(path):
                import stat
                import posixpath
                max_mtime = 0
                try:
                    # Also check the directory's own mtime
                    max_mtime = max(max_mtime, sftp.stat(path).st_mtime)
                    for attr in sftp.listdir_attr(path):
                        remote_filepath = posixpath.join(path, attr.filename)
                        if stat.S_ISDIR(attr.st_mode):
                            max_mtime = max(max_mtime, get_remote_max_mtime(remote_filepath))
                        else:
                            max_mtime = max(max_mtime, attr.st_mtime)
                except IOError: # Catch if a directory is not readable or doesn't exist
                    return 0
                return max_mtime

            remote_mtime = get_remote_max_mtime(remote_plugin_dir)
            sftp.close()
        except IOError:
            remote_mtime = 0 # SFTP client failed to open or top-level directory access failed

        return local_mtime > remote_mtime

    def place_or_update(self, local_plugin_dir):
        """
        Place or update a plugin directory on the remote server, set ownership, and track changes.
        Also prints directory info and validation output.
        :param local_plugin_dir: Path to the local plugin directory
        """
        import posixpath
        plugin_name = os.path.basename(local_plugin_dir)
        remote_plugin_dir = posixpath.join(self.remote_plugin_path, plugin_name)
        if self.plugin_needs_update(local_plugin_dir, remote_plugin_dir):
            if not self.local_mode:
                self.ssh_client.exec_command(f"sudo rm -rf {remote_plugin_dir}")
                rt = RemoteTransfer(None, None)  # Not used for connection, just for copy
                rt.client = self.ssh_client
                rt.copy_directory(local_plugin_dir, self.remote_plugin_path)
                self.ssh_client.exec_command(f"sudo chown -R kong:kong {remote_plugin_dir}")
            self.tracker.update(plugin_name, local_plugin_dir)
            print(f"[INFO] Placed/updated plugin: {plugin_name}")
        else:
            print(f"[SKIP] {plugin_name}: No changes since last sync.")
        
        if not self.local_mode:
            try:
                sftp = self.ssh_client.open_sftp()

                def print_remote_dir_info(path):
                    try:
                        import stat
                        import datetime
                        attr = sftp.stat(path)
                        mode = attr.st_mode
                        perms = stat.filemode(mode)
                        uid = attr.st_uid
                        gid = attr.st_gid
                        size = attr.st_size
                        mtime = datetime.datetime.fromtimestamp(attr.st_mtime).strftime('%b %d %H:%M')
                        print(f"[INFO] Directory info for {path}:")
                        print(f"  {perms} 1 {uid} {gid} {size} {mtime} {posixpath.basename(path)}")
                    except IOError as e:
                        print(f"[ERROR] Could not stat remote directory {path}: {e}")

                def print_remote_dir_tree(path, indent_level=0):
                    try:
                        import stat
                        for attr in sftp.listdir_attr(path):
                            mode = attr.st_mode
                            is_dir = stat.S_ISDIR(mode)
                            print("  " * indent_level + f"  - {attr.filename}{'/' if is_dir else ''}")
                            if is_dir:
                                print_remote_dir_tree(posixpath.join(path, attr.filename), indent_level + 1)
                    except IOError as e:
                        print(f"[ERROR] Could not list remote directory {path}: {e}")

                print_remote_dir_info(remote_plugin_dir)
                print(f"[INFO] Directory and file structure for {remote_plugin_dir}:")
                print_remote_dir_tree(remote_plugin_dir)

                sftp.close()
            except Exception as e:
                print(f"[ERROR] Failed to get remote directory info: {e}")
        
        val_out, val_err = self.validator.validate(remote_plugin_dir)
        print(f"[PONGO OUTPUT] {plugin_name}:\n{val_out}")
        if val_err:
            print(f"[PONGO ERROR] {plugin_name}:\n{val_err}")
