import unittest
from unittest.mock import Mock, ANY
import json

# Reusing the Python implementation from the functional tests
from tests.saml_assertion.test_functional import SAMLAssertionHandler, KongMock

class TestSAMLAssertionUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = SAMLAssertionHandler(self.kong_mock)
        self.base_conf = {
            'saml_service_url': 'http://saml-svc.example.com',
            'on_error_status': 500,
            'on_error_body': 'SAML Error'
        }
        # Default successful service response
        self.kong_mock.http.client.go.return_value = (Mock(status=200, body=json.dumps({'success': True, 'saml_assertion': '...', 'verified': True, 'attributes': {}})), None)

    def test_missing_required_input_generate(self):
        """
        Test Case 1: Terminates request if payload or signing key is missing for 'generate'.
        """
        conf = {
            **self.base_conf,
            'operation_type': 'generate',
            'saml_payload_source_type': 'shared_context',
            'saml_payload_source_name': 'non_existent_payload', # This key is missing
            'signing_key_source_type': 'literal',
            'signing_key_literal': 'some-key'
        }
        # Arrange: ensure payload is missing
        self.kong_mock.ctx['shared'] = {}
        
        self.plugin.access(conf)

        self.kong_mock.http.client.go.assert_not_called()
        self.kong_mock.response.exit.assert_called_once_with(500, 'SAML Error')

    def test_on_error_continue_true(self):
        """
        Test Case 2: Request proceeds on error if on_error_continue is true.
        """
        conf = {
            **self.base_conf,
            'operation_type': 'generate',
            'saml_payload_source_type': 'literal', 'saml_payload_source_name': 'data',
            'signing_key_source_type': 'literal', 'signing_key_literal': 'key',
            'on_error_continue': True # Key for this test
        }
        # Arrange: Simulate an error from the external service
        self.kong_mock.http.client.go.return_value = (Mock(status=500), None)

        self.plugin.access(conf)
        
        self.kong_mock.http.client.go.assert_called_once()
        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
