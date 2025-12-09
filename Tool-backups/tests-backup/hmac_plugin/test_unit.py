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
        self.ALGORITHM_MAP = {"HMAC-SHA256": hashlib.sha256}

    def access(self, conf):
        client_sig_full = self.kong.request.get_header(conf['signature_header_name'])
        if not client_sig_full:
            return self.kong.response.exit(400)

        client_sig = client_sig_full
        prefix = conf.get('signature_prefix', '')
        if prefix and client_sig.startswith(prefix):
            client_sig = client_sig[len(prefix):]

        secret = conf.get('secret_literal') or self.kong.ctx['shared'].get(conf.get('secret_source_name'))
        
        string_to_sign = self.kong.request.get_raw_body() # Simplified for these tests

        algo = self.ALGORITHM_MAP.get(conf['algorithm'])
        digest = hmac.new(secret.encode('utf-8'), string_to_sign.encode('utf-8'), algo).digest()
        calculated_sig = base64.b64encode(digest).decode('utf-8')

        if calculated_sig != client_sig:
            if not conf.get('on_verification_failure_continue'):
                return self.kong.response.exit(401)
        
class TestHMACUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = HMACHandler(self.kong_mock)
        self.kong_mock.request.get_raw_body.return_value = "test-body"

    def test_secret_from_shared_context(self):
        """
        Test Case 1: Correctly uses the shared secret from kong.ctx.shared.
        """
        secret = "secret-from-context"
        string_to_sign = self.kong_mock.request.get_raw_body()
        digest = hmac.new(secret.encode('utf-8'), string_to_sign.encode('utf-8'), hashlib.sha256).digest()
        expected_sig = base64.b64encode(digest).decode('utf-8')

        conf = {
            'signature_header_name': 'X-Sig', 'algorithm': 'HMAC-SHA256',
            'secret_source_type': 'shared_context',
            'secret_source_name': 'hmac_secret'
        }
        # Arrange
        self.kong_mock.ctx['shared']['hmac_secret'] = secret
        self.kong_mock.request.get_header.return_value = expected_sig

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_not_called()

    def test_failure_with_continue_on_error(self):
        """
        Test Case 2: Request proceeds on verification failure if on_verification_failure_continue is true.
        """
        conf = {
            'signature_header_name': 'X-Sig', 'algorithm': 'HMAC-SHA256',
            'secret_literal': 'any-secret',
            'on_verification_failure_continue': True # Key for this test
        }
        # Arrange: Provide a deliberately wrong signature
        self.kong_mock.request.get_header.return_value = "wrong-signature"

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_not_called()

    def test_signature_with_prefix(self):
        """
        Test Case 3: Correctly verifies a signature that has a prefix.
        """
        secret = "my-secret"
        string_to_sign = self.kong_mock.request.get_raw_body()
        digest = hmac.new(secret.encode('utf-8'), string_to_sign.encode('utf-8'), hashlib.sha256).digest()
        signature_part = base64.b64encode(digest).decode('utf-8')
        
        prefix = "HMAC-SHA256 "
        full_signature_header = f"{prefix}{signature_part}"

        conf = {
            'signature_header_name': 'Authorization',
            'algorithm': 'HMAC-SHA256',
            'secret_literal': secret,
            'signature_prefix': prefix
        }
        self.kong_mock.request.get_header.return_value = full_signature_header
        
        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
