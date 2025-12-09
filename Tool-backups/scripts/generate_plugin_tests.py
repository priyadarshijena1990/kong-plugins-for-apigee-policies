import os
import shutil

# Configuration
PLUGIN_BASE_DIR = "apigee-policies-based-plugins"
TESTS_BASE_DIR = "tests"

def get_plugin_dirs(base_dir):
    """
    Discovers all plugin directories under the given base directory.
    """
    plugin_dirs = []
    for entry in os.listdir(base_dir):
        path = os.path.join(base_dir, entry)
        if os.path.isdir(path) and not entry.startswith('.'):
            # Check if it contains expected plugin files like handler.lua or schema.lua
            if any(f in os.listdir(path) for f in ["handler.lua", "schema.lua"]):
                plugin_dirs.append(entry)
    return plugin_dirs

def create_placeholder_test_file(plugin_name):
    """
    Creates a placeholder test file for a given plugin.
    """
    plugin_test_dir = os.path.join(TESTS_BASE_DIR, plugin_name)
    os.makedirs(plugin_test_dir, exist_ok=True)
    
    test_file_path = os.path.join(plugin_test_dir, f"test_{plugin_name.replace('-', '_')}.py")
    
    if not os.path.exists(test_file_path):
        content = f"""import unittest
import os

class Test{plugin_name.replace('-', '').title()}(unittest.TestCase):
    def setUp(self):
        # Setup any necessary test environment or mock data
        pass

    def tearDown(self):
        # Clean up after tests
        pass

    def test_example_functionality(self):
        # This is a placeholder test.
        # Replace with actual tests for the '{plugin_name}' plugin.
        self.assertTrue(True) # Replace with actual assertions
        print(f"Placeholder test for {{os.path.basename(os.path.dirname(__file__))}} plugin executed.")

if __name__ == '__main__':
    unittest.main()
"""
        with open(test_file_path, "w") as f:
            f.write(content)
        print(f"Created placeholder test file: {test_file_path}")
    else:
        print(f"Test file already exists for {plugin_name}: {test_file_path}")

def main():
    print(f"Discovering plugins in {PLUGIN_BASE_DIR}...")
    plugin_dirs = get_plugin_dirs(PLUGIN_BASE_DIR)
    
    if not plugin_dirs:
        print(f"No plugin directories found in {PLUGIN_BASE_DIR}.")
        return

    print("Generating placeholder test files...")
    for plugin in plugin_dirs:
        create_placeholder_test_file(plugin)
    print("Finished generating placeholder test files.")

if __name__ == '__main__':
    main()
