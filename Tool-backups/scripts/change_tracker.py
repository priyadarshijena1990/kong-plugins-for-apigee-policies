import os
import json
import time

class ChangeTracker:
    """
    Tracks plugin deployment changes, timestamps, and previous/current state in a local JSON file.
    """
    def __init__(self, tracker_path):
        """
        Initialize ChangeTracker.
        :param tracker_path: Path to the tracker JSON file
        """
        self.tracker_path = os.path.abspath(tracker_path)

    def update(self, plugin_name, local_plugin_dir):
        """
        Update the tracker file with the plugin's previous and current state and timestamp.
        :param plugin_name: Name of the plugin
        :param local_plugin_dir: Path to the local plugin directory
        """
        prev_state = None
        if os.path.exists(self.tracker_path):
            with open(self.tracker_path, 'r') as f:
                try:
                    tracker = json.load(f)
                except Exception:
                    tracker = {}
            prev_state = tracker.get(plugin_name)
        else:
            tracker = {}
        
        # Get plugin version from rockspec
        version = "unknown"
        for file in os.listdir(local_plugin_dir):
            if file.endswith(".rockspec"):
                with open(os.path.join(local_plugin_dir, file), 'r') as f:
                    for line in f:
                        if "version = " in line:
                            version = line.split('"')[1]
                            break
                break

        # Get git commit hash
        commit_hash = "unknown"
        try:
            import subprocess
            commit_hash = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).strip().decode('utf-8')
        except (subprocess.CalledProcessError, FileNotFoundError):
            commit_hash = "not a git repository"

        curr_state = {
            'timestamp': int(time.time()),
            'version': version,
            'commit': commit_hash,
            'files': os.listdir(local_plugin_dir)
        }
        tracker[plugin_name] = {
            'previous_state': prev_state,
            'current_state': curr_state,
            'summary': f"Updated plugin {plugin_name} (v{version}, commit {commit_hash}) at {curr_state['timestamp']}"
        }
        with open(self.tracker_path, 'w') as f:
            json.dump(tracker, f, indent=2)
