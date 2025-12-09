import unittest
from unittest.mock import Mock

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.client = Mock()
        self.ctx = {
            'shared': {},
            'authenticated_oauth2_token': None # Will be set in tests
        }

class GetOAuthV2InfoHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        consumer = self.kong.client.get_consumer()
        credential = self.kong.client.get_credential()

        if conf.get('extract_client_id_to_shared_context_key') and credential:
            self.kong.ctx['shared'][conf['extract_client_id_to_shared_context_key']] = credential.get('client_id')
        
        if conf.get('extract_app_name_to_shared_context_key') and credential:
            self.kong.ctx['shared'][conf['extract_app_name_to_shared_context_key']] = credential.get('name')

        if conf.get('extract_end_user_to_shared_context_key') and consumer:
            self.kong.ctx['shared'][conf['extract_end_user_to_shared_context_key']] = consumer.get('username')

        if conf.get('extract_scopes_to_shared_context_key') and self.kong.ctx.get('authenticated_oauth2_token'):
            self.kong.ctx['shared'][conf['extract_scopes_to_shared_context_key']] = self.kong.ctx['authenticated_oauth2_token'].get('scope')

        for attr in conf.get('extract_custom_attributes', []):
            value = None
            if consumer and attr['source_field'] in consumer:
                value = consumer[attr['source_field']]
            elif credential and attr['source_field'] in credential:
                value = credential[attr['source_field']]
            
            if value is not None:
                self.kong.ctx['shared'][attr['output_key']] = value

class TestGetOAuthV2InfoFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = GetOAuthV2InfoHandler(self.kong_mock)

    def test_extract_standard_info(self):
        """
        Test Case 1: Extracts all standard OAuth2 information correctly.
        """
        conf = {
            'extract_client_id_to_shared_context_key': 'oauth_client_id',
            'extract_app_name_to_shared_context_key': 'oauth_app_name',
            'extract_end_user_to_shared_context_key': 'oauth_user',
            'extract_scopes_to_shared_context_key': 'oauth_scopes'
        }
        # Mock data from an upstream auth plugin
        self.kong_mock.client.get_consumer.return_value = {'username': 'testuser'}
        self.kong_mock.client.get_credential.return_value = {'client_id': 'abc-123', 'name': 'Test App'}
        self.kong_mock.ctx['authenticated_oauth2_token'] = {'scope': 'read,write'}

        self.plugin.access(conf)

        self.assertEqual(self.kong_mock.ctx['shared'].get('oauth_client_id'), 'abc-123')
        self.assertEqual(self.kong_mock.ctx['shared'].get('oauth_app_name'), 'Test App')
        self.assertEqual(self.kong_mock.ctx['shared'].get('oauth_user'), 'testuser')
        self.assertEqual(self.kong_mock.ctx['shared'].get('oauth_scopes'), 'read,write')

    def test_extract_custom_attributes(self):
        """
        Test Case 2: Extracts custom attributes from both consumer and credential.
        """
        conf = {
            'extract_custom_attributes': [
                {'source_field': 'user_tier', 'output_key': 'tier'},
                {'source_field': 'app_version', 'output_key': 'version'}
            ]
        }
        # Mock data
        self.kong_mock.client.get_consumer.return_value = {'user_tier': 'gold'}
        self.kong_mock.client.get_credential.return_value = {'app_version': '2.1'}

        self.plugin.access(conf)

        self.assertEqual(self.kong_mock.ctx['shared'].get('tier'), 'gold')
        self.assertEqual(self.kong_mock.ctx['shared'].get('version'), '2.1')

    def test_partial_info_available(self):
        """
        Test Case 3: Plugin runs without error when some info is missing.
        """
        conf = {
            'extract_client_id_to_shared_context_key': 'oauth_client_id',
            'extract_end_user_to_shared_context_key': 'oauth_user',
        }
        # Mock data: credential exists, but no consumer
        self.kong_mock.client.get_consumer.return_value = None
        self.kong_mock.client.get_credential.return_value = {'client_id': 'xyz-789'}
        
        self.plugin.access(conf)

        # Asserts that the available data was extracted
        self.assertEqual(self.kong_mock.ctx['shared'].get('oauth_client_id'), 'xyz-789')
        # Asserts that the missing data was not
        self.assertNotIn('oauth_user', self.kong_mock.ctx['shared'])

if __name__ == '__main__':
    unittest.main()
