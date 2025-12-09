import unittest
from unittest.mock import Mock, patch

# Mocking the Kong environment
class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}

    def reset(self):
        self.log.reset_mock()
        self.response.reset_mock()
        self.ctx['shared'].clear()

# A python representation of the lua plugin for testing purposes
class AssertConditionHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        try:
            # In Python, we can use eval for a similar purpose as 'load' in Lua for this test
            # WARNING: In a real application, using eval with untrusted input is dangerous.
            # Here, it's safe as we control the input in the tests.
            condition_result = eval(conf['lua_condition'], {'kong': self.kong})
        except Exception as e:
            self.kong.log.err("AssertCondition: Error evaluating Lua condition: ", str(e))
            return self.kong.response.exit(500, "Internal Server Error: Error during condition evaluation.")

        if not condition_result:
            self.kong.log.warn("AssertCondition: Condition '", conf['lua_condition'], "' evaluated to false. Raising fault.")
            headers = conf.get('on_assertion_failure_headers', {})
            
            if 'on_assertion_failure_body' in conf and "Content-Type" not in headers and "content-type" not in headers:
                body = conf['on_assertion_failure_body']
                if body.startswith('{') or body.startswith('['):
                    headers["Content-Type"] = "application/json"
                else:
                    headers["Content-Type"] = "text/plain"

            response_opts = {
                'status': conf.get('on_assertion_failure_status', 400),
                'body': conf.get('on_assertion_failure_body', "Assertion failed: Invalid request."),
                'headers': headers,
            }
            # The actual kong.response.exit can take a dictionary in some versions
            return self.kong.response.exit(response_opts['status'], response_opts['body'], response_opts['headers'])

        self.kong.log.debug("AssertCondition: Condition '", conf['lua_condition'], "' evaluated to true. Request proceeding.")

class TestAssertConditionFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = AssertConditionHandler(self.kong_mock)

    def test_condition_true(self):
        """
        Test Case 1: Condition evaluates to true, request should proceed.
        """
        self.kong_mock.ctx['shared']['is_valid'] = True
        conf = {
            'lua_condition': "kong.ctx['shared']['is_valid'] == True"
        }

        self.plugin.access(conf)

        # Assert that exit was not called
        self.kong_mock.response.exit.assert_not_called()

    def test_condition_false(self):
        """
        Test Case 2: Condition evaluates to false, a fault should be raised.
        """
        conf = {
            'lua_condition': "1 == 2",
            'on_assertion_failure_status': 403,
            'on_assertion_failure_body': '{"error": "Forbidden"}'
        }

        self.plugin.access(conf)

        # Assert that exit was called with the correct parameters
        self.kong_mock.response.exit.assert_called_once()
        args, _ = self.kong_mock.response.exit.call_args
        self.assertEqual(args[0], 403)
        self.assertEqual(args[1], '{"error": "Forbidden"}')
        # Check if Content-Type was auto-detected and set
        self.assertIn('Content-Type', args[2])
        self.assertEqual(args[2]['Content-Type'], 'application/json')

    def test_invalid_lua_condition(self):
        """
        Test Case 3: An invalid Lua expression should result in a 500 error.
        Note: In our Python mock, this tests for a Python syntax error.
        """
        conf = {
            'lua_condition': "invalid syntax here"
        }

        self.plugin.access(conf)

        # Assert that exit was called with a 500 status
        self.kong_mock.response.exit.assert_called_once_with(500, "Internal Server Error: Error during condition evaluation.")

if __name__ == '__main__':
    unittest.main()
