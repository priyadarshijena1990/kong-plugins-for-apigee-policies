import os
import shutil
import subprocess
import sys

PLUGIN_SRC_DIR = "apigee-policies-based-plugins"
KONG_PLUGIN_DST = "/usr/local/share/lua/5.1/kong/plugins"

# List of plugins to deploy (all folders in the source directory)
def get_plugin_list():
    return [d for d in os.listdir(PLUGIN_SRC_DIR) if os.path.isdir(os.path.join(PLUGIN_SRC_DIR, d))]

def copy_plugin(plugin_name):
    src = os.path.join(PLUGIN_SRC_DIR, plugin_name)
    dst = os.path.join(KONG_PLUGIN_DST, plugin_name)
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    print(f"Copied {plugin_name} to {dst}")

def update_kong_conf(plugin_names, kong_conf_path="/etc/kong/kong.conf"):
    with open(kong_conf_path, "r") as f:
        lines = f.readlines()
    found = False
    for i, line in enumerate(lines):
        if line.strip().startswith("plugins ="):
            found = True
            plugins_line = line.strip().split("=", 1)[1].strip()
            plugins = [p.strip() for p in plugins_line.split(",") if p.strip()]
            for plugin in plugin_names:
                if plugin not in plugins:
                    plugins.append(plugin)
            lines[i] = f"plugins = {','.join(plugins)}\n"
    if not found:
        lines.append(f"plugins = bundled,{','.join(plugin_names)}\n")
    with open(kong_conf_path, "w") as f:
        f.writelines(lines)
    print(f"Updated {kong_conf_path} with plugins: {', '.join(plugin_names)}")

def restart_kong():
    print("Restarting Kong...")
    subprocess.run(["kong", "restart"])  # Assumes kong is in PATH

def main():
    plugins = get_plugin_list()
    print(f"Deploying plugins: {', '.join(plugins)}")
    for plugin in plugins:
        copy_plugin(plugin)
    update_kong_conf(plugins)
    restart_kong()
    print("Deployment complete. Check Kong logs and Admin API for plugin status.")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("This script must be run as root (to copy files to Kong directories).", file=sys.stderr)
        sys.exit(1)
    main()
