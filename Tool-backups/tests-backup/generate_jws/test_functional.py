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

    def reset(self):
        # This method is used to reset mocks between tests
        for attr in self.__dict__.values():
            if hasattr(attr, 'reset_mock'):
                attr.reset_mock()
        self.ctx['shared'].clear()

class GenerateJWSHandler:
    # This is a simplified Python representation of the Lua plugin's logic for testing purposes.
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_source(self, source_type, source_name):
        if source_type == 'shared_context':
            return self.kong.ctx['shared'].get(source_name)
        return "mock_payload" # Default for simplicity

    def set_value_to_destination(self, destination_type, destination_name, value):
        if destination_type == 'header':
            self.kong.request.set_header(destination_name, value)
        # Other destination types would be implemented here

    def access(self, conf):
        payload = self.get_value_from_source(conf['payload_source_type'], conf.get('payload_source_name'))
        if not payload:
            if not conf.get('on_error_continue'):
                return self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])
            return

        res, err = self.kong.http.client.go(conf['jws_generate_service_url'], unittest.mock.ANY)

        if not res or res.status != 200:
            if not conf.get('on_error_continue'):
                return self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])
            return

        service_response = json.loads(res.body)
        jws = service_response.get('jws')

        if jws:
            self.set_value_to_destination(conf['output_destination_type'], conf['output_destination_name'], jws)


class TestGenerateJWSFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = GenerateJWSHandler(self.kong_mock)

    def test_successful_jws_generation(self):
        """
        Test Case 1: Successful call to external service places JWS in the output destination.
        """
        conf = {
            'jws_generate_service_url': 'http://mock-service/generate',
            'payload_source_type': 'literal',
            'payload_source_name': 'my-payload',
            'private_key_literal': 'my-key',
            'algorithm': 'HS256',
            'output_destination_type': 'header',
            'output_destination_name': 'X-Generated-JWS'
        }
        # Mock the external service response
        generated_jws = "header.payload.signature"
        mock_response = Mock(status=200, body=json.dumps({'jws': generated_jws}))
        self.kong_mock.http.client.go.return_value = (mock_response, None)

        self.plugin.access(conf)

        # Assert that the JWS was placed in the correct header
        self.kong_mock.request.set_header.assert_called_once_with('X-Generated-JWS', generated_jws)
        self.kong_mock.response.exit.assert_not_called()

    def test_external_service_error(self):
        """
        Test Case 2: External service returns a non-200 status, terminating the request.
        """
        conf = {
            'jws_generate_service_url': 'http://mock-service/generate',
            'payload_source_type': 'literal',
            'on_error_status': 503,
            'on_error_body': 'JWS service unavailable'
        }
        # Mock the external service failure
        self.kong_mock.http.client.go.return_value = (Mock(status=500, body='Error'), None)

        self.plugin.access(conf)

        # Assert that the plugin terminated the request with the configured error
        self.kong_mock.response.exit.assert_called_once_with(503, 'JWS service unavailable')
        self.kong_mock.request.set_header.assert_not_called()

    def test_missing_payload(self):
        """
        Test Case 3: Plugin handles a missing payload without calling the external service.
        """
        conf = {
            'jws_generate_service_url': 'http://mock-service/generate',
            'payload_source_type': 'shared_context',
            'payload_source_name': 'non_existent_key',
            'on_error_status': 400,
            'on_error_body': 'Missing payload'
        }
        # Arrange: The key is missing from the shared context
        
        self.plugin.access(conf)
        
        # Assert that the plugin terminated the request
        self.kong_mock.response.exit.assert_called_once_with(400, 'Missing payload')
        # Assert that the external service was never called
        self.kong_mock.http.client.go.assert_not_called()

if __name__ == '__main__':
    unittest.main()
