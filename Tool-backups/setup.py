import os
import subprocess
import sys

def check_wsl_installed():
    """Checks if Windows Subsystem for Linux (WSL) is installed."""
    try:
        # This command lists installed WSL distributions
        result = subprocess.run(["wsl", "--list"], capture_output=True, text=True, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
        # If there's any output beyond the header, WSL is likely installed
        return "Windows Subsystem for Linux Distributions:" in result.stdout and len(result.stdout.strip().splitlines()) > 1
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def guide_wsl_installation():
    """Provides instructions for WSL installation."""
    print("--------------------------------------------------------------------------------")
    print("                     WSL (Windows Subsystem for Linux) Setup Guide              ")
    print("--------------------------------------------------------------------------------")
    print("It appears WSL is not installed or not configured properly on your system.")
    print("Kong Pongo often requires a Linux environment (like bash) to function correctly.")
    print("\nTo set up WSL and a Linux distribution (e.g., Ubuntu), please follow these steps:")
    print("1. Open PowerShell as Administrator.")
    print("2. Run: wsl --install")
    print("   This command will enable the necessary WSL features and install Ubuntu by default.")
    print("   You may need to restart your computer after this step.")
    print("3. After restarting, open the Ubuntu (or your chosen distro) application from your Start Menu.")
    print("   It will complete the installation and prompt you to create a username and password.")
    print("4. Once WSL is set up, re-run this setup.py script from within your WSL terminal.")
    print("   Navigate to your project directory (e.g., /mnt/c/Users/YourUser/project-folder).")
    print("   Then run: python3 setup.py")
    print("\nFor more detailed instructions, visit: https://learn.microsoft.com/en-us/windows/wsl/install")
    print("--------------------------------------------------------------------------------")

def setup_pongo_in_wsl():
    """Provides instructions for installing and setting up pongo within WSL."""
    print("--------------------------------------------------------------------------------")
    print("                Kong Pongo Setup Guide for WSL (Linux Environment)              ")
    print("--------------------------------------------------------------------------------")
    print("You are running inside a WSL (Linux) environment. Let's set up Kong Pongo.")
    print("\n1. Ensure you have the necessary build tools and LuaRocks:")
    print("   sudo apt update")
    print("   sudo apt install build-essential luarocks -y")
    print("\n2. Install Kong Pongo and its dependencies (like busted) using LuaRocks:")
    print("   sudo luarocks install kong-pongo")
    print("   sudo luarocks install busted")
    print("\n3. Verify Pongo installation:")
    print("   pongo --version")
    print("\n4. Create the .pongo.yml configuration file (if not already present):")
    pongo_yml_content = """
workspace: .
kong_version: "3.11"
plugins:
  - apigee-policies-based-plugins
test_scripts:
  - unittests
"""
    pongo_yml_path = ".pongo.yml"
    if not os.path.exists(pongo_yml_path):
        with open(pongo_yml_path, "w") as f:
            f.write(pongo_yml_content)
        print(f"\nCreated {pongo_yml_path} with Kong version 3.11.")
    else:
        print(f"\n{pongo_yml_path} already exists. Please ensure it's configured for Kong 3.11.")
    
    print("\n5. After Pongo is installed and .pongo.yml is configured, you can run your tests.")
    print("   From within this WSL terminal, navigate to your project directory and run:")
    print("   pongo run -- kong-pongo test")
    print("\n   If you want to run tests from Windows PowerShell/CMD (after Pongo is set up in WSL):")
    print("   wsl.exe -e bash -c 'cd \"$(wslpath \\\"$(pwd)\\\")\" && pongo run -- kong-pongo test'")
    print("--------------------------------------------------------------------------------")

def main():
    if sys.platform == "win32":
        if check_wsl_installed():
            print("WSL is detected. To complete the setup, please run this script INSIDE your WSL terminal.")
            print("Open your WSL terminal (e.g., Ubuntu), navigate to this project directory, and run:")
            print("python3 setup.py")
        else:
            guide_wsl_installation()
    else: # Assumes Linux/WSL environment
        setup_pongo_in_wsl()

if __name__ == "__main__":
    main()
