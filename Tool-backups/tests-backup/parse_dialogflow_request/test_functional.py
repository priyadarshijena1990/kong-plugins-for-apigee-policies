import unittest
from unittest.mock import Mock
import json

# Python implementation of the simple JSONPath resolver
def resolve_jsonpath_py(data, path):
    if not path: return data
    parts = path.split('.')
    current = data
    for part in parts:
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            return None
    return current

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.request = Mock()
        self.ctx = {'shared': {}}

class ParseDialogflowRequestHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        body = self.kong.request.get_raw_body()
        if not body: return

        try:
            parsed_json = json.loads(body)
        except json.JSONDecodeError:
            if not conf.get('on_parse_error_continue', False):
                return self.kong.response.exit(conf['on_parse_error_status'], conf['on_parse_error_body'])
            return

        for mapping in conf.get('mappings', []):
            value = resolve_jsonpath_py(parsed_json, mapping['dialogflow_jsonpath'])
            if value is not None:
                self.kong.ctx['shared'][mapping['output_key']] = value

class TestParseDialogflowFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = ParseDialogflowRequestHandler(self.kong_mock)
        # Sample Dialogflow request structure
        self.dialogflow_payload = {
            "responseId": "some-id",
            "queryResult": {
                "queryText": "hello",
                "parameters": {
                    "param1": "value1"
                },
                "intent": {
                    "name": "projects/agent/intents/intent-id",
                    "displayName": "Greeting Intent"
                }
            }
        }
        self.dialogflow_str = json.dumps(self.dialogflow_payload)

    def test_extract_multiple_values(self):
        """
        Test Case 1: Correctly extracts multiple values from the Dialogflow JSON.
        """
        conf = {
            'mappings': [
                {'dialogflow_jsonpath': 'queryResult.intent.displayName', 'output_key': 'intent_name'},
                {'dialogflow_jsonpath': 'queryResult.queryText', 'output_key': 'user_query'},
                {'dialogflow_jsonpath': 'queryResult.parameters.param1', 'output_key': 'my_param'}
            ]
        }
        self.kong_mock.request.get_raw_body.return_value = self.dialogflow_str
        
        self.plugin.access(conf)

        self.assertEqual(self.kong_mock.ctx['shared'].get('intent_name'), 'Greeting Intent')
        self.assertEqual(self.kong_mock.ctx['shared'].get('user_query'), 'hello')
        self.assertEqual(self.kong_mock.ctx['shared'].get('my_param'), 'value1')
        self.kong_mock.response.exit.assert_not_called()

    def test_path_not_found(self):
        """
        Test Case 2: Does not add a key to context if the JSONPath is not found.
        """
        conf = {
            'mappings': [
                {'dialogflow_jsonpath': 'queryResult.intent.nonexistentPath', 'output_key': 'should_be_nil'}
            ]
        }
        self.kong_mock.request.get_raw_body.return_value = self.dialogflow_str

        self.plugin.access(conf)

        self.assertNotIn('should_be_nil', self.kong_mock.ctx['shared'])
        self.kong_mock.response.exit.assert_not_called()

    def test_invalid_source_json(self):
        """
        Test Case 3: Terminates request if the source JSON is malformed.
        """
        conf = {
            'on_parse_error_status': 400,
            'on_parse_error_body': 'Invalid JSON',
            'on_parse_error_continue': False
        }
        malformed_json = '{"key": "value"' # Missing closing brace
        self.kong_mock.request.get_raw_body.return_value = malformed_json

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(400, 'Invalid JSON')

if __name__ == '__main__':
    unittest.main()
