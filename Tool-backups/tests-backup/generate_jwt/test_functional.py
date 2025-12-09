import unittest
from unittest.mock import Mock, patch
import json
import time

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()
        self.http = Mock()
        # Mock ngx.time()
        self.ngx = Mock()

class GenerateJWTHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_source(self, source_type, source_name):
        if source_type == 'literal':
            return source_name
        if source_type == 'shared_context':
            return self.kong.ctx['shared'].get(source_name)
        return None

    def set_value_to_destination(self, dest_type, dest_name, value):
        if dest_type == 'header':
            self.kong.request.set_header(dest_name, value)

    def access(self, conf):
        claims = {}
        if conf.get('subject_source_type'):
            claims['sub'] = self.get_value_from_source(conf['subject_source_type'], conf['subject_source_name'])
        if conf.get('expires_in_seconds'):
            claims['exp'] = self.kong.ngx.time() + conf['expires_in_seconds']
        for claim_conf in conf.get('additional_claims', []):
            claims[claim_conf['claim_name']] = self.get_value_from_source(claim_conf['claim_value_source_type'], claim_conf['claim_value_source_name'])

        key = None
        if conf.get('secret_source_type') == 'literal':
            key = conf.get('secret_literal')
        else:
            key = self.get_value_from_source(conf.get('secret_source_type'), conf.get('secret_source_name'))

        if not key:
            return self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])
        
        req_body = {'claims': claims, 'key': key, 'algorithm': conf['algorithm']}
        res, err = self.kong.http.client.go(conf['jwt_generate_service_url'], {'body': json.dumps(req_body)})

        if res and res.status == 200:
            jwt = json.loads(res.body).get('jwt')
            self.set_value_to_destination(conf['output_destination_type'], conf['output_destination_name'], jwt)
        else:
             return self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])

class TestGenerateJWTFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = GenerateJWTHandler(self.kong_mock)
        self.current_time = int(time.time())
        self.kong_mock.ngx.time.return_value = self.current_time

    def test_assemble_and_sign(self):
        """
        Test Case 1: Correctly assembles claims and calls the signing service.
        """
        self.kong_mock.ctx['shared']['user_role'] = 'admin'
        conf = {
            'jwt_generate_service_url': 'http://signer/sign',
            'algorithm': 'HS256',
            'secret_source_type': 'literal',
            'secret_literal': 'my-secret',
            'subject_source_type': 'literal',
            'subject_source_name': 'user123',
            'expires_in_seconds': 3600,
            'additional_claims': [{
                'claim_name': 'role',
                'claim_value_source_type': 'shared_context',
                'claim_value_source_name': 'user_role'
            }],
            'output_destination_type': 'header',
            'output_destination_name': 'X-My-JWT',
            'on_error_status': 500,
            'on_error_body': 'JWT Generation Error'
        }
        self.kong_mock.http.client.go.return_value = (Mock(status=200, body='{"jwt":"..."}'), None)

        self.plugin.access(conf)

        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        sent_body = json.loads(call_args[1]['body'])
        
        # Assert claims payload is correct
        self.assertEqual(sent_body['claims']['sub'], 'user123')
        self.assertEqual(sent_body['claims']['role'], 'admin')
        self.assertEqual(sent_body['claims']['exp'], self.current_time + 3600)
        # Assert key and algorithm are correct
        self.assertEqual(sent_body['key'], 'my-secret')
        self.assertEqual(sent_body['algorithm'], 'HS256')

    def test_successful_generation_and_output(self):
        """
        Test Case 2: Places the generated JWT into the correct output destination.
        """
        conf = {
            'jwt_generate_service_url': 'http://signer/sign',
            'algorithm': 'HS256',
            'secret_source_type': 'literal', 'secret_literal': 's', # simplified
            'output_destination_type': 'header',
            'output_destination_name': 'X-My-JWT',
            'on_error_status': 500,
            'on_error_body': 'JWT Generation Error'
        }
        generated_jwt = "signed.jwt.token"
        mock_response = Mock(status=200, body=json.dumps({'jwt': generated_jwt}))
        self.kong_mock.http.client.go.return_value = (mock_response, None)

        self.plugin.access(conf)

        self.kong_mock.request.set_header.assert_called_once_with('X-My-JWT', generated_jwt)
        self.kong_mock.response.exit.assert_not_called()

    def test_missing_signing_key(self):
        """
        Test Case 3: Terminates request if the signing key is not found.
        """
        conf = {
            'jwt_generate_service_url': 'http://signer/sign',
            'algorithm': 'HS256',
            'secret_source_type': 'shared_context',
            'secret_source_name': 'non_existent_key', # This key is missing
            'on_error_status': 401,
            'on_error_body': 'Key configuration error'
        }

        self.plugin.access(conf)

        self.kong_mock.http.client.go.assert_not_called()
        self.kong_mock.response.exit.assert_called_once_with(401, 'Key configuration error')

if __name__ == '__main__':
    unittest.main()
