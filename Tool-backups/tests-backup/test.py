import os
import unittest
import sys
import subprocess
import shutil # Re-added for command_exists

# --- Helper function to check if a command exists ---
def command_exists(cmd):
    return shutil.which(cmd) is not None # shutil.which is preferred for cross-platform


def main():
    """
    This script discovers and runs all tests for the Kong plugins.
    """
    # Get the directory where this script is located.
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Add the project root to sys.path to allow imports like 'from tests.module import ...'
    project_root = os.path.dirname(script_dir)
    sys.path.insert(0, project_root)
    # Add the script's directory (tests) to sys.path as well, in case of direct imports
    sys.path.insert(1, script_dir)
    # Add the scripts directory to sys.path
    scripts_path = os.path.join(project_root, 'scripts')
    sys.path.insert(2, scripts_path)

    # Custom Python test discovery
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Discover Python test files manually from renamed directories
    # Iterate through each subdirectory in 'tests'
    for plugin_test_dir_name in os.listdir(script_dir):
        plugin_test_dir_path = os.path.join(script_dir, plugin_test_dir_name)
        
        # Ensure it's a directory and not __pycache__ or a file
        if not os.path.isdir(plugin_test_dir_path) or plugin_test_dir_name == '__pycache__':
            continue

        # Find test files within this plugin's test directory
        for root, _, files in os.walk(plugin_test_dir_path):
            for file in files:
                if file.startswith("test") and file.endswith(".py"):
                    # Construct the module name
                    # e.g., tests.access_entity.test_functional
                    relative_to_tests = os.path.relpath(os.path.join(root, os.path.splitext(file)[0]), script_dir)
                    # Replace platform-specific path separators with '.' for module name
                    module_name = "tests." + relative_to_tests.replace(os.sep, '.')
                    
                    try:
                        # Dynamically load the test module
                        suite.addTests(loader.loadTestsFromName(module_name))
                    except Exception as e:
                        print(f"Error loading test module {module_name}: {e}", file=sys.stderr)
                        class FailedTest(unittest.TestCase):
                            def test_failed_to_load(self):
                                raise Exception(f"Failed to load test module {module_name}: {e}")
                        suite.addTest(unittest.makeSuite(FailedTest))

    # Run the discovered Python tests.
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # --- Python Test Summary ---
    python_failures = len(result.failures)
    python_errors = len(result.errors)
    python_total_ran = result.testsRun


    print("\n--- Running Lua Tests ---")
    lua_test_files = []
    # Loop through the renamed test directories to find Lua tests
    for plugin_test_dir_name in os.listdir(script_dir):
        plugin_test_dir_path = os.path.join(script_dir, plugin_test_dir_name)
        if not os.path.isdir(plugin_test_dir_path) or plugin_test_dir_name == '__pycache__':
            continue
        for root, _, files in os.walk(plugin_test_dir_path):
            for file in files:
                if file.startswith("test") and file.endswith(".lua"):
                    lua_test_files.append(os.path.join(root, file))

    lua_failures = 0
    lua_passed = 0
    lua_error_details = []

    pongo_found = command_exists("pongo")
    if not pongo_found:
        print("WARNING: 'pongo' command not found in PATH. Skipping Lua tests.", file=sys.stderr)
        lua_failures = len(lua_test_files) # Mark all as failed due to environment
        for lua_test_file in lua_test_files:
            lua_error_details.append(f"Lua Test Skipped: {lua_test_file} - 'pongo' not found in PATH.")
    else:
        for lua_test_file in lua_test_files:
            plugins_dir = os.path.join(project_root, "apigee-policies-based-plugins")
            print(f"Running Lua test: {os.path.basename(lua_test_file)} using pongo...")
            try:
                # pongo test requires the plugin to be accessible from where pongo is executed
                # Or pongo test can be run against individual test files
                # Assuming pongo test <file> works as per common test runner patterns
                # Declarative tests (`01-request.t`) are run against the directory
                if os.path.basename(lua_test_file) == '01-request.t':
                    test_path = os.path.dirname(lua_test_file)
                    command = ["pongo", "test", "-p", plugins_dir, test_path]
                else: # Imperative unit tests are run against the file
                    test_path = lua_test_file
                    command = ["pongo", "test", "--plugins", plugins_dir, test_path]

                process = subprocess.run(command, capture_output=True, text=True, check=False)

                # Check for specific failure indicators or lack of success indicator
                # pongo output format might differ from raw lua.
                # Assuming pongo will return non-zero for failures.
                if process.returncode != 0:
                    lua_failures += 1
                    lua_error_details.append(f"Lua Test Failed: {lua_test_file}\nStdout:\n{process.stdout}\nStderr:\n{process.stderr}")
                # Pongo success output for declarative tests is different from imperative
                elif ("All tests successful" in process.stdout or \
                     ("0 failures" in process.stdout and "0 errors" in process.stdout) or \
                     "passed successfully!" in process.stdout):
                    lua_passed += 1
                else:
                    # If exit code is 0 but expected success message isn't there, or if assert fails
                    lua_failures += 1
                    lua_error_details.append(f"Lua Test Failed (Unexpected Pongo Output): {lua_test_file}\nStdout:\n{process.stdout}\nStderr:\n{process.stderr}")

            except FileNotFoundError:
                lua_failures += 1
                lua_error_details.append(f"Pongo command not found for {lua_test_file}. Please ensure 'pongo' is in your system's PATH.")
            except Exception as e:
                lua_failures += 1
                lua_error_details.append(f"Error running Lua test {lua_test_file}: {e}\nStdout:\n{process.stdout if 'process' in locals() else 'N/A'}\nStderr:\n{process.stderr if 'process' in locals() else 'N/A'}")

    # --- Combined Test Summary ---
    print("\n--- Combined Test Summary ---")
    print(f"Python Tests Run: {python_total_ran}")
    print(f"Python Failures: {python_failures}")
    print(f"Python Errors: {python_errors}")
    print(f"Lua Tests Run: {len(lua_test_files)}")
    print(f"Lua Passed: {lua_passed}")
    print(f"Lua Failures: {lua_failures}")

    total_failures = python_failures + lua_failures
    total_errors = python_errors

    if total_failures == 0 and total_errors == 0:
        print("\nAll Python and Lua tests passed successfully!")
        sys.exit(0)
    else:
        print("\nSome tests failed or encountered errors.")
        if result.failures:
            print("\n--- Python Failure Details ---")
            for test, traceback_text in result.failures:
                print(f"Test: {test}\n{traceback_text}")

        if result.errors:
            print("\n--- Python Error Details ---")
            for test, traceback_text in result.errors:
                print(f"Test: {test}\n{traceback_text}")

        if lua_error_details:
            print("\n--- Lua Test Failure/Error Details ---")
            for detail in lua_error_details:
                print(detail)
        sys.exit(1)

if __name__ == "__main__":
    main()
