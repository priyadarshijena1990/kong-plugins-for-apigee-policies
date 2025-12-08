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

class GenerateJWSHandler:
    # Simplified Python representation of the plugin's logic for testing.
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_source(self, source_type, source_name):
        if source_type == 'shared_context':
            return self.kong.ctx['shared'].get(source_name)
        return "mock_payload"

    def set_value_to_destination(self, destination_type, destination_name, value):
        if destination_type == 'shared_context':
            self.kong.ctx['shared'][destination_name] = value

    def access(self, conf):
        private_key = conf.get('private_key_literal') or self.get_value_from_source('shared_context', conf.get('private_key_source_name'))

        # Simplified body construction for testing the private key source
        request_body = {'private_key': private_key, 'payload': '...'}
        
        res, err = self.kong.http.client.go(conf['jws_generate_service_url'], {'body': json.dumps(request_body)})

        if not res or res.status != 200:
            if not conf.get('on_error_continue'):
                return self.kong.response.exit(500, "Error")
            return
        
        jws = json.loads(res.body).get('jws')
        if jws:
            self.set_value_to_destination(conf['output_destination_type'], conf['output_destination_name'], jws)


class TestGenerateJWSUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = GenerateJWSHandler(self.kong_mock)

    def test_on_error_continue_true(self):
        """
        Test Case 1: Request proceeds on failure if on_error_continue is true.
        """
        conf = {
            'jws_generate_service_url': 'http://mock-service/generate',
            'payload_source_type': 'literal',
            'on_error_continue': True,
        }
        # Mock a failure from the external service
        self.kong_mock.http.client.go.return_value = (None, "Service connection failed")

        self.plugin.access(conf)

        # Assert that the plugin did not terminate the request
        self.kong_mock.response.exit.assert_not_called()

    def test_output_to_shared_context(self):
        """
        Test Case 2: Generated JWS is correctly placed into kong.ctx.shared.
        """
        conf = {
            'jws_generate_service_url': 'http://mock-service/generate',
            'payload_source_type': 'literal',
            'output_destination_type': 'shared_context',
            'output_destination_name': 'my_generated_jws'
        }
        generated_jws = "header.payload.signature_from_context_test"
        mock_response = Mock(status=200, body=json.dumps({'jws': generated_jws}))
        self.kong_mock.http.client.go.return_value = (mock_response, None)

        self.plugin.access(conf)

        # Assert that the JWS was stored in the shared context
        self.assertIn('my_generated_jws', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['my_generated_jws'], generated_jws)

    def test_private_key_from_shared_context(self):
        """
        Test Case 3: Private key is correctly sourced from kong.ctx.shared.
        """
        conf = {
            'jws_generate_service_url': 'http://mock-service/generate',
            'payload_source_type': 'literal',
            'private_key_source_type': 'shared_context',
            'private_key_source_name': 'my_secret_key',
            'output_destination_type': 'shared_context',
            'output_destination_name': 'my_generated_jws'
        }
        # Arrange: Place the key in the context
        self.kong_mock.ctx['shared']['my_secret_key'] = 'key-from-context'
        self.kong_mock.http.client.go.return_value = (Mock(status=200, body='{"jws":"..."}'), None)

        self.plugin.access(conf)

        # Assert that the service was called
        self.kong_mock.http.client.go.assert_called_once()
        # Inspect the 'body' argument sent to the mocked http client
        call_args = self.kong_mock.http.client.go.call_args[0]
        sent_body = json.loads(call_args[1]['body'])
        
        self.assertEqual(sent_body['private_key'], 'key-from-context')


if __name__ == '__main__':
    unittest.main()
