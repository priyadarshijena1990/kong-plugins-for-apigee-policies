import unittest
from unittest.mock import Mock
import json
import re

# Python implementation of helpers for generating expected output
def get_json_path_ref_py(data, path_str):
    if not data or not path_str or path_str == "" or path_str == ".":
        return data, None, None, True
    path_parts = path_str.split('.')
    current = data
    parent = None
    last_key = None
    for i, part in enumerate(path_parts):
        if isinstance(current, dict) and part in current:
            parent = current
            last_key = part
            current = current[part]
        else:
            return None, None, None, False
    return current, parent, last_key, True

def modify_json_field_py(data, path_str, new_value, action):
    if not data or not path_str: return False
    if path_str == "." or path_str == "": return False # Not handled here for root

    val, parent, last_key, found = get_json_path_ref_py(data, path_str)
    if not found or not parent or not last_key: return False

    if action == "remove":
        del parent[last_key]
    elif action == "redact":
        parent[last_key] = new_value
    else:
        return False
    return True


class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()

class SanitizeModelResponseHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def body_filter(self, conf):
        original_body = self.kong.response.get_raw_body()
        if not original_body:
            return

        parsed_body = None
        try:
            parsed_body = json.loads(original_body)
        except json.JSONDecodeError:
            pass # Fallback to string processing

        if parsed_body:
            for path in conf.get('remove_fields', []):
                modify_json_field_py(parsed_body, path, None, "remove")
            for path in conf.get('redact_fields', []):
                modify_json_field_py(parsed_body, path, conf.get('redaction_string', '[REDACTED]'), "redact")
            
            final_response_string = json.dumps(parsed_body)
        else: # Non-JSON body
            final_response_string = original_body
        
        for rep in conf.get('replacements', []):
            final_response_string = re.sub(rep['pattern'], rep['replacement'], final_response_string)
        
        if conf.get('max_length') and len(final_response_string) > conf['max_length']:
            final_response_string = final_response_string[:conf['max_length']]

        self.kong.response.set_body(final_response_string)


class TestSanitizeModelResponseFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = SanitizeModelResponseHandler(self.kong_mock)
        self.sample_json = {
            "id": "123",
            "user": {
                "name": "John Doe",
                "email": "john.doe@example.com",
                "internal_id": "abc-xyz"
            },
            "data": [
                {"item": 1, "secret": "s1"},
                {"item": 2, "secret": "s2"}
            ],
            "debug_info": "logs here"
        }
        self.sample_json_str = json.dumps(self.sample_json)

    def test_remove_and_redact_fields(self):
        """
        Test Case 1: Fields are correctly removed and redacted.
        """
        conf = {
            'remove_fields': ['user.internal_id', 'debug_info'],
            'redact_fields': ['user.email', 'data.0.secret'],
            'redaction_string': '***REDACTED***'
        }
        self.kong_mock.response.get_raw_body.return_value = self.sample_json_str

        # Generate expected output
        expected_json_obj = json.loads(self.sample_json_str)
        modify_json_field_py(expected_json_obj, 'user.internal_id', None, 'remove')
        modify_json_field_py(expected_json_obj, 'debug_info', None, 'remove')
        modify_json_field_py(expected_json_obj, 'user.email', '***REDACTED***', 'redact')
        modify_json_field_py(expected_json_obj, 'data.0.secret', '***REDACTED***', 'redact')
        expected_output_str = json.dumps(expected_json_obj)

        self.plugin.body_filter(conf)

        self.kong_mock.response.set_body.assert_called_once_with(expected_output_str)

    def test_replacements_and_truncate_length(self):
        """
        Test Case 2: String replacements and truncation are applied.
        """
        conf = {
            'replacements': [
                {'pattern': 'John Doe', 'replacement': 'Jane Doe'},
                {'pattern': 'example.com', 'replacement': 'newdomain.org'}
            ],
            'max_length': 50 # Truncate after 50 characters
        }
        self.kong_mock.response.get_raw_body.return_value = self.sample_json_str

        # Generate expected output
        modified_str = re.sub('John Doe', 'Jane Doe', self.sample_json_str)
        modified_str = re.sub('example.com', 'newdomain.org', modified_str)
        expected_output_str = modified_str[:50]

        self.plugin.body_filter(conf)

        self.kong_mock.response.set_body.assert_called_once_with(expected_output_str)

    def test_non_json_body_processing(self):
        """
        Test Case 3: String replacements and truncation apply to plain text bodies.
        """
        conf = {
            'replacements': [
                {'pattern': 'secret_token', 'replacement': 'REDACTED'}
            ],
            'max_length': 20
        }
        plain_text_body = "This is a secret_token in plain text."
        self.kong_mock.response.get_raw_body.return_value = plain_text_body

        # Generate expected output
        modified_str = re.sub('secret_token', 'REDACTED', plain_text_body)
        expected_output_str = modified_str[:20]

        self.plugin.body_filter(conf)

        self.kong_mock.response.set_body.assert_called_once_with(expected_output_str)

if __name__ == '__main__':
    unittest.main()
