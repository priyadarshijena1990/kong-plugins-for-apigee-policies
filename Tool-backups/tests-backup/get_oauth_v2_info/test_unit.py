import unittest
from unittest.mock import Mock

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.client = Mock()
        self.ctx = {
            'shared': {},
            'authenticated_oauth2_token': None
        }

class GetOAuthV2InfoHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        consumer = self.kong.client.get_consumer()
        credential = self.kong.client.get_credential()

        if conf.get('extract_end_user_to_shared_context_key') and consumer:
            end_user = consumer.get('username') or consumer.get('custom_id')
            if end_user:
                self.kong.ctx['shared'][conf['extract_end_user_to_shared_context_key']] = end_user

        if conf.get('extract_scopes_to_shared_context_key') and self.kong.ctx.get('authenticated_oauth2_token'):
            scopes = self.kong.ctx['authenticated_oauth2_token'].get('scope')
            if isinstance(scopes, list):
                scopes = ",".join(scopes)
            if scopes:
                self.kong.ctx['shared'][conf['extract_scopes_to_shared_context_key']] = scopes

class TestGetOAuthV2InfoUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = GetOAuthV2InfoHandler(self.kong_mock)
        # Default mocks for entities
        self.kong_mock.client.get_consumer.return_value = {}
        self.kong_mock.client.get_credential.return_value = {}

    def test_no_configuration(self):
        """
        Test Case 1: Plugin runs without error if the config is empty.
        """
        # Arrange: set some context that should not be touched
        self.kong_mock.ctx['shared']['pre_existing'] = 'value'
        
        # Act
        self.plugin.access({}) # Empty config

        # Assert: context is unchanged
        self.assertEqual(self.kong_mock.ctx['shared'], {'pre_existing': 'value'})

    def test_consumer_with_custom_id(self):
        """
        Test Case 2: Uses consumer's custom_id as fallback for end user.
        """
        conf = {'extract_end_user_to_shared_context_key': 'user_id'}
        # Arrange: Consumer has custom_id but no username
        self.kong_mock.client.get_consumer.return_value = {'custom_id': 'user-from-custom-id'}

        self.plugin.access(conf)

        self.assertEqual(self.kong_mock.ctx['shared'].get('user_id'), 'user-from-custom-id')

    def test_scope_as_table(self):
        """
        Test Case 3: Correctly joins a table of scopes into a string.
        """
        conf = {'extract_scopes_to_shared_context_key': 'scopes'}
        # Arrange: Scopes are a list (table in Lua)
        self.kong_mock.ctx['authenticated_oauth2_token'] = {'scope': ['read:data', 'write:data']}

        self.plugin.access(conf)

        self.assertEqual(self.kong_mock.ctx['shared'].get('scopes'), 'read:data,write:data')

if __name__ == '__main__':
    unittest.main()
