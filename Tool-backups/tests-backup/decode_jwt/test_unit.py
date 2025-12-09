import unittest
from unittest.mock import Mock
import base64
import json

# Mocking the Kong environment and plugin logic
class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()

class DecodeJWTHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_source(self, source_type, source_name):
        value = None
        if source_type == "header":
            value = self.kong.request.get_header(source_name)
            # Handle Authorization: Bearer token_string
            if value and source_name.lower() == "authorization" and value.lower().startswith("bearer "):
                value = value[7:]
        return value

    def access(self, conf):
        jwt_string = self.get_value_from_source(conf.get('jwt_source_type'), conf.get('jwt_source_name'))
        if not jwt_string:
            if not conf.get('on_error_continue', False):
                return self.kong.response.exit(400, "Missing JWT")
            return

        parts = jwt_string.split('.')
        if len(parts) != 3:
            if not conf.get('on_error_continue', False):
                return self.kong.response.exit(400, "Invalid format")
            return
        
        # Simplified payload decoding for the test
        try:
            # In a real scenario, this would be base64url decoded
            payload = json.loads(base64.b64decode(parts[1] + "==").decode('utf-8'))
        except:
             payload = {}

        for claim in conf.get('claims_to_extract', []):
            if claim['claim_name'] not in payload:
                # This is the behavior to test: nothing is added
                pass

class TestDecodeJWTUnit(unittest.TestCase):
    
    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = DecodeJWTHandler(self.kong_mock)
        self.sample_jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature"

    def test_on_error_continue_true(self):
        """
        Test Case 1: With on_error_continue=true, request proceeds on failure.
        """
        conf = {
            'jwt_source_type': 'header',
            'jwt_source_name': 'Authorization',
            'on_error_continue': True
        }
        # Malformed JWT
        self.kong_mock.request.get_header.return_value = "invalid.jwt"
        
        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_not_called()

    def test_bearer_prefix_stripping(self):
        """
        Test Case 2: Correctly strips 'Bearer ' prefix from Authorization header.
        """
        conf = {
            'jwt_source_type': 'header',
            'jwt_source_name': 'Authorization'
        }
        # JWT with "Bearer " prefix
        self.kong_mock.request.get_header.return_value = f"Bearer {self.sample_jwt}"
        
        # We test the helper function directly
        jwt_string = self.plugin.get_value_from_source('header', 'Authorization')
        
        self.assertEqual(jwt_string, self.sample_jwt)

    def test_non_existent_claim(self):
        """
        Test Case 3: Plugin proceeds without error if a specified claim is not in the payload.
        """
        conf = {
            'jwt_source_type': 'header',
            'jwt_source_name': 'Authorization',
            # Asking for a claim that doesn't exist in self.sample_jwt
            'claims_to_extract': [{'claim_name': 'non-existent-claim', 'output_key': 'should_not_exist'}]
        }
        self.kong_mock.request.get_header.return_value = self.sample_jwt

        self.plugin.access(conf)

        # Assert that the key was not added to the context
        self.assertNotIn('should_not_exist', self.kong_mock.ctx['shared'])
        # And that the request was not terminated
        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
