import unittest
from unittest.mock import Mock
import base64
import json

# Python representation of the base64url_decode and other helpers
def base64url_decode(s):
    s = s.replace('-', '+').replace('_', '/')
    s += '=' * (-len(s) % 4)
    return base64.b64decode(s).decode('utf-8')

# Mocking the Kong environment
class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()

# Python representation of the plugin logic
class DecodeJWTHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_source(self, source_type, source_name):
        if source_type == 'header':
            return self.kong.request.get_header(source_name)
        return None

    def access(self, conf):
        jwt_string = self.get_value_from_source(conf['jwt_source_type'], conf['jwt_source_name'])
        if not jwt_string:
            return self.kong.response.exit(400, "Missing JWT")

        parts = jwt_string.split('.')
        if len(parts) != 3:
            return self.kong.response.exit(conf.get('on_error_status', 400), conf.get('on_error_body', '...'))

        try:
            decoded_header = json.loads(base64url_decode(parts[0]))
            decoded_payload = json.loads(base64url_decode(parts[1]))
        except Exception:
            return self.kong.response.exit(400, "Decode error")

        if conf.get('store_header_to_shared_context_key'):
            self.kong.ctx['shared'][conf['store_header_to_shared_context_key']] = decoded_header
        
        if conf.get('store_all_claims_in_shared_context_key'):
            self.kong.ctx['shared'][conf['store_all_claims_in_shared_context_key']] = decoded_payload

        for claim in conf.get('claims_to_extract', []):
            if claim['claim_name'] in decoded_payload:
                self.kong.ctx['shared'][claim['output_key']] = decoded_payload[claim['claim_name']]

class TestDecodeJWTFunctional(unittest.TestCase):
    
    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = DecodeJWTHandler(self.kong_mock)
        # Standard sample JWT: {"alg":"HS256","typ":"JWT"}.{"sub":"1234567890","name":"John Doe","iat":1516239022}.signature
        self.sample_jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

    def test_decode_and_extract_specific_claim(self):
        """
        Test Case 1: Successfully decode and extract a specific claim.
        """
        conf = {
            'jwt_source_type': 'header',
            'jwt_source_name': 'Authorization',
            'claims_to_extract': [{'claim_name': 'sub', 'output_key': 'subject'}]
        }
        self.kong_mock.request.get_header.return_value = self.sample_jwt
        
        self.plugin.access(conf)

        self.assertEqual(self.kong_mock.ctx['shared'].get('subject'), '1234567890')
        self.kong_mock.response.exit.assert_not_called()

    def test_store_entire_payload_and_header(self):
        """
        Test Case 2: Store the entire header and payload in the context.
        """
        conf = {
            'jwt_source_type': 'header',
            'jwt_source_name': 'Authorization',
            'store_header_to_shared_context_key': 'jwt_header',
            'store_all_claims_in_shared_context_key': 'jwt_payload'
        }
        self.kong_mock.request.get_header.return_value = self.sample_jwt
        
        self.plugin.access(conf)

        # Check header
        self.assertIn('jwt_header', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['jwt_header']['alg'], 'HS256')
        
        # Check payload
        self.assertIn('jwt_payload', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['jwt_payload']['name'], 'John Doe')
        self.kong_mock.response.exit.assert_not_called()

    def test_invalid_jwt_format(self):
        """
        Test Case 3: Handle a malformed JWT string.
        """
        conf = {
            'jwt_source_type': 'header',
            'jwt_source_name': 'Authorization',
            'on_error_status': 401,
            'on_error_body': 'Invalid token format'
        }
        # A JWT with only two parts
        malformed_jwt = "part1.part2"
        self.kong_mock.request.get_header.return_value = malformed_jwt

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(401, 'Invalid token format')

if __name__ == '__main__':
    unittest.main()
