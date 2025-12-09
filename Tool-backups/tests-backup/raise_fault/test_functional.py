import unittest
from unittest.mock import Mock

# Using a similar mock structure as assert-condition tests
class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}

class RaiseFaultHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        should_raise = True
        if conf.get('lua_condition'):
            # In Python, we use eval for a similar purpose as 'load' in Lua for this test
            # This is safe as we control the inputs in the tests.
            try:
                condition_result = eval(conf['lua_condition'], {'kong': self.kong})
                if not condition_result:
                    should_raise = False
            except Exception:
                # The real plugin logs an error and continues, so we don't raise here.
                should_raise = False

        if should_raise:
            headers = conf.get('headers', {})
            body = conf.get('body')
            # Simplified content-type logic for test
            if body and 'Content-Type' not in headers and 'content-type' not in headers:
                if body.startswith('{') or body.startswith('['):
                    headers['Content-Type'] = 'application/json'

            return self.kong.response.exit(conf['status'], body, headers)

class TestRaiseFaultFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = RaiseFaultHandler(self.kong_mock)

    def test_unconditional_fault(self):
        """
        Test Case 1: Fault is always raised when no condition is provided.
        """
        conf = {
            'status': 403,
            'body': '{"error": "Forbidden"}'
        }
        
        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once()
        args, _ = self.kong_mock.response.exit.call_args
        self.assertEqual(args[0], 403)
        self.assertEqual(args[1], '{"error": "Forbidden"}')
        self.assertEqual(args[2]['Content-Type'], 'application/json')

    def test_conditional_fault_is_raised(self):
        """
        Test Case 2: Fault is raised when the condition is true.
        """
        self.kong_mock.ctx['shared']['is_error'] = True
        conf = {
            'status': 500,
            'body': 'Server error triggered.',
            'lua_condition': "kong.ctx['shared']['is_error'] == True"
        }

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(500, 'Server error triggered.', {})

    def test_conditional_fault_is_skipped(self):
        """
        Test Case 3: Fault is NOT raised when the condition is false.
        """
        self.kong_mock.ctx['shared']['is_error'] = False
        conf = {
            'status': 500,
            'body': 'Server error triggered.',
            'lua_condition': "kong.ctx['shared']['is_error'] == True"
        }

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
