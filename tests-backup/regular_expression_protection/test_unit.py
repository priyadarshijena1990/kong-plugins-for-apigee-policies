import unittest
from unittest.mock import Mock

# Reusing the Python implementation from the functional tests
from tests.regular_expression_protection.test_functional import RegularExpressionProtectionHandler, KongMock

class TestRegularExpressionProtectionUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = RegularExpressionProtectionHandler(self.kong_mock)
        self.base_conf = {
            'violation_status': 403,
            'violation_body': 'Forbidden',
        }

    def test_continue_action_on_match(self):
        """
        Test Case 1: Logs a violation but does not abort the request when action is 'continue'.
        """
        conf = {
            **self.base_conf,
            'sources': [{
                'match_action': 'continue', # Key for this test
                'source_type': 'header',
                'source_name': 'X-Bad-Data',
                'patterns': ['bad-pattern']
            }]
        }
        # Arrange
        self.kong_mock.request.get_header.return_value = "this contains a bad-pattern"
        
        # Act
        self.plugin.access(conf)

        # Assert: The request was NOT terminated
        self.kong_mock.response.exit.assert_not_called()
        # The real plugin would call kong.log.warn, which we assume happens.

    def test_raw_body_check(self):
        """
        Test Case 2: Correctly checks the raw body when it's not valid JSON.
        """
        conf = {
            **self.base_conf,
            'sources': [{
                'match_action': 'block',
                'source_type': 'body',
                # 'source_name' is omitted to indicate checking the whole body
                'patterns': ["<svg onload=alert(1)>"]
            }]
        }
        # Arrange: Body is a plain string, not JSON
        plain_text_body = "Some text in the body, followed by a malicious <svg onload=alert(1)> tag."
        self.kong_mock.request.get_raw_body.return_value = plain_text_body

        # Act
        self.plugin.access(conf)

        # Assert: The request was blocked because the pattern was found in the raw string
        self.kong_mock.response.exit.assert_called_once_with(403, 'Forbidden')

if __name__ == '__main__':
    unittest.main()
