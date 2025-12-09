import unittest
from unittest.mock import Mock
import json

# Reusing the Python implementation from the functional tests
from tests.log_shared_context.test_functional import LogSharedContextHandler, KongMock

class TestLogSharedContextUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = LogSharedContextHandler(self.kong_mock)

    def test_prefix_matching_logic(self):
        """
        Test Case 1: Verifies the nuances of prefix matching.
        """
        # In the lua code, `k:sub(1, #prefix) == prefix` handles startswith,
        # and `k == prefix` handles exact match.
        conf = {'log_key': 'unit_test', 'target_key_prefix': 'log_'}
        
        self.kong_mock.ctx['shared'] = {
            'log_this': 'value1',
            'log_that': 'value2',
            'dont_log_this': 'value3',
            'log_': 'exact_match_value', # Exact match should also be included
            'log': 'should_not_match' # Does not start with "log_"
        }

        expected_data = {
            'log_this': 'value1',
            'log_that': 'value2',
            'log_': 'exact_match_value'
        }
        expected_json = json.dumps(expected_data)

        self.plugin.log(conf)

        self.kong_mock.log.notice.assert_called_once_with(
            "LOG_SHARED_CONTEXT -- ", 'unit_test', ": ", expected_json
        )

# Since the plugin is so simple, additional unit tests would largely repeat
# the functional tests. This single test focuses on the core filtering logic.

if __name__ == '__main__':
    unittest.main()
