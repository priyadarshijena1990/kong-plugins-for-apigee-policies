import unittest
from unittest.mock import Mock, MagicMock

class KongMock:
    def __init__(self, kvm_name):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()
        # Mock the shared dictionary
        self.shared = {kvm_name: MagicMock()}

class KeyValueMapOperationsHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock, kvm_name):
        self.kong = kong_mock
        self.kvm_name = kvm_name

    def get_value_from_source(self, source_type, source_name):
        # Simplified for testing
        if source_type == 'literal':
            return source_name
        elif source_type == 'shared_context':
            return self.kong.ctx['shared'].get(source_name)
        return None

    def set_value_to_destination(self, dest_type, dest_name, value):
        if dest_type == 'shared_context':
            self.kong.ctx['shared'][dest_name] = value

    def _handle_error(self, conf):
        if not conf.get('on_error_continue', False):
            self.kong.response.exit(conf.get('on_error_status', 500), conf.get('on_error_body', 'KVM Error'))

    def access(self, conf):
        if self.kvm_name not in self.kong.shared:
            self._handle_error(conf)
            return
        
        kvm_dict = self.kong.shared[self.kvm_name]

        key = self.get_value_from_source(conf['key_source_type'], conf['key_source_name'])
        if not key:
            self._handle_error(conf)
            return

        op = conf['operation_type']
        if op == 'put':
            value = self.get_value_from_source(conf['value_source_type'], conf['value_source_name'])
            if value is None:
                self._handle_error(conf)
                return
            kvm_dict.set(key, str(value), conf.get('ttl'))
        elif op == 'get':
            value, _ = kvm_dict.get(key)
            if value is None:
                self._handle_error(conf)
                return
            self.set_value_to_destination(conf['output_destination_type'], conf['output_destination_name'], value)
        elif op == 'delete':
            kvm_dict.delete(key)

class TestKeyValueMapOperationsFunctional(unittest.TestCase):
    
    def setUp(self):
        self.kvm_name = "my_kvm"
        self.kong_mock = KongMock(self.kvm_name)
        self.plugin = KeyValueMapOperationsHandler(self.kong_mock, self.kvm_name)
        self.kvm_dict_mock = self.kong_mock.shared[self.kvm_name]

    def test_put_operation(self):
        """
        Test Case 1: Performs a 'put' operation correctly.
        """
        conf = {
            'kvm_name': self.kvm_name,
            'operation_type': 'put',
            'key_source_type': 'literal',
            'key_source_name': 'my-key',
            'value_source_type': 'shared_context',
            'value_source_name': 'value_to_store',
            'ttl': 3600
        }
        # Arrange
        self.kong_mock.ctx['shared']['value_to_store'] = 'hello world'
        
        # Act
        self.plugin.access(conf)

        # Assert
        self.kvm_dict_mock.set.assert_called_once_with('my-key', 'hello world', 3600)

    def test_get_operation(self):
        """
        Test Case 2: Performs a 'get' operation and stores the result.
        """
        conf = {
            'kvm_name': self.kvm_name,
            'operation_type': 'get',
            'key_source_type': 'literal',
            'key_source_name': 'the-key-to-get',
            'output_destination_type': 'shared_context',
            'output_destination_name': 'retrieved_value'
        }
        # Arrange: Mock the return value from the KVM
        self.kvm_dict_mock.get.return_value = ('retrieved value from KVM', None)
        
        # Act
        self.plugin.access(conf)

        # Assert
        self.kvm_dict_mock.get.assert_called_once_with('the-key-to-get')
        self.assertIn('retrieved_value', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['retrieved_value'], 'retrieved value from KVM')

    def test_delete_operation(self):
        """
        Test Case 3: Performs a 'delete' operation.
        """
        conf = {
            'kvm_name': self.kvm_name,
            'operation_type': 'delete',
            'key_source_type': 'literal',
            'key_source_name': 'key-to-be-deleted'
        }
        
        # Act
        self.plugin.access(conf)

        # Assert
        self.kvm_dict_mock.delete.assert_called_once_with('key-to-be-deleted')
        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
