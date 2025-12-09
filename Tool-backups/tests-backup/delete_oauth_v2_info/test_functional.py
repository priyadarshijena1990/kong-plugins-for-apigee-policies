import unittest
from unittest.mock import Mock

# Mocking the Kong environment
class KongMock:
    def __init__(self):
        self.log = Mock()
        self.ctx = {'shared': {}}

# Python representation of the plugin logic
class DeleteOAuthV2InfoHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        if not conf.get('keys_to_delete'):
            return
        
        for key in conf['keys_to_delete']:
            if key in self.kong.ctx['shared']:
                del self.kong.ctx['shared'][key]

class TestDeleteOAuthV2InfoFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = DeleteOAuthV2InfoHandler(self.kong_mock)

    def test_delete_existing_keys(self):
        """
        Test Case 1: Deletes keys that exist in the shared context.
        """
        # Arrange: Populate the context
        self.kong_mock.ctx['shared']['access_token'] = 'token123'
        self.kong_mock.ctx['shared']['token_type'] = 'Bearer'
        conf = {
            'keys_to_delete': ['access_token', 'token_type']
        }

        # Act: Run the plugin
        self.plugin.access(conf)

        # Assert: Keys are no longer in the context
        self.assertNotIn('access_token', self.kong_mock.ctx['shared'])
        self.assertNotIn('token_type', self.kong_mock.ctx['shared'])

    def test_delete_non_existing_keys(self):
        """
        Test Case 2: No error when attempting to delete keys that do not exist.
        """
        # Arrange: Context is empty
        conf = {
            'keys_to_delete': ['key1', 'key2']
        }

        # Act: Run the plugin
        self.plugin.access(conf)

        # Assert: Context remains empty and no error was thrown
        self.assertEqual(len(self.kong_mock.ctx['shared']), 0)
        
    def test_delete_mixed_keys(self):
        """
        Test Case 3: Correctly deletes existing keys while ignoring non-existing ones.
        """
        # Arrange: Populate context with some keys
        self.kong_mock.ctx['shared']['key_to_delete'] = 'some_value'
        self.kong_mock.ctx['shared']['key_to_keep'] = 'another_value'
        conf = {
            'keys_to_delete': ['key_to_delete', 'non_existent_key']
        }

        # Act: Run the plugin
        self.plugin.access(conf)

        # Assert: The correct key was deleted and the other was kept
        self.assertNotIn('key_to_delete', self.kong_mock.ctx['shared'])
        self.assertIn('key_to_keep', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['key_to_keep'], 'another_value')

if __name__ == '__main__':
    unittest.main()
