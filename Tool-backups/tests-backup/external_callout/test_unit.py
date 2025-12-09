import unittest
from unittest.mock import Mock, patch
import json

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()
        self.http = Mock()

class ExternalCalloutHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        body = None
        if conf.get('request_body_source_type') == 'shared_context':
            body = self.kong.ctx['shared'].get(conf.get('request_body_source_name'))
            if isinstance(body, dict): # Emulate JSON encoding
                body = json.dumps(body)
        elif conf.get('request_body_source_type') == 'request_body':
            body = self.kong.request.get_raw_body()

        callout_opts = {'method': conf.get('method', 'POST'), 'body': body}
        res, err = self.kong.http.client.go(conf['callout_url'], callout_opts)

        if conf.get('wait_for_response', True):
            if (not res or res.status >= 400) and not conf.get('on_error_continue', False):
                return self.kong.response.exit(500, "Error")

class TestExternalCalloutUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = ExternalCalloutHandler(self.kong_mock)

    def test_body_from_shared_context(self):
        """
        Test Case 1: Correctly uses request body from kong.ctx.shared.
        """
        conf = {
            'callout_url': 'http://example.com/api',
            'request_body_source_type': 'shared_context',
            'request_body_source_name': 'my_callout_body'
        }
        # Arrange: Set the body in the shared context
        self.kong_mock.ctx['shared']['my_callout_body'] = {"key": "value"}
        self.kong_mock.http.client.go.return_value = (Mock(status=200), None)

        self.plugin.access(conf)

        # Assert: Check that kong.http.client.go was called with the correct body
        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        sent_opts = call_args[1]
        self.assertEqual(sent_opts['body'], '{"key": "value"}')

    def test_sync_call_failure_with_continue_on_error(self):
        """
        Test Case 2: Request proceeds on sync call failure if on_error_continue is true.
        """
        conf = {
            'callout_url': 'http://example.com/api',
            'wait_for_response': True,
            'on_error_continue': True # Key for this test
        }
        
        # Arrange: Simulate a failed call
        self.kong_mock.http.client.go.return_value = (Mock(status=500), None)

        self.plugin.access(conf)

        # Assert: The request was not terminated
        self.kong_mock.response.exit.assert_not_called()

    def test_body_from_original_request(self):
        """
        Test Case 3: Correctly uses the body from the original client request.
        """
        conf = {
            'callout_url': 'http://example.com/api',
            'request_body_source_type': 'request_body'
        }
        # Arrange: Set the mock original request body
        original_body = '{"original": "request"}'
        self.kong_mock.request.get_raw_body.return_value = original_body
        self.kong_mock.http.client.go.return_value = (Mock(status=200), None)

        self.plugin.access(conf)

        # Assert: The callout was made with the original request body
        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        sent_opts = call_args[1]
        self.assertEqual(sent_opts['body'], original_body)


if __name__ == '__main__':
    unittest.main()
