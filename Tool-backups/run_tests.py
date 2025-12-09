import unittest
import os
import sys

def run_tests():
    """
    Discovers and runs all tests in the 'tests' directory.
    """
    # Get the directory of the current script (run_tests.py)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Add the project root to the Python path to allow imports from scripts/
    project_root = script_dir
    if project_root not in sys.path:
        sys.path.insert(0, project_root)

    test_loader = unittest.TestLoader()
    test_suite = test_loader.discover(start_dir=os.path.join(script_dir, 'tests'), pattern='test_*.py')

    runner = unittest.TextTestRunner(verbosity=2)
    runner.run(test_suite)

if __name__ == '__main__':
    run_tests()