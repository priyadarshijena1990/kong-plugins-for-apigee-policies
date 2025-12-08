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
        callout_opts = {'method': conf.get('method', 'POST')}
        res, err = self.kong.http.client.go(conf['callout_url'], callout_opts)

        if conf.get('wait_for_response', True):
            callout_succeeded = True
            if not res or res.status >= 400:
                callout_succeeded = False

            if conf.get('response_to_shared_context_key'):
                self.kong.ctx['shared'][conf['response_to_shared_context_key']] = {
                    'status': res.status if res else 0,
                    'body': res.body if res else err,
                }
            
            if not callout_succeeded and not conf.get('on_error_continue', False):
                return self.kong.response.exit(conf.get('on_error_status', 500), conf.get('on_error_body', '...'))

class TestExternalCalloutFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = ExternalCalloutHandler(self.kong_mock)

    def test_sync_call_success(self):
        """
        Test Case 1: Successful synchronous call stores response in context.
        """
        conf = {
            'callout_url': 'http://example.com/api',
            'wait_for_response': True,
            'response_to_shared_context_key': 'callout_response'
        }
        
        mock_response = Mock()
        mock_response.status = 200
        mock_response.body = '{"data": "success"}'
        self.kong_mock.http.client.go.return_value = (mock_response, None)

        self.plugin.access(conf)

        self.assertIn('callout_response', self.kong_mock.ctx['shared'])
        response_data = self.kong_mock.ctx['shared']['callout_response']
        self.assertEqual(response_data['status'], 200)
        self.assertEqual(response_data['body'], '{"data": "success"}')
        self.kong_mock.response.exit.assert_not_called()

    def test_sync_call_failure(self):
        """
        Test Case 2: Failed synchronous call terminates the request.
        """
        conf = {
            'callout_url': 'http://example.com/api',
            'wait_for_response': True,
            'on_error_continue': False,
            'on_error_status': 503,
            'on_error_body': 'Service Unavailable'
        }
        
        mock_response = Mock()
        mock_response.status = 500
        mock_response.body = 'External service error'
        self.kong_mock.http.client.go.return_value = (mock_response, None)

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(503, 'Service Unavailable')

    def test_async_fire_and_forget(self):
        """
        Test Case 3: Asynchronous call does not wait or terminate on failure.
        """
        conf = {
            'callout_url': 'http://example.com/log',
            'wait_for_response': False # Fire-and-forget
        }

        # Simulate a complete failure of the HTTP client
        self.kong_mock.http.client.go.return_value = (None, "Connection timed out")

        self.plugin.access(conf)

        # The external call was made
        self.kong_mock.http.client.go.assert_called_once()
        # But the plugin did not wait and did not terminate the request
        self.kong_mock.response.exit.assert_not_called()
        # And nothing was stored in the context
        self.assertEqual(len(self.kong_mock.ctx['shared']), 0)

if __name__ == '__main__':
    unittest.main()
