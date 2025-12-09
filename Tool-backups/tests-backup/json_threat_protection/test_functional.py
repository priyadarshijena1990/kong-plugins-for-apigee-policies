import unittest
from unittest.mock import Mock
import json

# Python implementation of the recursive validator for testing
def validate_json_py(conf, data, current_depth):
    max_depth = conf.get('max_container_depth')
    if max_depth and max_depth > 0 and current_depth > max_depth:
        return False

    if isinstance(data, dict):
        max_entries = conf.get('max_object_entry_count')
        if max_entries and max_entries > 0 and len(data) > max_entries:
            return False
        for key, value in data.items():
            max_name_len = conf.get('max_object_entry_name_length')
            if max_name_len and max_name_len > 0 and len(str(key)) > max_name_len:
                return False
            if not validate_json_py(conf, value, current_depth + 1):
                return False
    elif isinstance(data, list):
        max_elements = conf.get('max_array_elements')
        if max_elements and max_elements > 0 and len(data) > max_elements:
            return False
        for item in data:
            if not validate_json_py(conf, item, current_depth + 1):
                return False
    elif isinstance(data, str):
        max_str_len = conf.get('max_string_value_length')
        if max_str_len and max_str_len > 0 and len(data) > max_str_len:
            return False
    
    return True

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.request = Mock()

class JSONThreatProtectionHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        body = self.kong.request.get_raw_body()
        if not body: return

        try:
            parsed_json = json.loads(body)
        except json.JSONDecodeError:
            return self.kong.response.exit(conf['on_violation_status'], conf['on_violation_body'])

        if not validate_json_py(conf, parsed_json, 1):
            if not conf.get('on_violation_continue', False):
                return self.kong.response.exit(conf['on_violation_status'], conf['on_violation_body'])

class TestJSONThreatProtectionFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = JSONThreatProtectionHandler(self.kong_mock)
        self.base_conf = {
            'on_violation_status': 400,
            'on_violation_body': 'Threat detected'
        }

    def test_exceed_max_container_depth(self):
        """
        Test Case 1: Blocks JSON that exceeds the maximum container depth.
        """
        conf = {**self.base_conf, 'max_container_depth': 2}
        # A JSON with depth 3
        deep_json = '{"level1": {"level2": {"level3": "value"}}}'
        self.kong_mock.request.get_raw_body.return_value = deep_json

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(400, 'Threat detected')

    def test_exceed_max_array_elements(self):
        """
        Test Case 2: Blocks JSON with an array containing too many elements.
        """
        conf = {**self.base_conf, 'max_array_elements': 3}
        # JSON with an array of 4 elements
        large_array_json = '{"data": [1, 2, 3, 4]}'
        self.kong_mock.request.get_raw_body.return_value = large_array_json

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(400, 'Threat detected')

    def test_valid_json_passes(self):
        """
        Test Case 3: Allows a valid JSON payload to pass all checks.
        """
        conf = {
            **self.base_conf,
            'max_container_depth': 5,
            'max_array_elements': 10,
            'max_object_entry_count': 10,
            'max_object_entry_name_length': 50,
            'max_string_value_length': 1000
        }
        valid_json = '{"user": {"id": 123, "name": "test", "tags": ["a", "b"]}}'
        self.kong_mock.request.get_raw_body.return_value = valid_json

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
