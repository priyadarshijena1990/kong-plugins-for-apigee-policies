import argparse
import json
import os
import sys
import subprocess

def load_config(config_path):
    """
    Loads configuration from a JSON file.
    """
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Config file not found at: {config_path}")
    with open(config_path, 'r') as f:
        config = json.load(f)
    return config

def create_ssh_client(host, username, key_filepath):
    """
    Creates and returns an SSH client connected to the remote host.
    """
    import paramiko
    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        key_filepath = os.path.expanduser(key_filepath)
        if not os.path.exists(key_filepath):
            raise FileNotFoundError(f"SSH key file not found at: {key_filepath}")
            
        private_key = paramiko.RSAKey.from_private_key_file(key_filepath)
        client.connect(hostname=host, username=username, pkey=private_key, timeout=10)
        print(f"Successfully connected to {username}@{host}")
        return client
    except paramiko.AuthenticationException:
        print(f"Authentication failed for {username}@{host}. Check username and key file.", file=sys.stderr)
        raise
    except paramiko.SSHException as e:
        print(f"Could not establish SSH connection to {host}: {e}", file=sys.stderr)
        raise
    except Exception as e:
        print(f"An error occurred during SSH connection: {e}", file=sys.stderr)
        raise

def transfer_files_to_remote(ssh_client, local_path, remote_path):
    """
    Transfers files or directories from local_path to remote_path on the remote server.
    Creates the remote_path if it doesn't exist.
    """
    from scp import SCPClient
    with SCPClient(ssh_client.get_transport()) as scp:
        try:
            stdin, stdout, stderr = ssh_client.exec_command(f"mkdir -p {remote_path}")
            exit_status = stdout.channel.recv_exit_status()
            if exit_status != 0:
                print(f"Error creating remote directory {remote_path}: {stderr.read().decode()}", file=sys.stderr)
                raise Exception(f"Failed to create remote directory {remote_path}")
            
            print(f"Transferring {local_path} to {remote_path} on remote server...")
            if os.path.isdir(local_path):
                scp.put(local_path, recursive=True, remote_path=remote_path)
            else:
                scp.put(local_path, remote_path=remote_path)
            print(f"Successfully transferred {local_path} to {remote_path}.")
        except Exception as e:
            print(f"Error during file transfer: {e}", file=sys.stderr)
            raise

def execute_remote_command(ssh_client, command):
    """
    Executes a command on the remote server and prints stdout/stderr.
    Returns the exit status.
    """
    print(f"Executing remote command: {command}")
    stdin, stdout, stderr = ssh_client.exec_command(command)
    stdout_output = stdout.read().decode().strip()
    stderr_output = stderr.read().decode().strip()
    exit_status = stdout.channel.recv_exit_status()

    if stdout_output:
        print(f"Remote STDOUT:\n{stdout_output}")
    if stderr_output:
        print(f"Remote STDERR:\n{stderr_output}", file=sys.stderr)
    
    return exit_status, stdout_output, stderr_output

def retrieve_file_from_remote(ssh_client, remote_path, local_path):
    """
    Retrieves a file from remote_path on the remote server to local_path.
    """
    from scp import SCPClient
    with SCPClient(ssh_client.get_transport()) as scp:
        try:
            print(f"Retrieving {remote_path} from remote server to {local_path}...")
            scp.get(remote_path, local_path)
            print(f"Successfully retrieved {remote_path} to {local_path}.")
        except Exception as e:
            print(f"Error during file retrieval: {e}", file=sys.stderr)
            raise

def display_validation_summary(results):
    """
    Displays the validation summary in a formatted table.
    """
    from tabulate import tabulate
    print("\n--- Pongo Validation Summary ---")
    if not results:
        print("No validation results to display.")
        return

    headers = ["Plugin", "Status", "Reason"]
    table_data = []

    for plugin_name, data in results.items():
        table_data.append([
            plugin_name,
            data.get("status", "N/A"),
            data.get("reason", "").split('\n')[0] # Only take the first line of reason for brevity
        ])
    
    print(tabulate(table_data, headers=headers, tablefmt="grid"))
    print("--------------------------------")


def run_pongo_validation_on_remote(remote_final_plugin_path, kong_version):
    """
    Executes Pongo validation for all plugins in the remote_final_plugin_path.
    Returns a dictionary of results for each plugin.
    """
    print(f"[REMOTE] Starting Pongo validation for Kong version {kong_version}...")
    validation_results = {}
    
    plugins = [d for d in os.listdir(remote_final_plugin_path) if os.path.isdir(os.path.join(remote_final_plugin_path, d))]
    
    if not plugins:
        print("[REMOTE] No plugins found for validation.", file=sys.stderr)
        return validation_results

    for plugin_name in plugins:
        plugin_path = os.path.join(remote_final_plugin_path, plugin_name).replace("\\", "/")
        print(f"[REMOTE] Validating plugin: {plugin_name} at {plugin_path}")
        
        pongo_cmd = f"pongo validate --kong-version {kong_version} {plugin_path}"
        
        try:
            process = subprocess.run(
                pongo_cmd,
                shell=True,
                capture_output=True,
                text=True,
                check=False
            )
            
            status = "PASSED" if process.returncode == 0 else "FAILED"
            reason = ""
            if process.returncode != 0:
                reason = process.stderr if process.stderr else process.stdout
            
            validation_results[plugin_name] = {
                "status": status,
                "return_code": process.returncode,
                "stdout": process.stdout,
                "stderr": process.stderr,
                "reason": reason.strip()
            }
            print(f"[REMOTE] Plugin {plugin_name} validation: {status}")
            if status == "FAILED":
                print(f"[REMOTE] Reason: {reason.strip()}", file=sys.stderr)

        except Exception as e:
            print(f"[REMOTE] Error during validation of {plugin_name}: {e}", file=sys.stderr)
            validation_results[plugin_name] = {
                "status": "ERROR",
                "return_code": -1,
                "stdout": "",
                "stderr": str(e),
                "reason": str(e)
            }
    
    print("[REMOTE] Pongo validation complete.")
    return validation_results

def run_remote_setup_and_place_plugins(remote_temp_dir, remote_final_plugin_path, kong_version):
    print("[REMOTE] >>> EXECUTING run_remote_setup_and_place_plugins (v1.5) <<<", file=sys.stderr)
    """
    Logic to be run on the remote server:
    - Sets up environment (installs dependencies like Pongo, moves plugins).
    - Places plugins in the final Kong plugins directory.
    Assumes that the entire local project directory (including `requirements.txt` and `apigee-policies-based-plugins`) 
    is available under `remote_temp_dir` on the remote server, and the script itself is run from within `remote_temp_dir`.
    """
    print(f"[REMOTE] Starting remote setup for Kong version {kong_version}...")

    remote_requirements_path = os.path.join(remote_temp_dir, "requirements.txt").replace("\\", "/")
    remote_apigee_plugins_source = os.path.join(remote_temp_dir, "apigee-policies-based-plugins").replace("\\", "/")

    # --- Check for and install pip if it's missing ---
    check_pip_cmd = "python3 -m pip --version"
    pip_check_result = subprocess.run(check_pip_cmd, shell=True, capture_output=True, text=True, check=False)
    if pip_check_result.returncode != 0:
        print("[REMOTE] `pip` for python3 not found. Attempting to install it...", file=sys.stderr)
        # Try with yum (Amazon Linux 2) or dnf (Amazon Linux 2023)
        install_pip_cmd = "sudo yum install -y python3-pip || sudo dnf install -y python3-pip"
        install_pip_result = subprocess.run(install_pip_cmd, shell=True, capture_output=True, text=True, check=False)
        if install_pip_result.returncode != 0:
            print(f"[REMOTE] Error installing python3-pip. Command: {install_pip_cmd}", file=sys.stderr)
            print(f"[REMOTE] STDOUT: {install_pip_result.stdout}", file=sys.stderr)
            print(f"[REMOTE] STDERR: {install_pip_result.stderr}", file=sys.stderr)
            # As a fallback, try to use the ensurepip module
            print("[REMOTE] Trying fallback: `python3 -m ensurepip --upgrade`...", file=sys.stderr)
            ensurepip_cmd = "python3 -m ensurepip --upgrade"
            ensurepip_result = subprocess.run(ensurepip_cmd, shell=True, capture_output=True, text=True, check=False)
            if ensurepip_result.returncode != 0:
                print("[REMOTE] Fallback with ensurepip also failed. Cannot proceed.", file=sys.stderr)
                return False
        print("[REMOTE] `pip` installed successfully.")

    print(f"[REMOTE] Installing/Updating Python dependencies from {remote_requirements_path}...")
    install_cmd = f"python3 -m pip install -r {remote_requirements_path}"
    install_result = subprocess.run(install_cmd, shell=True, capture_output=True, text=True, check=False)
    if install_result.returncode != 0:
        print(f"[REMOTE] Error installing Python dependencies. Command: {install_cmd}", file=sys.stderr)
        print(f"[REMOTE] STDOUT: {install_result.stdout}", file=sys.stderr)
        print(f"[REMOTE] STDERR: {install_result.stderr}", file=sys.stderr)
        return False
    print("[REMOTE] Python dependencies installed successfully.")

    # --- Check for and install Pongo if it's missing ---
    check_pongo_cmd = "pongo --version"
    pongo_check_result = subprocess.run(check_pongo_cmd, shell=True, capture_output=True, text=True, check=False)
    if pongo_check_result.returncode != 0:
        print("[REMOTE] `pongo` not found. Attempting to install it...", file=sys.stderr)
        
        # Step 1: Install LuaRocks if not present
        check_luarocks_cmd = "luarocks --version"
        luarocks_check_result = subprocess.run(check_luarocks_cmd, shell=True, capture_output=True, text=True, check=False)
        if luarocks_check_result.returncode != 0:
            print("[REMOTE] `luarocks` not found. Attempting to install it from source...", file=sys.stderr)
            
            print("[REMOTE] Installing LuaRocks build dependencies...", file=sys.stderr)
            result = subprocess.run("sudo dnf install -y wget unzip lua-devel gcc make", shell=True, capture_output=True, text=True, check=False)
            if result.returncode != 0:
                print(f"[REMOTE] Error installing build dependencies. STDOUT: {result.stdout}, STDERR: {result.stderr}", file=sys.stderr)
                return False
            print("[REMOTE] Build dependencies installed.", file=sys.stderr)

            print("[REMOTE] Downloading LuaRocks...", file=sys.stderr)
            result = subprocess.run("wget https://luarocks.org/releases/luarocks-3.9.2.tar.gz -O /tmp/luarocks-3.9.2.tar.gz", shell=True, capture_output=True, text=True, check=False)
            if result.returncode != 0:
                print(f"[REMOTE] Error downloading LuaRocks. STDOUT: {result.stdout}, STDERR: {result.stderr}", file=sys.stderr)
                return False
            print("[REMOTE] LuaRocks downloaded.", file=sys.stderr)

            print("[REMOTE] Extracting LuaRocks...", file=sys.stderr)
            result = subprocess.run("tar zxpf /tmp/luarocks-3.9.2.tar.gz -C /tmp", shell=True, capture_output=True, text=True, check=False)
            if result.returncode != 0:
                print(f"[REMOTE] Error extracting LuaRocks. STDOUT: {result.stdout}, STDERR: {result.stderr}", file=sys.stderr)
                return False
            print("[REMOTE] LuaRocks extracted.", file=sys.stderr)

            print("[REMOTE] Configuring and building LuaRocks...", file=sys.stderr)
            # Use 'export PATH=$PATH:/usr/local/bin;' to make sure luarocks is found after install
            result = subprocess.run("cd /tmp/luarocks-3.9.2 && ./configure --with-lua-version=5.1 && make && sudo make install", shell=True, capture_output=True, text=True, check=False)
            if result.returncode != 0:
                print(f"[REMOTE] Error configuring/building LuaRocks. STDOUT: {result.stdout}, STDERR: {result.stderr}", file=sys.stderr)
                return False
            print("[REMOTE] LuaRocks configured and built.", file=sys.stderr)
            
            
            # ... Diagnostic commands ...

            # Check if luarocks is now in PATH and usable
            check_luarocks_path_cmd = "export PATH=$PATH:/usr/local/bin; which luarocks"
            if subprocess.run(check_luarocks_path_cmd, shell=True, capture_output=True).returncode != 0:
                print("[REMOTE] `luarocks` not found in expected path after installation. Exiting.", file=sys.stderr)
                return False

        # Step 2: Install Kong Pongo using LuaRocks
        print("[REMOTE] Installing `kong-pongo` via luarocks...", file=sys.stderr)
        
        
        # Step 2: Install Kong Pongo using LuaRocks
        print("[REMOTE] Installing `kong-pongo` via luarocks...", file=sys.stderr)
        
        # Always try with --lua-version=5.1 to be explicit
        # Use bash -c to ensure PATH and LUA_VERSION are set for the command
        pongo_install_cmds = [
            "bash -c \"export PATH=$PATH:/usr/local/bin; sudo LUA_VERSION=5.1 luarocks install kong-pongo\"",
            "bash -c \"export PATH=$PATH:/usr/local/bin; sudo LUA_VERSION=5.1 luarocks install busted\""
        ]
        
        for cmd in pongo_install_cmds:
            install_result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=False)
            if install_result.returncode != 0:
                print(f"[REMOTE] Error during Lua package installation. Command: {cmd}", file=sys.stderr)
                print(f"[REMOTE] STDOUT: {install_result.stdout}", file=sys.stderr)
                print(f"[REMOTE] STDERR: {install_result.stderr}", file=sys.stderr)
                return False

    print(f"[REMOTE] Creating final plugin directory: {remote_final_plugin_path}...")
    mkdir_cmd = f"sudo mkdir -p {remote_final_plugin_path}"
    mkdir_result = subprocess.run(mkdir_cmd, shell=True, capture_output=True, text=True, check=False)
    if mkdir_result.returncode != 0:
        print(f"[REMOTE] Error creating final plugin directory. Command: {mkdir_cmd}", file=sys.stderr)
        print(f"[REMOTE] STDOUT: {mkdir_result.stdout}", file=sys.stderr)
        print(f"[REMOTE] STDERR: {mkdir_result.stderr}", file=sys.stderr)
        return False
    print("[REMOTE] Final plugin directory ensured.")

    print(f"[REMOTE] Synchronizing plugins from {remote_apigee_plugins_source} to {remote_final_plugin_path}...")
    # Use rsync with --delete to ensure the destination is an exact mirror of the source
    move_plugins_cmd = f"sudo rsync -av --delete {remote_apigee_plugins_source}/ {remote_final_plugin_path}/"
    move_plugins_result = subprocess.run(move_plugins_cmd, shell=True, capture_output=True, text=True, check=False)
    if move_plugins_result.returncode != 0:
        print(f"[REMOTE] Error moving plugins. Command: {move_plugins_cmd}", file=sys.stderr)
        print(f"[REMOTE] STDOUT: {move_plugins_result.stdout}", file=sys.stderr)
        print(f"[REMOTE] STDERR: {move_plugins_result.stderr}", file=sys.stderr)
        return False
    print("[REMOTE] Plugins synchronized to final destination.")

    print("[REMOTE] Environment setup and plugin placement complete.")
    
    validation_results = run_pongo_validation_on_remote(remote_final_plugin_path, kong_version)
    
    results_file = os.path.join(remote_temp_dir, "validation_results.json").replace("\\", "/")
    with open(results_file, "w") as f:
        json.dump(validation_results, f, indent=4)
    print(f"[REMOTE] Validation results saved to {results_file}")

    return True

def main():
    parser = argparse.ArgumentParser(description="Remote plugin deployment and validation tool.")
    parser.add_argument(
        "--config",
        type=str,
        default="configs/config.json",
        help="Path to the configuration JSON file (default: configs/config.json)"
    )
    parser.add_argument(
        "--remote-run",
        action="store_true",
        help="Flag to indicate that the script is running on the remote server."
    )
    parser.add_argument(
        "--remote-temp-dir",
        type=str,
        help="Path on the remote server where the script and local project were temporarily placed."
    )
    parser.add_argument(
        "--remote-final-plugin-path",
        type=str,
        help="Final destination path for plugins on the remote server."
    )
    parser.add_argument(
        "--kong-version",
        type=str,
        default="3.11.0.0",
        help="Kong version to validate against (default: 3.11.0.0)."
    )

    args = parser.parse_args()

    if args.remote_run:
        if not all([args.remote_temp_dir, args.remote_final_plugin_path, args.kong_version]):
            print("[REMOTE] Error: Missing remote-temp-dir, remote-final-plugin-path, or kong-version for remote run.", file=sys.stderr)
            sys.exit(1)
        
        success = run_remote_setup_and_place_plugins(
            args.remote_temp_dir,
            args.remote_final_plugin_path,
            args.kong_version
        )
        if success:
            print("[REMOTE] Remote setup and plugin placement completed successfully.")
            sys.exit(0)
        else:
            print("[REMOTE] Remote setup and plugin placement failed.", file=sys.stderr)
            sys.exit(1)

    import paramiko
    ssh_client = None
    try:
        print(f"Loading configuration from {args.config}...")
        config = load_config(args.config)
        print("Configuration loaded successfully.")

        remote_config = config.get("remote_server", {})
        if not all(k in remote_config for k in ["host", "username", "ssh_key_path", "remote_temp_dir", "remote_final_plugin_path"]):
            raise ValueError("Missing 'host', 'username', 'ssh_key_path', 'remote_temp_dir', or 'remote_final_plugin_path' in remote_server configuration.")
        
        apigee_plugins_dir = config.get("apigee_plugins_dir", "apigee-policies-based-plugins")
        if not os.path.exists(apigee_plugins_dir):
            raise FileNotFoundError(f"Local Apigee plugins directory not found at: {apigee_plugins_dir}")

        print(f"Attempting to connect to {remote_config['username']}@{remote_config['host']}...")
        ssh_client = create_ssh_client(
            remote_config["host"],
            remote_config["username"],
            remote_config["ssh_key_path"]
        )
        print("SSH connection tested successfully.")

        remote_temp_dir = remote_config["remote_temp_dir"]
        remote_final_plugin_path = remote_config["remote_final_plugin_path"]
        kong_version = args.kong_version

        script_name = os.path.basename(__file__)
        local_script_path = os.path.abspath(__file__)
        remote_script_path = os.path.join(remote_temp_dir, script_name).replace("\\", "/")

        transfer_files_to_remote(ssh_client, local_script_path, remote_temp_dir)
        print(f"Validator script placed on remote server at: {remote_script_path}")

        # --- Diagnostic: Verify remote script content ---
        print(f"Verifying content of {remote_script_path} on remote server...", file=sys.stderr)
        stdin, stdout, stderr = ssh_client.exec_command(f"cat {remote_script_path}")
        remote_script_content = stdout.read().decode().strip()
        remote_script_error = stderr.read().decode().strip()
        if remote_script_error:
            print(f"Error verifying remote script content: {remote_script_error}", file=sys.stderr)
        else:
            print(f"--- Remote Script Content Start ---\n{remote_script_content}\n--- Remote Script Content End ---", file=sys.stderr)
        # --- End Diagnostic ---

        local_requirements_path = "requirements.txt"
        if os.path.exists(local_requirements_path):
            transfer_files_to_remote(ssh_client, local_requirements_path, remote_temp_dir)
            formatted_remote_req_path = os.path.join(remote_temp_dir, 'requirements.txt').replace('\\', '/')
            print(f"requirements.txt placed on remote server at: {formatted_remote_req_path}")
        else:
            print("Warning: requirements.txt not found locally. Remote setup might fail.", file=sys.stderr)

        remote_plugins_temp_path_full = os.path.join(remote_temp_dir, os.path.basename(apigee_plugins_dir)).replace("\\", "/")
        transfer_files_to_remote(ssh_client, apigee_plugins_dir, remote_temp_dir)
        print(f"Plugins placed on remote server at: {remote_plugins_temp_path_full}")

        remote_command = (
            f"bash -c \"cat {remote_script_path} | python3 - --remote-run "
            f"--remote-temp-dir {remote_temp_dir} "
            f"--remote-final-plugin-path {remote_final_plugin_path} "
            f"--kong-version {kong_version}\""
        )
        print(f"Executing remote setup script: {remote_command}")
        exit_status, stdout, stderr = execute_remote_command(ssh_client, remote_command)

        if exit_status == 0:
            print("Remote setup and plugin placement completed successfully.")
            remote_results_file = os.path.join(remote_temp_dir, "validation_results.json").replace("\\", "/")
            local_results_file = os.path.join(os.getcwd(), "validation_results.json")
            
            retrieve_file_from_remote(ssh_client, remote_results_file, local_results_file)
            
            with open(local_results_file, 'r') as f:
                validation_results = json.load(f)
            
            display_validation_summary(validation_results)
            os.remove(local_results_file) # Clean up local results file
            print(f"Cleaned up local results file: {local_results_file}")

        else:
            print(f"Remote setup and plugin placement failed with exit status {exit_status}.", file=sys.stderr)
            raise Exception("Remote setup failed.")

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in config file {args.config} or remote results file.", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        print(f"Configuration Error: {e}", file=sys.stderr)
        sys.exit(1)
    except paramiko.SSHException:
        print("SSH connection failed. Exiting.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        if ssh_client:
            print("Closing SSH connection.")
            ssh_client.close()

if __name__ == "__main__":
    main()