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

class TestAccessEntityUnit(unittest.TestCase):

    def setUp(self):
        """Set up a new mock Kong environment for each test."""
        self.kong_mock = KongMock()
        self.plugin = AccessEntityHandler(self.kong_mock)

    def test_no_entity_found(self):
        """
        Test 1: Plugin exits gracefully when no authenticated entity is found.
        """
        # No consumer is found
        self.kong_mock.client.get_consumer.return_value = None

        # Plugin configuration
        conf = {
            'entity_type': 'consumer',
            'extract_attributes': [
                {'source_field': 'username', 'output_key': 'user_name_from_consumer'}
            ]
        }

        # Execute the plugin's access phase
        self.plugin.access(conf)

        # Assert that the shared context is empty
        self.assertEqual(len(self.kong_mock.ctx['shared']), 0)
        self.kong_mock.log.warn.assert_called_with("AccessEntity: No authenticated '", 'consumer', "' found. Skipping attribute extraction.")

    def test_attribute_not_found_no_default(self):
        """
        Test 2: Nothing is added to context when an attribute is not found and no default is provided.
        """
        # Configure the mock consumer
        mock_consumer = {'id': 'consumer-id', 'username': 'test-user'}
        self.kong_mock.client.get_consumer.return_value = mock_consumer

        # Plugin configuration looking for a non-existent field
        conf = {
            'entity_type': 'consumer',
            'extract_attributes': [
                {'source_field': 'non_existent_field', 'output_key': 'should_not_be_set'}
            ]
        }

        # Execute the plugin's access phase
        self.plugin.access(conf)

        # Assert that the shared context is still empty
        self.assertNotIn('should_not_be_set', self.kong_mock.ctx['shared'])

    def test_extract_multiple_attributes(self):
        """
        Test 3: Plugin correctly extracts multiple attributes.
        """
        # Configure the mock consumer
        mock_consumer = {'id': 'consumer-id', 'username': 'test-user', 'custom_id': '12345'}
        self.kong_mock.client.get_consumer.return_value = mock_consumer

        # Plugin configuration for multiple attributes
        conf = {
            'entity_type': 'consumer',
            'extract_attributes': [
                {'source_field': 'username', 'output_key': 'user_name'},
                {'source_field': 'custom_id', 'output_key': 'custom_user_id'}
            ]
        }

        # Execute the plugin's access phase
        self.plugin.access(conf)

        # Assert that both attributes were extracted correctly
        self.assertIn('user_name', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['user_name'], 'test-user')
        self.assertIn('custom_user_id', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['custom_user_id'], '12345')

if __name__ == '__main__':
    unittest.main()
