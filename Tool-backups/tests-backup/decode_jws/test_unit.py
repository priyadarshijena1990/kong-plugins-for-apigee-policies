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
        self.http = Mock()

    def reset(self):
        self.log.reset_mock()
        self.response.reset_mock()
        self.ctx['shared'].clear()
        self.request.reset_mock()
        self.http.reset_mock()

# Python representation of the Lua plugin
class DecodeJWSHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_source(self, source_type, source_name):
        if source_type == "header":
            return self.kong.request.get_header(source_name)
        elif source_type == "shared_context":
            return self.kong.ctx['shared'].get(source_name)
        elif source_type == "body":
            raw_body = self.kong.request.get_raw_body()
            if raw_body:
                try:
                    body = json.loads(raw_body)
                    # Simplified dot notation for testing
                    return body.get(source_name)
                except (json.JSONDecodeError, AttributeError):
                    return None
        return None

    def get_public_key(self, conf):
        if conf.get('public_key_source_type') == 'literal':
            return conf.get('public_key_literal')
        elif conf.get('public_key_source_type') == 'shared_context':
            return self.kong.ctx['shared'].get(conf.get('public_key_source_name'))
        return None
    def get_public_key(self, conf):
        return conf.get('public_key_literal') or self.get_value_from_source(conf.get('public_key_source_type'), conf.get('public_key_source_name'))
        
    def access(self, conf):
        jws_string = self.get_value_from_source(conf['jws_source_type'], conf['jws_source_name'])
        public_key = self.get_public_key(conf)

        if not jws_string or not public_key:
            if not conf.get('on_error_continue', False):
                self.kong.response.exit(500, "Error")
            return

        res, err = self.kong.http.client.go(conf['jws_decode_service_url'], unittest.mock.ANY)

        if err or not res or res.status != 200:
            if not conf.get('on_error_continue', False):
                self.kong.response.exit(500, "Error")
            return

class TestDecodeJWSUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = DecodeJWSHandler(self.kong_mock)

    def test_on_error_continue(self):
        """
        Test Case 1: With on_error_continue=true, request proceeds even on failure.
        """
        conf = {
            'jws_decode_service_url': 'http://mock-service/decode',
            'jws_source_type': 'header',
            'jws_source_name': 'X-JWS-Token',
            'public_key_literal': 'test-key',
            'on_error_continue': True # Key for this test
        }
        self.kong_mock.request.get_header.return_value = 'dummy.jws.token'

        # Mock a failure from the external service
        self.kong_mock.http.client.go.return_value = (None, "Connection error")

        self.plugin.access(conf)

        # Assert that exit was NOT called
        self.kong_mock.response.exit.assert_not_called()

    def test_public_key_from_context(self):
        """
        Test Case 2: Public key is correctly sourced from kong.ctx.shared.
        """
        conf = {
            'jws_decode_service_url': 'http://mock-service/decode',
            'jws_source_type': 'header',
            'jws_source_name': 'X-JWS-Token',
            'public_key_source_type': 'shared_context',
            'public_key_source_name': 'my_public_key'
        }
        self.kong_mock.request.get_header.return_value = 'dummy.jws.token'
        # Place the key in the shared context
        self.kong_mock.ctx['shared']['my_public_key'] = 'key-from-context'
        
        # Mock a successful call to capture the body sent to the service
        mock_response = Mock()
        mock_response.status = 200
        mock_response.body = json.dumps({'payload': {}})
        self.kong_mock.http.client.go.return_value = (mock_response, None)

        self.plugin.access(conf)
        
        # We can't directly inspect the body sent to kong.http.client.go with this simplified mock,
        # but we can verify the plugin didn't fail due to a missing key.
        self.kong_mock.response.exit.assert_not_called()
        self.kong_mock.http.client.go.assert_called_once()
        # A more advanced test could capture the 'body' argument sent to the mock.
        
    def test_jws_from_body(self):
        """
        Test Case 3: JWS token is correctly extracted from the request body.
        """
        conf = {
            'jws_decode_service_url': 'http://mock-service/decode',
            'jws_source_type': 'body',
            'jws_source_name': 'token', # Look for a 'token' field in the JSON body
            'public_key_literal': 'test-key'
        }
        # Set up the mock request body
        request_body = json.dumps({'token': 'jws.from.body', 'other_field': 'value'})
        self.kong_mock.request.get_raw_body.return_value = request_body

        # Mock a successful response
        mock_response = Mock()
        mock_response.status = 200
        mock_response.body = json.dumps({'payload': {}})
        self.kong_mock.http.client.go.return_value = (mock_response, None)

        self.plugin.access(conf)
        
        self.kong_mock.response.exit.assert_not_called()
        self.kong_mock.http.client.go.assert_called_once()

if __name__ == '__main__':
    unittest.main()
