import unittest
from unittest.mock import Mock

# Reusing the Python implementation from the functional tests
from tests.json_threat_protection.test_functional import JSONThreatProtectionHandler, KongMock

class TestJSONThreatProtectionUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = JSONThreatProtectionHandler(self.kong_mock)
        self.base_conf = {
            'on_violation_status': 400,
            'on_violation_body': 'Threat detected'
        }

    def test_exceed_max_string_value_length(self):
        """
        Test Case 1: Blocks JSON with a string value that is too long.
        """
        conf = {**self.base_conf, 'max_string_value_length': 10}
        long_string_json = '{"key": "this string is too long"}'
        self.kong_mock.request.get_raw_body.return_value = long_string_json

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(400, 'Threat detected')

    def test_exceed_max_object_entry_name_length(self):
        """
        Test Case 2: Blocks JSON with an object property name that is too long.
        """
        conf = {**self.base_conf, 'max_object_entry_name_length': 8}
        long_key_json = '{"this_key_is_very_long": "value"}'
        self.kong_mock.request.get_raw_body.return_value = long_key_json

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(400, 'Threat detected')

    def test_violation_with_continue_on_error(self):
        """
        Test Case 3: Request proceeds on violation if on_violation_continue is true.
        """
        conf = {
            **self.base_conf,
            'max_container_depth': 1,
            'on_violation_continue': True # Key for this test
        }
        # This JSON violates the depth limit of 1
        deep_json = '{"level1": {"level2": "value"}}'
        self.kong_mock.request.get_raw_body.return_value = deep_json
        
        self.plugin.access(conf)

        # Assert that the request was NOT terminated
        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
