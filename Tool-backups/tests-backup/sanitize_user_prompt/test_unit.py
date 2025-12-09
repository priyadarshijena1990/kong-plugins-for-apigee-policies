import unittest
from unittest.mock import Mock
import json
import re

# Reusing the Python implementation from the functional tests
from tests.sanitize_user_prompt.test_functional import SanitizeUserPromptHandler, KongMock

class TestSanitizeUserPromptUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = SanitizeUserPromptHandler(self.kong_mock)
        self.base_conf = {
            'block_status': 400,
            'block_body': 'Input blocked.'
        }

    def test_source_body_to_shared_context(self):
        """
        Test Case 1: Extracts prompt from JSON body (JSONPath) and puts into shared context.
        """
        conf = {
            **self.base_conf,
            'source_type': 'body',
            'source_name': 'request.prompt',
            'destination_type': 'shared_context',
            'destination_name': 'sanitized_prompt',
            'trim_whitespace': True
        }
        # Arrange: Mock the request body
        request_body = '{"request": {"prompt": "  my prompt "}}'
        self.kong_mock.request.get_raw_body.return_value = request_body
        
        # Act
        self.plugin.access(conf)

        # Assert
        self.assertIn('sanitized_prompt', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['sanitized_prompt'], 'my prompt')
        self.kong_mock.response.exit.assert_not_called()

    def test_no_user_prompt_found(self):
        """
        Test Case 2: Plugin proceeds if no user prompt is found from the source.
        """
        conf = {
            **self.base_conf,
            'source_type': 'header',
            'source_name': 'X-Non-Existent-Prompt',
            'destination_type': 'header',
            'destination_name': 'X-Sanitized-Prompt'
        }
        # Arrange: Mock the header to return None
        self.kong_mock.request.get_header.return_value = None

        # Act
        self.plugin.access(conf)

        # Assert: No error, no blocking, nothing set
        self.kong_mock.response.exit.assert_not_called()
        self.kong_mock.request.set_header.assert_not_called()
        self.assertEqual(len(self.kong_mock.ctx['shared']), 0) # Shared context should be empty

    def test_trim_whitespace_false(self):
        """
        Test Case 3: Leading/trailing whitespace is preserved when trim_whitespace is false.
        """
        conf = {
            **self.base_conf,
            'trim_whitespace': False, # Key for this test
            'source_type': 'header',
            'source_name': 'X-User-Prompt',
            'destination_type': 'shared_context',
            'destination_name': 'raw_prompt'
        }
        # Arrange
        original_prompt = "  My Prompt  "
        self.kong_mock.request.get_header.return_value = original_prompt

        # Act
        self.plugin.access(conf)

        # Assert
        self.assertEqual(self.kong_mock.ctx['shared']['raw_prompt'], original_prompt)
        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
