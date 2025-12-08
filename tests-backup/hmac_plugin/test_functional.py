import unittest
from unittest.mock import Mock, MagicMock
import hmac
import hashlib
import base64

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()

class HMACHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock
        self.ALGORITHM_MAP = {
            "HMAC-SHA256": hashlib.sha256,
        }

    def get_component_value(self, comp_type, comp_name):
        if comp_type == "method": return self.kong.request.get_method()
        if comp_type == "uri": return self.kong.request.get_uri()
        if comp_type == "body": return self.kong.request.get_raw_body()
        return ""

    def access(self, conf):
        client_sig = self.kong.request.get_header(conf['signature_header_name'])
        if not client_sig:
            return self.kong.response.exit(conf['on_verification_failure_status'], conf['on_verification_failure_body'])

        secret = conf.get('secret_literal') # Simplified for test

        string_to_sign_parts = []
        for comp in conf['string_to_sign_components']:
            string_to_sign_parts.append(self.get_component_value(comp['component_type'], comp.get('component_name')))
        
        string_to_sign = "\n".join(string_to_sign_parts)
        
        algo = self.ALGORITHM_MAP.get(conf['algorithm'])
        if not algo or not secret:
            return self.kong.response.exit(500, "Config error")
            
        digest = hmac.new(secret.encode('utf-8'), string_to_sign.encode('utf-8'), algo).digest()
        calculated_sig = base64.b64encode(digest).decode('utf-8')

        if calculated_sig != client_sig:
            return self.kong.response.exit(conf['on_verification_failure_status'], conf['on_verification_failure_body'])

class TestHMACFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = HMACHandler(self.kong_mock)
        self.secret = "my-shared-secret"

    def test_successful_verification(self):
        """
        Test Case 1: Correctly verifies a valid HMAC signature.
        """
        # --- Arrange ---
        # 1. Define request parts and string-to-sign
        method = "POST"
        uri = "/test/path"
        body = '{"hello": "world"}'
        string_to_sign = f"{method}\n{uri}\n{body}"

        # 2. Calculate expected signature
        digest = hmac.new(self.secret.encode('utf-8'), string_to_sign.encode('utf-8'), hashlib.sha256).digest()
        expected_sig = base64.b64encode(digest).decode('utf-8')
        
        # 3. Configure plugin and mock request
        conf = {
            'signature_header_name': 'X-Signature',
            'algorithm': 'HMAC-SHA256',
            'secret_literal': self.secret,
            'string_to_sign_components': [
                {'component_type': 'method'},
                {'component_type': 'uri'},
                {'component_type': 'body'},
            ]
        }
        self.kong_mock.request.get_method.return_value = method
        self.kong_mock.request.get_uri.return_value = uri
        self.kong_mock.request.get_raw_body.return_value = body
        self.kong_mock.request.get_header.return_value = expected_sig # Provide correct signature

        # --- Act ---
        self.plugin.access(conf)

        # --- Assert ---
        self.kong_mock.response.exit.assert_not_called()

    def test_failed_verification(self):
        """
        Test Case 2: Blocks a request with an incorrect signature.
        """
        conf = {
            'signature_header_name': 'X-Signature',
            'algorithm': 'HMAC-SHA256',
            'secret_literal': self.secret,
            'string_to_sign_components': [{'component_type': 'body'}],
            'on_verification_failure_status': 401,
            'on_verification_failure_body': 'Invalid signature.'
        }
        self.kong_mock.request.get_raw_body.return_value = 'some-body'
        self.kong_mock.request.get_header.return_value = 'incorrect-signature' # Provide wrong signature

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(401, 'Invalid signature.')

    def test_missing_header(self):
        """
        Test Case 3: Blocks a request if the signature header is missing.
        """
        conf = {
            'signature_header_name': 'X-Signature',
            'algorithm': 'HMAC-SHA256',
            'secret_literal': self.secret,
            'string_to_sign_components': [{'component_type': 'body'}],
            'on_verification_failure_status': 400,
            'on_verification_failure_body': 'Missing signature header.'
        }
        # Simulate header is not found
        self.kong_mock.request.get_header.return_value = None

        self.plugin.access(conf)

        self.kong_mock.request.get_header.assert_called_with('X-Signature')
        self.kong_mock.response.exit.assert_called_once_with(400, 'Missing signature header.')

if __name__ == '__main__':
    unittest.main()
