import unittest
from unittest.mock import Mock

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
            # Using eval for the mock. Safe because we control the test inputs.
            condition_result = eval(conf['lua_condition'], {'kong': self.kong})
        except Exception as e:
            self.kong.log.err("AssertCondition: Error evaluating Lua condition: ", str(e))
            return self.kong.response.exit(500, "Internal Server Error: Error during condition evaluation.")

        if not condition_result:
            self.kong.log.warn("AssertCondition: Condition '", conf['lua_condition'], "' evaluated to false. Raising fault.")
            headers = conf.get('on_assertion_failure_headers', {}).copy() # Use copy to avoid modifying conf
            
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
            return self.kong.response.exit(response_opts['status'], response_opts['body'], response_opts['headers'])

        self.kong.log.debug("AssertCondition: Condition '", conf['lua_condition'], "' evaluated to true. Request proceeding.")

class TestAssertConditionUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = AssertConditionHandler(self.kong_mock)

    def test_default_failure_response(self):
        """
        Test 1: Check for default status (400) and body on failure.
        """
        conf = {
            'lua_condition': "False"
            # No failure status or body specified
        }

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once()
        args, _ = self.kong_mock.response.exit.call_args
        self.assertEqual(args[0], 400) # Default status
        self.assertEqual(args[1], "Assertion failed: Invalid request.") # Default body

    def test_custom_headers_on_failure(self):
        """
        Test 2: Ensure custom headers are included in the failure response.
        """
        conf = {
            'lua_condition': "False",
            'on_assertion_failure_headers': {'X-Custom-Header': 'Failure'}
        }

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once()
        args, _ = self.kong_mock.response.exit.call_args
        headers = args[2]
        self.assertIn('X-Custom-Header', headers)
        self.assertEqual(headers['X-Custom-Header'], 'Failure')

    def test_plain_text_content_type(self):
        """
        Test 3: Check for correct Content-Type for a non-JSON body.
        """
        conf = {
            'lua_condition': "False",
            'on_assertion_failure_body': "This is a plain text error."
        }

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once()
        args, _ = self.kong_mock.response.exit.call_args
        headers = args[2]
        self.assertIn('Content-Type', headers)
        self.assertEqual(headers['Content-Type'], 'text/plain')

if __name__ == '__main__':
    unittest.main()
