import unittest
from unittest.mock import Mock
import re
import json

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.request = Mock()

class RegularExpressionProtectionHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_request_part(self, source_type, source_name):
        if source_type == "header":
            return self.kong.request.get_header(source_name)
        elif source_type == "body":
            body_str = self.kong.request.get_raw_body()
            if not body_str: return ""
            if source_name:  # If a JSON path is specified
                try:
                    data = json.loads(body_str) # Attempt to parse as JSON
                    # Simplified dot notation resolver for the test
                    value = data
                    for part in source_name.split('.'):
                        value = value[part]
                    return str(value)
                except (json.JSONDecodeError, KeyError, TypeError, AttributeError): # If not valid JSON or path fails
                    return "" # Can't find a value at the path, so return empty string
            return body_str  # Otherwise, return the whole raw body
        return ""

    def access(self, conf):
        for source_config in conf.get('sources', []):
            target_value = self.get_value_from_request_part(
                source_config['source_type'], source_config.get('source_name')
            )
            for pattern in source_config.get('patterns', []):
                if re.search(pattern, target_value):
                    if source_config.get('match_action', 'block') == 'block':
                        return self.kong.response.exit(conf.get('violation_status', 403), conf.get('violation_body', 'Forbidden'))
                    else:
                        # In continue mode, we just log and proceed
                        pass
        
class TestRegularExpressionProtectionFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = RegularExpressionProtectionHandler(self.kong_mock)
        self.base_conf = {
            'violation_status': 403,
            'violation_body': 'Forbidden',
            'match_action': 'abort'
        }

    def test_block_on_header(self):
        """
        Test Case 1: Blocks a request if a pattern matches in a specified header.
        """
        conf = {
            **self.base_conf,
            'sources': [{
                'source_type': 'header',
                'source_name': 'X-User-Input',
                'patterns': ["<script>"] # Block script tags
            }]
        }
        # Arrange
        self.kong_mock.request.get_header.return_value = 'some value <script>alert(1)</script>'
        
        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.response.exit.assert_called_once_with(403, 'Forbidden')

    def test_block_on_body_jsonpath(self):
        """
        Test Case 2: Blocks a request based on a pattern match in a specific JSON field.
        """
        conf = {
            **self.base_conf,
            'sources': [{
                'source_type': 'body',
                'source_name': 'comment.text', # Check this specific field
                'patterns': ["(?i)delete from"] # Case-insensitive SQL injection attempt
            }]
        }
        
        # Test 1: Match in the correct field should block
        bad_body = '{"comment": {"text": "nice post; DELETE FROM users;"}}'
        self.kong_mock.request.get_raw_body.return_value = bad_body
        self.plugin.access(conf)
        self.kong_mock.response.exit.assert_called_once_with(403, 'Forbidden')

        # Test 2: Match in a different field should NOT block
        self.kong_mock.response.exit.reset_mock()
        ok_body = '{"comment": {"text": "nice post"}, "other": "DELETE FROM users;"}'
        self.kong_mock.request.get_raw_body.return_value = ok_body
        self.plugin.access(conf)
        self.kong_mock.response.exit.assert_not_called()

    def test_no_match(self):
        """
        Test Case 3: Allows a request to proceed if no patterns match.
        """
        conf = {
            **self.base_conf,
            'sources': [
                {'source_type': 'header', 'source_name': 'X-User-Input', 'patterns': ["<script>"]},
                {'source_type': 'body', 'source_name': 'comment.text', 'patterns': ["delete from"]}
            ]
        }
        # Arrange
        self.kong_mock.request.get_header.return_value = 'a normal header value'
        self.kong_mock.request.get_raw_body.return_value = '{"comment": {"text": "a normal comment"}}'

        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
