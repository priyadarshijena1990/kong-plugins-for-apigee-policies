import unittest
from unittest.mock import Mock

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.ctx = {'shared': {}}

class ReadPropertySetHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        properties = conf.get('properties', {})
        if conf.get('assign_to_shared_context_key'):
            self.kong.ctx['shared'][conf['assign_to_shared_context_key']] = properties
        else:
            set_name = conf.get('property_set_name', 'unknown')
            for key, value in properties.items():
                self.kong.ctx['shared'][f"{set_name}.{key}"] = value

class TestReadPropertySetFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = ReadPropertySetHandler(self.kong_mock)
        self.properties = {
            'target_url': 'http://example.com/api',
            'retries': '3',
            'is_active': 'true'
        }

    def test_individual_property_assignment(self):
        """
        Test Case 1: Assigns properties individually to the shared context.
        """
        conf = {
            'property_set_name': 'my-settings',
            'properties': self.properties
        }

        self.plugin.access(conf)

        self.assertIn('my-settings.target_url', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['my-settings.target_url'], 'http://example.com/api')
        
        self.assertIn('my-settings.retries', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['my-settings.retries'], '3')

        self.assertIn('my-settings.is_active', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['my-settings.is_active'], 'true')

    def test_bulk_property_assignment(self):
        """
        Test Case 2: Assigns the entire property set as a single map to the context.
        """
        conf = {
            'property_set_name': 'my-settings',
            'properties': self.properties,
            'assign_to_shared_context_key': 'all_settings'
        }

        self.plugin.access(conf)

        self.assertIn('all_settings', self.kong_mock.ctx['shared'])
        self.assertIsInstance(self.kong_mock.ctx['shared']['all_settings'], dict)
        self.assertEqual(self.kong_mock.ctx['shared']['all_settings']['target_url'], 'http://example.com/api')
        self.assertEqual(len(self.kong_mock.ctx['shared']['all_settings']), 3)
        # Check that individual properties were NOT set
        self.assertNotIn('my-settings.target_url', self.kong_mock.ctx['shared'])


if __name__ == '__main__':
    unittest.main()
