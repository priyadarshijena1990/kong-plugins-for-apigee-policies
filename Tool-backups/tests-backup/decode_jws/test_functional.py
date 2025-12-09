import unittest
from unittest.mock import Mock, patch
import json

# Mocking the Kong environment
class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()
        # This is the mock for the external http client
        self.http = Mock()

    def reset(self):
        self.log.reset_mock()
        self.response.reset_mock()
        self.ctx['shared'].clear()
        self.request.reset_mock()
        self.http.reset_mock()

# Python representation of the Lua plugin for testing
class DecodeJWSHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_source(self, source_type, source_name):
        # Simplified for testing
        if source_type == "header":
            return self.kong.request.get_header(source_name)
        return None

    def access(self, conf):
        jws_string = self.get_value_from_source(conf['jws_source_type'], conf['jws_source_name'])
        if not jws_string:
            if not conf.get('on_error_continue', False):
                return self.kong.response.exit(conf.get('on_error_status', 500), conf.get('on_error_body', '...'))
            return

        public_key_string = conf.get('public_key_literal') # Simplified for test

        # Simulate the external call
        res, err = self.kong.http.client.go(conf['jws_decode_service_url'], unittest.mock.ANY)

        if not res or res.status != 200:
            if not conf.get('on_error_continue', False):
                return self.kong.response.exit(conf.get('on_error_status', 500), conf.get('on_error_body', '...'))
            return
        
        service_response = json.loads(res.body)
        payload_claims = service_response.get('payload')

        if not payload_claims:
            return

        for claim_mapping in conf.get('claims_to_extract', []):
            if claim_mapping['claim_name'] in payload_claims:
                self.kong.ctx['shared'][claim_mapping['output_key']] = payload_claims[claim_mapping['claim_name']]


class TestDecodeJWSFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = DecodeJWSHandler(self.kong_mock)

    def test_successful_decode_and_extraction(self):
        """
        Test Case 1: Successful call to external service and claim extraction.
        """
        conf = {
            'jws_decode_service_url': 'http://mock-service/decode',
            'jws_source_type': 'header',
            'jws_source_name': 'X-JWS-Token',
            'public_key_literal': 'test-key',
            'claims_to_extract': [
                {'claim_name': 'sub', 'output_key': 'user_id'},
                {'claim_name': 'iss', 'output_key': 'issuer'}
            ]
        }
        self.kong_mock.request.get_header.return_value = 'dummy.jws.token'

        # Mock the external service response
        mock_response = Mock()
        mock_response.status = 200
        mock_response.body = json.dumps({'payload': {'sub': '12345', 'iss': 'test-issuer'}})
        self.kong_mock.http.client.go.return_value = (mock_response, None)

        self.plugin.access(conf)

        # Assert claims were extracted
        self.assertEqual(self.kong_mock.ctx['shared'].get('user_id'), '12345')
        self.assertEqual(self.kong_mock.ctx['shared'].get('issuer'), 'test-issuer')
        self.kong_mock.response.exit.assert_not_called()

    def test_external_service_error(self):
        """
        Test Case 2: External service returns a non-200 status.
        """
        conf = {
            'jws_decode_service_url': 'http://mock-service/decode',
            'jws_source_type': 'header',
            'jws_source_name': 'X-JWS-Token',
            'public_key_literal': 'test-key',
            'on_error_status': 401,
            'on_error_body': 'Unauthorized'
        }
        self.kong_mock.request.get_header.return_value = 'dummy.jws.token'

        # Mock the external service response
        mock_response = Mock()
        mock_response.status = 500
        mock_response.body = 'Internal Server Error'
        self.kong_mock.http.client.go.return_value = (mock_response, None)

        self.plugin.access(conf)

        # Assert plugin exited with the configured error
        self.kong_mock.response.exit.assert_called_once_with(401, 'Unauthorized')

    def test_jws_not_found(self):
        """
        Test Case 3: JWS token is not found in the specified source.
        """
        conf = {
            'jws_decode_service_url': 'http://mock-service/decode',
            'jws_source_type': 'header',
            'jws_source_name': 'X-JWS-Token',
            'on_error_status': 400,
            'on_error_body': 'Missing JWS Token'
        }
        # JWS header is missing
        self.kong_mock.request.get_header.return_value = None

        self.plugin.access(conf)

        # Assert plugin exited with the configured error
        self.kong_mock.response.exit.assert_called_once_with(400, 'Missing JWS Token')
        # The external service should not have been called
        self.kong_mock.http.client.go.assert_not_called()

if __name__ == '__main__':
    unittest.main()
