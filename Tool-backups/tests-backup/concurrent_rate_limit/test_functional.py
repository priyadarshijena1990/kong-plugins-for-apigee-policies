import unittest
from unittest.mock import Mock, MagicMock

# Mocking the Kong environment
class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        # Simulate the shared dictionary with a simple dict
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
        self.counters = self.kong.shared.get('concurrent_limit_counters')

    def get_counter_key(self, conf):
        # Simplified key retrieval for testing
        if conf['counter_key_source_type'] == 'header':
            return self.kong.request.get_header(conf['counter_key_source_name'])
        return "global"

    def access(self, conf):
        if not self.counters:
            return

        counter_key = self.get_counter_key(conf)
        self.kong.ctx['shared']['concurrent_limit_key'] = counter_key

        current_count, _ = self.counters.incr(counter_key, 1)

        if current_count > conf['rate']:
            self.counters.incr(counter_key, -1) # Decrement since it's rejected
            return self.kong.response.exit(conf.get('on_limit_exceeded_status', 429),
                                            conf.get('on_limit_exceeded_body', "Too Many Concurrent Requests."))
    
    def log(self, conf):
        if not self.counters:
            return

        counter_key = self.kong.ctx['shared'].get('concurrent_limit_key')
        if counter_key:
            self.counters.incr(counter_key, -1)

class TestConcurrentRateLimitFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        # Mock the behavior of the shared dictionary's incr method
        self.counters_state = {}
        def incr_mock(key, val):
            self.counters_state.setdefault(key, 0)
            self.counters_state[key] += val
            return self.counters_state[key], None
        
        self.kong_mock.shared['concurrent_limit_counters'].incr.side_effect = incr_mock
        self.plugin = ConcurrentRateLimitHandler(self.kong_mock)

    def test_limit_not_exceeded(self):
        """
        Test Case 1: A single request should be allowed.
        """
        conf = {'rate': 5, 'counter_key_source_type': 'header', 'counter_key_source_name': 'X-User'}
        self.kong_mock.request.get_header.return_value = 'user1'

        # access phase
        self.plugin.access(conf)

        # Assert request was allowed
        self.kong_mock.response.exit.assert_not_called()
        self.assertEqual(self.counters_state['user1'], 1)

    def test_limit_exceeded(self):
        """
        Test Case 2: Subsequent requests exceeding the limit should be blocked.
        """
        conf = {'rate': 1, 'counter_key_source_type': 'header', 'counter_key_source_name': 'X-User'}
        self.kong_mock.request.get_header.return_value = 'user2'

        # First request (should pass)
        self.plugin.access(conf)
        self.kong_mock.response.exit.assert_not_called()
        self.assertEqual(self.counters_state['user2'], 1)

        # Second request (should be rejected)
        self.plugin.access(conf)
        self.kong_mock.response.exit.assert_called_once_with(429, "Too Many Concurrent Requests.")
        # Counter should be decremented back to 1 after rejection
        self.assertEqual(self.counters_state['user2'], 1)

    def test_correct_decrement_on_log(self):
        """
        Test Case 3: Counter is decremented in the log phase, allowing new requests.
        """
        conf = {'rate': 1, 'counter_key_source_type': 'header', 'counter_key_source_name': 'X-User'}
        self.kong_mock.request.get_header.return_value = 'user3'

        # --- Request 1 ---
        # Access phase
        self.plugin.access(conf)
        self.kong_mock.response.exit.assert_not_called()
        self.assertEqual(self.counters_state['user3'], 1)
        # It has a stored key for the log phase
        self.assertEqual(self.kong_mock.ctx['shared']['concurrent_limit_key'], 'user3')

        # Log phase (simulating request completion)
        self.plugin.log(conf)
        self.assertEqual(self.counters_state['user3'], 0)

        # --- Request 2 (should now be allowed) ---
        self.kong_mock.response.exit.reset_mock() # Reset mock for the new request
        self.plugin.access(conf)
        self.kong_mock.response.exit.assert_not_called()
        self.assertEqual(self.counters_state['user3'], 1)

if __name__ == '__main__':
    unittest.main()
