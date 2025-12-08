import unittest
from unittest.mock import Mock
import json
import re

# Reusing the Python implementation from the functional tests
from tests.sanitize_model_response.test_functional import SanitizeModelResponseHandler, KongMock, modify_json_field_py

class TestSanitizeModelResponseUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = SanitizeModelResponseHandler(self.kong_mock)
        self.sample_json = {
            "user": {
                "name": "John Doe",
                "email": "john.doe@example.com"
            },
            "data": "some value"
        }
        self.sample_json_str = json.dumps(self.sample_json)

    def test_empty_configuration_no_change(self):
        """
        Test Case 1: Empty configuration (no remove, redact, replace, max_length) should pass through unchanged.
        """
        conf = {}
        self.kong_mock.response.get_raw_body.return_value = self.sample_json_str

        self.plugin.body_filter(conf)

        self.kong_mock.response.set_body.assert_called_once_with(self.sample_json_str)

    def test_redaction_with_default_string(self):
        """
        Test Case 2: Redacts with the default string when redaction_string is not specified.
        """
        conf = {
            'redact_fields': ['user.email']
            # redaction_string is omitted, expecting default [REDACTED]
        }
        self.kong_mock.response.get_raw_body.return_value = self.sample_json_str

        expected_json_obj = json.loads(self.sample_json_str)
        modify_json_field_py(expected_json_obj, 'user.email', '[REDACTED]', 'redact')
        expected_output_str = json.dumps(expected_json_obj)

        self.plugin.body_filter(conf)

        self.kong_mock.response.set_body.assert_called_once_with(expected_output_str)

    def test_non_existent_jsonpath_for_removal(self):
        """
        Test Case 3: Plugin handles non-existent JSONPath for removal gracefully.
        """
        conf = {
            'remove_fields': ['user.non_existent_field'],
            'redact_fields': [],
            'replacements': [],
            'max_length': None
        }
        self.kong_mock.response.get_raw_body.return_value = self.sample_json_str

        # Act
        self.plugin.body_filter(conf)

        # Assert: No error should occur, and the original body (minus any other changes) should be set.
        # Since no other changes are configured, it should be the same.
        self.kong_mock.response.set_body.assert_called_once_with(self.sample_json_str)
        # Check that no calls to log.err were made
        self.kong_mock.log.err.assert_not_called()


if __name__ == '__main__':
    unittest.main()
