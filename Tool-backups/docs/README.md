# Kong Plugin Deployment & Validation Tool

## Overview
This tool automates the deployment, validation, and change tracking of custom Kong Lua plugins on a remote server. It is designed for enterprise use, with modular, object-oriented Python code, robust logging, and extensibility.

## Features
- Secure SSH/SCP-based deployment to root-owned Kong plugin directories.
- Only updates plugins with local changes by comparing modification times.
- Ensures correct file ownership (`kong:kong`) on the remote server.
- Runs Pongo validation for each updated plugin.
- Summarizes validation results in a clear table in the console.
- Generates a detailed HTML report of the validation summary in the `reports` directory.
- Enterprise-grade logging to both a file (`deployment.log`) and the console.
- Modular, OOP architecture for maintainability and extensibility.
- Local mode for testing without a remote server.

## Quick Start
1.  **Clone the repository.**
2.  **Install dependencies:**
    ```sh
    pip install -r requirements.txt
    ```
3.  **Configure your deployment:**
    -   Edit `configs/config.json` with your plugin path, server IP, SSH key, username, and remote plugin path.
4.  **Run the tool:**
    ```sh
    python validate_plugins.py
    ```
5.  **Run in local mode (for testing):**
    ```sh
    python validate_plugins.py --local
    ```

## Configuration
Edit `configs/config.json`:
```json
{
  "plugin_path": "apigee-policies-based-plugins",
  "server_ip": "<your-server-ip>",
  "ssh_key_path": "ssh_keys/your-key.pem",
  "ssh_username": "ubuntu",
  "remote_plugin_path": "/usr/local/share/lua/5.1/kong/plugins/"
}
```

## Architecture
-   `validate_plugins.py`: The main orchestration script that coordinates the entire deployment and validation workflow.
-   `scripts/remote_transfer.py`: A class-based module that handles SSH connections and SCP file transfers.
-   `scripts/place_plugins.py`: A class-based module responsible for placing or updating plugins on the remote server.
-   `scripts/change_tracker.py`: A class that tracks changes to plugins to determine if they need to be updated.
-   `scripts/pongo_validation.py`: A class that runs Pongo validation and summarizes the results.
-   `scripts/plugin_discovery.py`: A module for discovering plugin directories.
-   `scripts/logging_manager.py`: Sets up and configures the logging for the tool.
-   `scripts/config_context.py`: Loads the `config.json` file for use by all modules.

## Logging
-   Logs are written to `deployment.log` in the project root directory (overwritten each run).
-   Console and file logs include timestamps and step information for clear tracking of the deployment process.

## Extending & Testing
-   New functionality can be added by creating new modules in the `scripts/` directory.
-   The tool uses Python's built-in `unittest` framework for testing. Tests are located in the `tests/` directory.

## Troubleshooting
-   Ensure your SSH key has the correct permissions and that your server is accessible.
-   Verify that Pongo is installed and available on the remote server.
-   Check `deployment.log` for detailed error messages and step-by-step information about the deployment process.

## License
MIT or as specified by your organization.
