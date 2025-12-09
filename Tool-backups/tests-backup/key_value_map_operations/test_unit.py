import unittest
from unittest.mock import Mock, MagicMock

# Reusing the Python implementation from the functional tests
from tests.key_value_map_operations.test_functional import KeyValueMapOperationsHandler, KongMock

class TestKeyValueMapOperationsUnit(unittest.TestCase):

    def setUp(self):
        self.kvm_name = "my_kvm"
        # Base conf for failure tests
        self.base_conf = {
            'kvm_name': self.kvm_name,
            'on_error_status': 500,
            'on_error_body': 'KVM Error',
            'on_error_continue': False
        }

    def test_kvm_not_configured(self):
        """
        Test Case 1: Terminates request if the shared dictionary is not configured.
        """
        # Arrange
        kong_mock = KongMock(self.kvm_name)
        kong_mock.shared = {} # Simulate no shared dicts configured
        plugin = KeyValueMapOperationsHandler(kong_mock, self.kvm_name)
        conf = {**self.base_conf, 'operation_type': 'get', 'key_source_type': 'literal', 'key_source_name': 'any', 'output_destination_type': 'shared_context', 'output_destination_name': 'out'}

        # Act
        plugin.access(conf)

        # Assert
        kong_mock.response.exit.assert_called_once_with(500, 'KVM Error')

    def test_get_operation_key_not_found(self):
        """
        Test Case 2: Terminates request if a 'get' operation finds no key.
        """
        # Arrange
        kong_mock = KongMock(self.kvm_name)
        plugin = KeyValueMapOperationsHandler(kong_mock, self.kvm_name)
        conf = {
            **self.base_conf,
            'operation_type': 'get',
            'key_source_type': 'literal',
            'key_source_name': 'non_existent_key',
            'output_destination_type': 'shared_context',
            'output_destination_name': 'should_not_be_set'
        }
        # Mock the KVM to return nil (None)
        kong_mock.shared[self.kvm_name].get.return_value = (None, None)
        
        # Act
        plugin.access(conf)

        # Assert
        kong_mock.shared[self.kvm_name].get.assert_called_once_with('non_existent_key')
        self.assertNotIn('should_not_be_set', kong_mock.ctx['shared'])
        kong_mock.response.exit.assert_called_once_with(500, 'KVM Error')
        
    def test_put_operation_no_value(self):
        """
        Test Case 3: Terminates request if 'put' operation has no value to store.
        """
        # Arrange
        kong_mock = KongMock(self.kvm_name)
        plugin = KeyValueMapOperationsHandler(kong_mock, self.kvm_name)
        conf = {
            **self.base_conf,
            'operation_type': 'put',
            'key_source_type': 'literal',
            'key_source_name': 'a-key',
            'value_source_type': 'shared_context',
            'value_source_name': 'non_existent_value_key' # This doesn't exist
        }
        # Ensure the value source is empty
        kong_mock.ctx['shared'] = {}
        
        # Act
        plugin.access(conf)

        # Assert
        kong_mock.shared[self.kvm_name].set.assert_not_called()
        kong_mock.response.exit.assert_called_once_with(500, 'KVM Error')

if __name__ == '__main__':
    unittest.main()
