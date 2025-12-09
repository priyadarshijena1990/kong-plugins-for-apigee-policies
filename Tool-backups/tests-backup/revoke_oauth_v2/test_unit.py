import unittest
from unittest.mock import Mock
from urllib.parse import parse_qs, urlencode

# Reusing the Python implementation from the functional tests
from tests.revoke_oauth_v2.test_functional import RevokeOAuthV2Handler, KongMock

class TestRevokeOAuthV2Unit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = RevokeOAuthV2Handler(self.kong_mock)
        self.base_conf = {
            'revocation_endpoint': 'https://auth.example.com/revoke',
            'client_id': 'test-client',
            'on_success_status': 200, 'on_success_body': 'Revoked.',
            'on_error_status': 500, 'on_error_body': 'Failed.'
        }
        # Default successful call
        self.kong_mock.http.client.go.return_value = (Mock(status=200), None)

    def test_missing_token(self):
        """
        Test Case 1: Terminates request if the token is not found in the source.
        """
        conf = {
            **self.base_conf,
            'token_source_type': 'query',
            'token_source_name': 'token_to_revoke'
        }
        # Arrange: mock the source to return None
        self.kong_mock.request.get_query_arg.return_value = None

        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.http.client.go.assert_not_called()
        self.kong_mock.response.exit.assert_called_once_with(400, "Missing token")

    def test_token_type_hint(self):
        """
        Test Case 2: Correctly includes the token_type_hint in the request body.
        """
        # The Python mock needs to be adapted to include the hint
        class PluginWithHint(RevokeOAuthV2Handler):
             def access(self, conf):
                token = self.get_token_from_source(conf)
                form_params = {'token': token}
                if conf.get('token_type_hint'):
                    form_params['token_type_hint'] = conf['token_type_hint']
                
                body = self.kong.util.encode_urlencoded(form_params)
                self.kong.http.client.go(conf['revocation_endpoint'], {'body': body})

        plugin = PluginWithHint(self.kong_mock)
        
        conf = {
            **self.base_conf,
            'token_source_type': 'query',
            'token_source_name': 'token',
            'token_type_hint': 'refresh_token'
        }
        self.kong_mock.request.get_query_arg.return_value = 'my-refresh-token'

        # Act
        plugin.access(conf)

        # Assert
        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        sent_body = parse_qs(call_args[1]['body'])
        self.assertEqual(sent_body['token'][0], 'my-refresh-token')
        self.assertEqual(sent_body['token_type_hint'][0], 'refresh_token')


if __name__ == '__main__':
    unittest.main()
