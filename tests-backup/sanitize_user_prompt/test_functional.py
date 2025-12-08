import unittest
from unittest.mock import Mock
import re
import json

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.request = Mock()
        self.ctx = {'shared': {}}

class SanitizeUserPromptHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock
        self.html_tags_pattern = re.compile("<.*?>")

    def get_value_from_source(self, conf):
        if conf['source_type'] == 'header':
            return self.kong.request.get_header(conf['source_name'])
        elif conf['source_type'] == 'query':
            return self.kong.request.get_query_arg(conf['source_name'])
        elif conf['source_type'] == 'body':
            body_str = self.kong.request.get_raw_body()
            if not body_str: return None
            try:
                parsed_body = json.loads(body_str)
                # Simplified dot notation for testing
                keys = conf['source_name'].split('.')
                val = parsed_body
                for key in keys:
                    val = val.get(key)
                return val
            except json.JSONDecodeError:
                return None
        return None

    def set_sanitized_prompt(self, conf, sanitized_prompt):
        if conf['destination_type'] == 'header':
            self.kong.request.set_header(conf['destination_name'], sanitized_prompt)
        elif conf['destination_type'] == 'query':
            self.kong.request.set_query_arg(conf['destination_name'], sanitized_prompt)
        elif conf['destination_type'] == 'body':
            # This is simplified. In Lua, it reads, modifies, and sets.
            # Here, we'll just set it for simplicity.
            self.kong.request.set_body(json.dumps({conf['destination_name']: sanitized_prompt}))
        elif conf['destination_type'] == 'shared_context':
            self.kong.ctx['shared'][conf['destination_name']] = sanitized_prompt
        

    def access(self, conf):
        user_prompt = self.get_value_from_source(conf)
        if not user_prompt: return
        
        user_prompt = str(user_prompt)

        sanitized_prompt = user_prompt

        if conf.get('trim_whitespace', True):
            sanitized_prompt = sanitized_prompt.strip()

        if conf.get('remove_html_tags'):
            sanitized_prompt = self.html_tags_pattern.sub("", sanitized_prompt)

        for rep in conf.get('replacements', []):
            sanitized_prompt = re.sub(rep['pattern'], rep['replacement'], sanitized_prompt)

        for block_pattern in conf.get('block_on_match', []):
            if re.search(block_pattern, sanitized_prompt):
                return self.kong.response.exit(conf['block_status'], conf['block_body'])
        
        if conf.get('max_length') and len(sanitized_prompt) > conf['max_length']:
            sanitized_prompt = sanitized_prompt[:conf['max_length']]

        self.set_sanitized_prompt(conf, sanitized_prompt)


class TestSanitizeUserPromptFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = SanitizeUserPromptHandler(self.kong_mock)
        self.base_conf = {
            'source_type': 'header',
            'source_name': 'X-User-Prompt',
            'destination_type': 'header',
            'destination_name': 'X-Sanitized-Prompt',
            'block_status': 400,
            'block_body': 'Input blocked.'
        }

    def test_trim_remove_html_and_replace(self):
        """
        Test Case 1: Applies trim, HTML removal, and regex replacement.
        """
        conf = {
            **self.base_conf,
            'trim_whitespace': True,
            'remove_html_tags': True,
            'replacements': [
                {'pattern': 'badword', 'replacement': 'goodword'}
            ]
        }
        # Arrange
        original_prompt = "  <script>alert(1)</script> Hello badword World!  "
        self.kong_mock.request.get_header.return_value = "  <script>alert(1)</script> Hello badword World!  "
        
        # Expected: "Hello goodword World!"
        expected_sanitized = "Hello goodword World!"

        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.request.set_header.assert_called_once_with('X-Sanitized-Prompt', expected_sanitized)
        self.kong_mock.response.exit.assert_not_called()

    def test_block_on_malicious_pattern(self):
        """
        Test Case 2: Blocks request if a malicious pattern is found.
        """
        conf = {
            **self.base_conf,
            'block_on_match': ['SELECT .* FROM'] # Simple SQL injection pattern
        }
        # Arrange
        malicious_prompt = "What is SELECT * FROM users;"
        self.kong_mock.request.get_header.return_value = malicious_prompt

        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.response.exit.assert_called_once_with(400, 'Input blocked.')

    def test_truncate_length(self):
        """
        Test Case 3: Truncates the prompt if it exceeds max_length.
        """
        conf = {
            **self.base_conf,
            'max_length': 10
        }
        # Arrange
        long_prompt = "This is a very long prompt that should be truncated."
        self.kong_mock.request.get_header.return_value = long_prompt

        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.request.set_header.assert_called_once_with('X-Sanitized-Prompt', 'This is a ')
        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
