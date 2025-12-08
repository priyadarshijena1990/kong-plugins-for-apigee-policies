import unittest
from unittest.mock import Mock, MagicMock

# Mocking the Kong environment
class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.shared = {'concurrent_limit_counters': MagicMock()}
        self.ctx = {'shared': {}}
        self.request = Mock()

    def reset(self):
        self.log.reset_mock()
        self.response.reset_mock()
        self.shared['concurrent_limit_counters'].reset_mock()
        self.ctx['shared'].clear()
        self.request.reset_mock()

# Python representation of the Lua plugin for testing
class ConcurrentRateLimitHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock
        # Allow the counters to be missing for one test case
        self.counters = self.kong.shared.get('concurrent_limit_counters')

    def get_counter_key(self, conf):
        key_value = None
        if conf['counter_key_source_type'] == 'header':
            key_value = self.kong.request.get_header(conf['counter_key_source_name'])
        elif conf['counter_key_source_type'] == 'query':
            key_value = self.kong.request.get_query_arg(conf['counter_key_source_name'])
        
        return key_value if key_value else "global"

    def access(self, conf):
        if not self.counters:
            self.kong.log.err("ConcurrentRateLimit: Shared dictionary 'concurrent_limit_counters' is not configured. Concurrent limiting will not work.")
            return

        counter_key = self.get_counter_key(conf)
        self.kong.ctx['shared']['concurrent_limit_key'] = counter_key
        self.counters.incr(counter_key, 1)
        # Other logic is not needed for these unit tests
    
    def log(self, conf):
        pass # Not needed for these tests

class TestConcurrentRateLimitUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.counters_state = {}
        def incr_mock(key, val):
            self.counters_state.setdefault(key, 0)
            self.counters_state[key] += val
            return self.counters_state[key], None
        
        self.kong_mock.shared['concurrent_limit_counters'].incr.side_effect = incr_mock

    def test_global_counter(self):
        """
        Test Case 1: Defaults to a 'global' counter key if no specific key is found.
        """
        conf = {'counter_key_source_type': 'header', 'counter_key_source_name': 'X-Non-Existent-Header'}
        self.kong_mock.request.get_header.return_value = None
        plugin = ConcurrentRateLimitHandler(self.kong_mock)
        
        plugin.access(conf)

        # Assert that the key in the shared context is 'global'
        self.assertEqual(self.kong_mock.ctx['shared']['concurrent_limit_key'], 'global')
        # Assert that the 'global' counter was incremented
        self.assertIn('global', self.counters_state)
        self.assertEqual(self.counters_state['global'], 1)

    def test_no_shared_dictionary(self):
        """
        Test Case 2: Plugin logs an error if the shared dictionary is missing.
        """
        # Remove the dictionary for this test
        self.kong_mock.shared.pop('concurrent_limit_counters', None)
        plugin = ConcurrentRateLimitHandler(self.kong_mock)
        
        plugin.access({}) # Conf doesn't matter here

        # Assert an error was logged and no exit was called
        self.kong_mock.log.err.assert_called_with("ConcurrentRateLimit: Shared dictionary 'concurrent_limit_counters' is not configured. Concurrent limiting will not work.")
        self.kong_mock.response.exit.assert_not_called()

    def test_key_from_query_parameter(self):
        """
        Test Case 3: Counter key is correctly extracted from a query parameter.
        """
        conf = {'counter_key_source_type': 'query', 'counter_key_source_name': 'api_key'}
        self.kong_mock.request.get_query_arg.return_value = 'my-api-key'
        plugin = ConcurrentRateLimitHandler(self.kong_mock)

        plugin.access(conf)

        # Assert the key was extracted correctly
        self.assertEqual(self.kong_mock.ctx['shared']['concurrent_limit_key'], 'my-api-key')
        self.assertIn('my-api-key', self.counters_state)
        self.assertEqual(self.counters_state['my-api-key'], 1)
        self.kong_mock.request.get_query_arg.assert_called_with('api_key')

if __name__ == '__main__':
    unittest.main()
