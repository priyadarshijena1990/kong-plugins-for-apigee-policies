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
        # The 'get' method with an empty list as default handles both missing and null cases for the conf key
        keys_to_delete = conf.get('keys_to_delete') or []
        
        for key in keys_to_delete:
            if key in self.kong.ctx['shared']:
                del self.kong.ctx['shared'][key]
                self.kong.log.debug(f"Deleted {key}")

class TestDeleteOAuthV2InfoUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = DeleteOAuthV2InfoHandler(self.kong_mock)

    def test_no_keys_configured(self):
        """
        Test Case 1: Plugin runs without error if 'keys_to_delete' is not in the config.
        """
        # Arrange: Context has data, but config is empty
        self.kong_mock.ctx['shared']['some_key'] = 'some_value'
        conf = {} # No 'keys_to_delete'

        # Act
        self.plugin.access(conf)

        # Assert: Context is unchanged
        self.assertIn('some_key', self.kong_mock.ctx['shared'])
        self.kong_mock.log.debug.assert_not_called()

    def test_empty_keys_list(self):
        """
        Test Case 2: Plugin runs without error if 'keys_to_delete' is an empty list.
        """
        # Arrange
        self.kong_mock.ctx['shared']['some_key'] = 'some_value'
        conf = {'keys_to_delete': []}

        # Act
        self.plugin.access(conf)

        # Assert: Context is unchanged
        self.assertIn('some_key', self.kong_mock.ctx['shared'])
        self.kong_mock.log.debug.assert_not_called()

    def test_key_with_none_value(self):
        """
        Test Case 3: A key with a value of None is still deleted if specified.
        """
        # Arrange
        self.kong_mock.ctx['shared']['key_with_none'] = None
        conf = {'keys_to_delete': ['key_with_none']}
        
        # Act
        self.plugin.access(conf)
        
        # Assert: The key is removed from the dictionary
        self.assertNotIn('key_with_none', self.kong_mock.ctx['shared'])
        self.kong_mock.log.debug.assert_called_with("Deleted key_with_none")

if __name__ == '__main__':
    unittest.main()
