import unittest
from unittest.mock import Mock, ANY

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.request = Mock()
        self.http = Mock()

class ResetQuotaHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_source(self, source_type, source_name):
        if source_type == 'query':
            return self.kong.request.get_query_arg(source_name)
        return None

    def access(self, conf):
        scope_id = None
        if conf.get('scope_type'):
            scope_id = self.get_value_from_source(conf['scope_id_source_type'], conf['scope_id_source_name'])
            if not scope_id:
                return self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])

        url = f"{conf['admin_api_url']}/plugins/{conf['rate_limiting_plugin_id']}/rate-limit"
        if scope_id:
            url += f"/{scope_id}/reset"
        else:
            url += "/reset"
            
        headers = {}
        if conf.get('admin_api_key'):
            headers['apikey'] = conf['admin_api_key']

        res, err = self.kong.http.client.go(url, {'method': 'DELETE', 'headers': headers, 'timeout': ANY, 'connect_timeout': ANY, 'ssl_verify': ANY})

        if not res or res.status != 204:
            if not conf.get('on_error_continue', False):
                return self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])

class TestResetQuotaFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = ResetQuotaHandler(self.kong_mock)
        self.base_conf = {
            'admin_api_url': 'http://localhost:8001',
            'rate_limiting_plugin_id': 'abc-123-def-456',
            'on_error_status': 500,
            'on_error_body': 'Reset failed'
        }

    def test_global_reset(self):
        """
        Test Case 1: Calls the correct global reset URL.
        """
        conf = {**self.base_conf, 'admin_api_key': 'my-key'}
        self.kong_mock.http.client.go.return_value = (Mock(status=204), None)

        self.plugin.access(conf)

        expected_url = 'http://localhost:8001/plugins/abc-123-def-456/rate-limit/reset'
        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        self.assertEqual(call_args[0], expected_url)
        self.assertEqual(call_args[1]['headers']['apikey'], 'my-key')
        self.assertEqual(call_args[1]['method'], 'DELETE')
        self.kong_mock.response.exit.assert_not_called()

    def test_scoped_reset(self):
        """
        Test Case 2: Calls the correct scoped reset URL.
        """
        conf = {
            **self.base_conf,
            'scope_type': 'consumer',
            'scope_id_source_type': 'query',
            'scope_id_source_name': 'consumer_id'
        }
        self.kong_mock.request.get_query_arg.return_value = 'user-xyz'
        self.kong_mock.http.client.go.return_value = (Mock(status=204), None)
        
        self.plugin.access(conf)

        expected_url = 'http://localhost:8001/plugins/abc-123-def-456/rate-limit/user-xyz/reset'
        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        self.assertEqual(call_args[0], expected_url)

    def test_admin_api_failure(self):
        """
        Test Case 3: Terminates the request if the Admin API call fails.
        """
        conf = {**self.base_conf}
        # Simulate the admin API returning a 500 error
        self.kong_mock.http.client.go.return_value = (Mock(status=500, body='Internal Server Error'), None)

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(500, 'Reset failed')

if __name__ == '__main__':
    unittest.main()
