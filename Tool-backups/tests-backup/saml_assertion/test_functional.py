import unittest
from unittest.mock import Mock, ANY
import json
import base64

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()
        self.http = Mock()

class SAMLAssertionHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_source(self, source_type, source_name):
        if source_type == 'literal':
            return source_name
        elif source_type == 'shared_context':
            return self.kong.ctx['shared'].get(source_name)
        return None

    def set_value_to_destination(self, dest_type, dest_name, value):
        if dest_type == 'shared_context':
            self.kong.ctx['shared'][dest_name] = value

    def access(self, conf):
        req_body_to_service = {}
        saml_op_successful = False

        if conf['operation_type'] == 'generate':
            payload = self.get_value_from_source(conf['saml_payload_source_type'], conf['saml_payload_source_name'])
            signing_key = self.get_value_from_source(conf['signing_key_source_type'], conf['signing_key_literal'] or conf['signing_key_source_name'])
            if not payload or not signing_key:
                return self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])
            req_body_to_service = {'operation': 'generate', 'payload': payload, 'signing_key': signing_key}
        elif conf['operation_type'] == 'verify':
            assertion = self.get_value_from_source(conf['saml_assertion_source_type'], conf['saml_assertion_source_name'])
            verification_key = self.get_value_from_source(conf['verification_key_source_type'], conf['verification_key_literal'] or conf['verification_key_source_name'])
            if not assertion or not verification_key:
                return self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])
            req_body_to_service = {'operation': 'verify', 'saml_assertion': assertion, 'verification_key': verification_key}

        res, err = self.kong.http.client.go(conf['saml_service_url'], {'body': json.dumps(req_body_to_service)})

        if res and res.status == 200:
            service_response = json.loads(res.body)
            if service_response.get('success'):
                saml_op_successful = True
                if conf['operation_type'] == 'generate' and service_response.get('saml_assertion'):
                    self.set_value_to_destination(conf['output_destination_type'], conf['output_destination_name'], service_response['saml_assertion'])
                elif conf['operation_type'] == 'verify' and service_response.get('verified'):
                    if conf.get('extract_claims') and service_response.get('attributes'):
                        for claim_map in conf['extract_claims']:
                            if claim_map['attribute_name'] in service_response['attributes']:
                                self.kong.ctx['shared'][claim_map['output_key']] = service_response['attributes'][claim_map['attribute_name']]
            else: # Service reported failure
                saml_op_successful = False
        else: # HTTP call failed
            saml_op_successful = False
        
        if not saml_op_successful:
            if not conf.get('on_error_continue', False):
                return self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])


class TestSAMLAssertionFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = SAMLAssertionHandler(self.kong_mock)
        self.base_conf = {
            'saml_service_url': 'http://saml-svc.example.com',
            'on_error_status': 500,
            'on_error_body': 'SAML Error'
        }

    def test_generate_saml_assertion(self):
        """
        Test Case 1: Successfully generates a SAML assertion and stores it.
        """
        conf = {
            **self.base_conf,
            'operation_type': 'generate',
            'saml_payload_source_type': 'literal',
            'saml_payload_source_name': 'user-data',
            'signing_key_source_type': 'literal',
            'signing_key_literal': 'private-key-data',
            'output_destination_type': 'shared_context',
            'output_destination_name': 'generated_saml'
        }
        generated_saml = "<saml:Assertion>...</saml:Assertion>"
        self.kong_mock.http.client.go.return_value = (Mock(status=200, body=json.dumps({'success': True, 'saml_assertion': generated_saml})), None)

        self.plugin.access(conf)

        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        sent_body = json.loads(call_args[1]['body'])
        self.assertEqual(sent_body['operation'], 'generate')
        self.assertEqual(self.kong_mock.ctx['shared']['generated_saml'], generated_saml)
        self.kong_mock.response.exit.assert_not_called()

    def test_verify_saml_assertion(self):
        """
        Test Case 2: Successfully verifies a SAML assertion and extracts attributes.
        """
        conf = {
            **self.base_conf,
            'operation_type': 'verify',
            'saml_assertion_source_type': 'literal',
            'saml_assertion_source_name': 'some-saml-assertion',
            'verification_key_source_type': 'literal',
            'verification_key_literal': 'public-key-data',
            'extract_claims': [
                {'attribute_name': 'uid', 'output_key': 'user_id'},
                {'attribute_name': 'email', 'output_key': 'user_email'}
            ]
        }
        self.kong_mock.http.client.go.return_value = (Mock(status=200, body=json.dumps({
            'success': True, 'verified': True, 
            'attributes': {'uid': '123', 'email': 'test@example.com'}
        })), None)

        self.plugin.access(conf)

        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        sent_body = json.loads(call_args[1]['body'])
        self.assertEqual(sent_body['operation'], 'verify')
        self.assertEqual(self.kong_mock.ctx['shared']['user_id'], '123')
        self.assertEqual(self.kong_mock.ctx['shared']['user_email'], 'test@example.com')
        self.kong_mock.response.exit.assert_not_called()

    def test_external_service_failure(self):
        """
        Test Case 3: Terminates request with error if external service returns error.
        """
        conf = {
            **self.base_conf,
            'operation_type': 'generate',
            'saml_payload_source_type': 'literal', 'saml_payload_source_name': 'data',
            'signing_key_source_type': 'literal', 'signing_key_literal': 'key',
        }
        self.kong_mock.http.client.go.return_value = (Mock(status=500), None)

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(500, 'SAML Error')

if __name__ == '__main__':
    unittest.main()
