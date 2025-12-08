import unittest
from unittest.mock import Mock, ANY
import base64
from urllib.parse import parse_qs, urlencode

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.request = Mock()
        self.http = Mock()
        self.util = Mock() # Mock for kong.tools.utils

class RevokeOAuthV2Handler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock
        # In Python, we can get this behavior from standard libraries
        self.kong.util.encode_urlencoded = urlencode

    def get_token_from_source(self, conf):
        if conf['token_source_type'] == 'query':
            return self.kong.request.get_query_arg(conf['token_source_name'])
        return None

    def access(self, conf):
        token = self.get_token_from_source(conf)
        if not token:
            return self.kong.response.exit(400, "Missing token")
        
        form_params = {'token': token}
        headers = {"Content-Type": "application/x-www-form-urlencoded"}

        if conf.get('client_id') and conf.get('client_secret'):
            auth_str = f"{conf['client_id']}:{conf['client_secret']}"
            b64_auth = base64.b64encode(auth_str.encode('utf-8')).decode('utf-8')
            headers['Authorization'] = f"Basic {b64_auth}"
        elif conf.get('client_id'):
            form_params['client_id'] = conf.get('client_id')
        
        body = self.kong.util.encode_urlencoded(form_params)
        res, err = self.kong.http.client.go(conf['revocation_endpoint'], {'body': body, 'headers': headers})

        if res and res.status < 300:
            return self.kong.response.exit(conf['on_success_status'], conf['on_success_body'])
        else:
            return self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])


class TestRevokeOAuthV2Functional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = RevokeOAuthV2Handler(self.kong_mock)
        self.base_conf = {
            'revocation_endpoint': 'https://auth.example.com/revoke',
            'token_source_type': 'query',
            'token_source_name': 'token_to_revoke',
            'on_success_status': 200, 'on_success_body': 'Revoked.',
            'on_error_status': 500, 'on_error_body': 'Failed.'
        }
        self.kong_mock.request.get_query_arg.return_value = 'test-access-token'
        self.kong_mock.http.client.go.return_value = (Mock(status=200), None)

    def test_revocation_with_basic_auth(self):
        """
        Test Case 1: Sends client credentials via Basic Authentication header.
        """
        conf = {
            **self.base_conf,
            'client_id': 'my-client',
            'client_secret': 'my-secret'
        }
        
        self.plugin.access(conf)

        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        sent_opts = call_args[1]
        
        # Assert Authorization header is correct
        expected_b64 = base64.b64encode(b'my-client:my-secret').decode('utf-8')
        self.assertEqual(sent_opts['headers']['Authorization'], f"Basic {expected_b64}")
        
        # Assert body only contains the token
        sent_body = parse_qs(sent_opts['body'])
        self.assertEqual(sent_body['token'][0], 'test-access-token')
        self.assertNotIn('client_id', sent_body)

    def test_revocation_with_client_id_in_body(self):
        """
        Test Case 2: Sends client_id in the form body when no secret is provided.
        """
        conf = {
            **self.base_conf,
            'client_id': 'my-public-client',
            # No client_secret
        }

        self.plugin.access(conf)

        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        sent_opts = call_args[1]
        
        # Assert NO Authorization header is sent
        self.assertNotIn('Authorization', sent_opts['headers'])

        # Assert body contains both token and client_id
        sent_body = parse_qs(sent_opts['body'])
        self.assertEqual(sent_body['token'][0], 'test-access-token')
        self.assertEqual(sent_body['client_id'][0], 'my-public-client')

    def test_revocation_endpoint_failure(self):
        """
        Test Case 3: Plugin exits with error if the endpoint fails.
        """
        conf = {**self.base_conf, 'client_id': 'c'}
        # Arrange: mock a failure from the revocation server
        self.kong_mock.http.client.go.return_value = (Mock(status=400, body='invalid_token'), None)

        self.plugin.access(conf)

        self.kong_mock.http.client.go.assert_called_once()
        self.kong_mock.response.exit.assert_called_once_with(500, 'Failed.')


if __name__ == '__main__':
    unittest.main()
