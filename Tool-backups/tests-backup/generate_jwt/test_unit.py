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

class GenerateJWTHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value(self, source_type, source_name):
        if source_type == 'shared_context':
            return self.kong.ctx['shared'].get(source_name)
        return "mock_value"

    def set_value(self, dest_type, dest_name, value):
        if dest_type == 'shared_context':
            self.kong.ctx['shared'][dest_name] = value

    def access(self, conf):
        key = None
        if conf['algorithm'].startswith("HS"):
            key = conf.get('secret_literal') or self.get_value('shared_context', conf.get('secret_source_name'))
        elif conf['algorithm'].startswith("RS") or conf['algorithm'].startswith("ES"):
            key = conf.get('private_key_literal') or self.get_value('shared_context', conf.get('private_key_source_name'))

        if not key:
            return self.kong.response.exit(500, "Missing key")

        res, err = self.kong.http.client.go(conf['jwt_generate_service_url'], unittest.mock.ANY)

        if not res or res.status != 200:
            if not conf.get('on_error_continue'):
                return self.kong.response.exit(500, "Service error")
            return

        jwt = json.loads(res.body).get('jwt')
        if jwt:
            self.set_value(conf['output_destination_type'], conf['output_destination_name'], jwt)

class TestGenerateJWTUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = GenerateJWTHandler(self.kong_mock)

    def test_on_error_continue_true(self):
        """
        Test Case 1: Request proceeds on failure if on_error_continue is true.
        """
        conf = {
            'jwt_generate_service_url': 'http://signer/sign',
            'algorithm': 'HS256', 'secret_literal': 's',
            'on_error_continue': True,
        }
        # Mock a failure from the external service
        self.kong_mock.http.client.go.return_value = (None, "Connection timeout")

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_not_called()

    def test_output_to_shared_context(self):
        """
        Test Case 2: Generated JWT is correctly placed into kong.ctx.shared.
        """
        conf = {
            'jwt_generate_service_url': 'http://signer/sign',
            'algorithm': 'HS256', 'secret_literal': 's',
            'output_destination_type': 'shared_context',
            'output_destination_name': 'my_jwt'
        }
        generated_jwt = "context.jwt.token"
        mock_response = Mock(status=200, body=json.dumps({'jwt': generated_jwt}))
        self.kong_mock.http.client.go.return_value = (mock_response, None)

        self.plugin.access(conf)

        self.assertIn('my_jwt', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['my_jwt'], generated_jwt)

    def test_key_sourcing_for_rs256(self):
        """
        Test Case 3: Correctly looks for a private_key for an RS256 algorithm.
        """
        conf = {
            'jwt_generate_service_url': 'http://signer/sign',
            'algorithm': 'RS256',
            # Correctly configured with private_key, not secret
            'private_key_source_type': 'shared_context',
            'private_key_source_name': 'my_rs_key',
            'output_destination_type': 'shared_context',
            'output_destination_name': 'my_jwt'
        }
        self.kong_mock.ctx['shared']['my_rs_key'] = '-----BEGIN PRIVATE KEY-----...'
        self.kong_mock.http.client.go.return_value = (Mock(status=200, body='{"jwt":"..."}'), None)

        self.plugin.access(conf)

        # The check here is that the plugin didn't exit due to a missing key
        self.kong_mock.response.exit.assert_not_called()
        self.kong_mock.http.client.go.assert_called_once()

if __name__ == '__main__':
    unittest.main()
