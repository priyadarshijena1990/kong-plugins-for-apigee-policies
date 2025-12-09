import unittest
from unittest.mock import Mock, ANY
import json

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.ctx = {'shared': {}}

class LogSharedContextHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def log(self, conf):
        data_to_log = {}
        prefix = conf.get('target_key_prefix', "")
        
        if not prefix:
            data_to_log = self.kong.ctx['shared']
        else:
            for k, v in self.kong.ctx['shared'].items():
                if k.startswith(prefix):
                    data_to_log[k] = v
        
        # The lua cjson.encode might produce slightly different spacing, but for a test,
        # comparing the parsed objects is robust.
        self.kong.log.notice("LOG_SHARED_CONTEXT -- ", conf['log_key'], ": ", json.dumps(data_to_log))

class TestLogSharedContextFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = LogSharedContextHandler(self.kong_mock)

    def test_log_entire_context(self):
        """
        Test Case 1: Logs the entire shared context when no prefix is given.
        """
        conf = {'log_key': 'test1', 'target_key_prefix': ''}
        # Arrange
        self.kong_mock.ctx['shared'] = {'key1': 'value1', 'key2': 123}
        expected_json = json.dumps({'key1': 'value1', 'key2': 123})
        
        # Act
        self.plugin.log(conf)

        # Assert
        self.kong_mock.log.notice.assert_called_once_with(
            "LOG_SHARED_CONTEXT -- ", 'test1', ": ", expected_json
        )

    def test_log_with_prefix(self):
        """
        Test Case 2: Logs only the keys matching the specified prefix.
        """
        conf = {'log_key': 'test2', 'target_key_prefix': 'prefix_'}
        # Arrange
        self.kong_mock.ctx['shared'] = {
            'prefix_key1': 'value1',
            'prefix_key2': True,
            'other_key': 'value3'
        }
        expected_data = {'prefix_key1': 'value1', 'prefix_key2': True}
        expected_json = json.dumps(expected_data)

        # Act
        self.plugin.log(conf)

        # Assert
        self.kong_mock.log.notice.assert_called_once_with(
            "LOG_SHARED_CONTEXT -- ", 'test2', ": ", expected_json
        )

    def test_log_empty_context(self):
        """
        Test Case 3: Logs an empty JSON object if the context is empty.
        """
        conf = {'log_key': 'test3', 'target_key_prefix': ''}
        # Arrange
        self.kong_mock.ctx['shared'] = {}
        expected_json = json.dumps({})
        
        # Act
        self.plugin.log(conf)

        # Assert
        self.kong_mock.log.notice.assert_called_once_with(
            "LOG_SHARED_CONTEXT -- ", 'test3', ": ", expected_json
        )

if __name__ == '__main__':
    unittest.main()
