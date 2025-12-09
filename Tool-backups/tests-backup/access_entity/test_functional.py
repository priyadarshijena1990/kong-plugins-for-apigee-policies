import unittest
from unittest.mock import Mock

# Mocking the Kong environment
class KongMock:
    def __init__(self):
        self.client = Mock()
        self.ctx = {'shared': {}}
        self.log = Mock()

    def reset(self):
        self.ctx['shared'].clear()
        self.client.reset_mock()
        self.log.reset_mock()

# A python representation of the lua plugin for testing purposes
class AccessEntityHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        entity_object = None

        if conf['entity_type'] == 'consumer':
            entity_object = self.kong.client.get_consumer()
        elif conf['entity_type'] == 'credential':
            entity_object = self.kong.client.get_credential()

        if not entity_object:
            self.kong.log.warn("AccessEntity: No authenticated '", conf['entity_type'], "' found. Skipping attribute extraction.")
            return

        for attr_mapping in conf['extract_attributes']:
            extracted_value = entity_object.get(attr_mapping['source_field'])
            
            if extracted_value is None:
                if 'default_value' in attr_mapping:
                    extracted_value = attr_mapping['default_value']
                    self.kong.log.debug("AccessEntity: Field '", attr_mapping['source_field'], "' not found on '", conf['entity_type'], "', using default value.")
                else:
                    self.kong.log.debug("AccessEntity: Field '", attr_mapping['source_field'], "' not found on '", conf['entity_type'], "' and no default value provided. Skipping storage.")
                    continue

            self.kong.ctx['shared'][attr_mapping['output_key']] = extracted_value
            self.kong.log.debug("AccessEntity: Extracted '", attr_mapping['source_field'], "' from '", conf['entity_type'], "' to shared context key '", attr_mapping['output_key'], "': ", str(extracted_value))

class TestAccessEntityFunctional(unittest.TestCase):

    def setUp(self):
        """Set up a new mock Kong environment for each test."""
        self.kong_mock = KongMock()
        self.plugin = AccessEntityHandler(self.kong_mock)

    def test_extract_from_consumer(self):
        """
        Test Case 1: Extract an attribute from a mock consumer object.
        """
        # Configure the mock consumer
        mock_consumer = {'id': 'consumer-id', 'username': 'test-user'}
        self.kong_mock.client.get_consumer.return_value = mock_consumer

        # Plugin configuration
        conf = {
            'entity_type': 'consumer',
            'extract_attributes': [
                {'source_field': 'username', 'output_key': 'user_name_from_consumer'}
            ]
        }

        # Execute the plugin's access phase
        self.plugin.access(conf)

        # Assert that the attribute was extracted and stored in the shared context
        self.assertIn('user_name_from_consumer', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['user_name_from_consumer'], 'test-user')
        self.kong_mock.client.get_consumer.assert_called_once()

    def test_extract_from_credential(self):
        """
        Test Case 2: Extract an attribute from a mock credential object.
        """
        # Configure the mock credential
        mock_credential = {'id': 'cred-id', 'client_id': 'test-client-id'}
        self.kong_mock.client.get_credential.return_value = mock_credential

        # Plugin configuration
        conf = {
            'entity_type': 'credential',
            'extract_attributes': [
                {'source_field': 'client_id', 'output_key': 'client_id_from_cred'}
            ]
        }

        # Execute the plugin's access phase
        self.plugin.access(conf)

        # Assert that the attribute was extracted and stored in the shared context
        self.assertIn('client_id_from_cred', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['client_id_from_cred'], 'test-client-id')
        self.kong_mock.client.get_credential.assert_called_once()

    def test_use_default_value(self):
        """
        Test Case 3: Use a default value when the attribute is not found.
        """
        # Configure the mock consumer (without the attribute we're looking for)
        mock_consumer = {'id': 'consumer-id', 'username': 'test-user'}
        self.kong_mock.client.get_consumer.return_value = mock_consumer

        # Plugin configuration with a default value
        conf = {
            'entity_type': 'consumer',
            'extract_attributes': [
                {'source_field': 'custom_field', 'output_key': 'custom_output', 'default_value': 'default'}
            ]
        }

        # Execute the plugin's access phase
        self.plugin.access(conf)

        # Assert that the default value was used and stored in the shared context
        self.assertIn('custom_output', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['custom_output'], 'default')
        self.kong_mock.client.get_consumer.assert_called_once()

if __name__ == '__main__':
    unittest.main()
