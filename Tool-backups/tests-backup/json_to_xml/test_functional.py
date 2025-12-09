import unittest
from unittest.mock import Mock
import json

# Python implementation of the plugin's logic for generating expected XML
def json_to_xml_py(data, element_name="root", indent_level=0):
    indent_str = "  " * indent_level
    xml = ""
    if isinstance(data, dict):
        xml += f"{indent_str}<{element_name}>\n"
        for key, value in data.items():
            xml += json_to_xml_py(value, key, indent_level + 1)
        xml += f"{indent_str}</{element_name}>\n"
    elif isinstance(data, list):
        for item in data:
            # In the Lua implementation, array items repeat the parent element name
            xml += json_to_xml_py(item, element_name, indent_level)
    else:
        xml += f"{indent_str}<{element_name}>{data}</{element_name}>\n"
    return xml

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.request = Mock()
        self.ctx = {'shared': {}}

class JSONToXMLHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def perform_conversion(self, conf, phase):
        source_json_str = ""
        if conf['source_type'] == 'request_body' and phase == 'access':
            source_json_str = self.kong.request.get_raw_body()
        elif conf['source_type'] == 'response_body' and phase == 'body_filter':
            source_json_str = self.kong.response.get_raw_body()
        elif conf['source_type'] == 'shared_context':
            source_json_str = self.kong.ctx['shared'].get(conf['source_key'])

        if not source_json_str: return

        try:
            parsed_json = json.loads(source_json_str)
            xml_result = '<?xml version="1.0" encoding="UTF-8"?>\n' + json_to_xml_py(parsed_json, conf.get('root_element_name', 'root'))
        except json.JSONDecodeError:
            if not conf.get('on_error_continue', False):
                self.kong.response.exit(conf['on_error_status'], conf['on_error_body'])
            return
        
        if conf['output_type'] == 'request_body' and phase == 'access':
            self.kong.request.set_body(xml_result)
        elif conf['output_type'] == 'response_body' and phase == 'body_filter':
            self.kong.response.set_body(xml_result)
        elif conf['output_type'] == 'shared_context':
            self.kong.ctx['shared'][conf['output_key']] = xml_result

class TestJSONToXMLFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = JSONToXMLHandler(self.kong_mock)
        self.sample_json_str = '{"user": {"name": "John", "id": 123}}'
        self.sample_json_obj = json.loads(self.sample_json_str)

    def test_request_body_transformation(self):
        """
        Test Case 1: Transforms a JSON request body to XML in place.
        """
        conf = {
            'source_type': 'request_body',
            'output_type': 'request_body',
            'root_element_name': 'request'
        }
        self.kong_mock.request.get_raw_body.return_value = self.sample_json_str
        expected_xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + json_to_xml_py(self.sample_json_obj, 'request')

        self.plugin.perform_conversion(conf, 'access')

        self.kong_mock.request.set_body.assert_called_once_with(expected_xml)

    def test_response_body_transformation(self):
        """
        Test Case 2: Transforms a JSON response body to XML in place.
        """
        conf = {
            'source_type': 'response_body',
            'output_type': 'response_body',
            'root_element_name': 'response'
        }
        self.kong_mock.response.get_raw_body.return_value = self.sample_json_str
        expected_xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + json_to_xml_py(self.sample_json_obj, 'response')

        self.plugin.perform_conversion(conf, 'body_filter')

        self.kong_mock.response.set_body.assert_called_once_with(expected_xml)

    def test_shared_context_transformation(self):
        """
        Test Case 3: Converts from a context variable to another context variable.
        """
        conf = {
            'source_type': 'shared_context',
            'source_key': 'input_json',
            'output_type': 'shared_context',
            'output_key': 'output_xml',
            'root_element_name': 'data'
        }
        self.kong_mock.ctx['shared']['input_json'] = self.sample_json_str
        expected_xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + json_to_xml_py(self.sample_json_obj, 'data')

        self.plugin.perform_conversion(conf, 'access') # Phase can be access or body_filter

        self.assertIn('output_xml', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['output_xml'], expected_xml)

if __name__ == '__main__':
    unittest.main()
