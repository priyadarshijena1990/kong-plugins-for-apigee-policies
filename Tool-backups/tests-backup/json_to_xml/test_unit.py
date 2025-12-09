import unittest
from unittest.mock import Mock
import json

# Reusing the Python implementation from the functional tests
from tests.json_to_xml.test_functional import JSONToXMLHandler, KongMock, json_to_xml_py

class TestJSONToXMLUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = JSONToXMLHandler(self.kong_mock)
        self.base_conf = {
            'source_type': 'request_body',
            'output_type': 'request_body',
            'root_element_name': 'root',
            'on_error_status': 400,
            'on_error_body': 'Conversion Failed',
            'on_error_continue': False
        }

    def test_json_with_array(self):
        """
        Test Case 1: Correctly converts a JSON object containing an array.
        """
        conf = {**self.base_conf, 'root_element_name': 'data'}
        json_with_array_str = '{"products": [{"id": 1}, {"id": 2}]}'
        json_with_array_obj = json.loads(json_with_array_str)
        self.kong_mock.request.get_raw_body.return_value = json_with_array_str
        
        # Manually generate expected XML to be precise about array handling
        expected_xml = ('<?xml version="1.0" encoding="UTF-8"?>\n' 
                        '<data>\n' 
                        '  <products>\n' 
                        '    <id>1</id>\n' 
                        '  </products>\n' 
                        '  <products>\n' 
                        '    <id>2</id>\n' 
                        '  </products>\n' 
                        '</data>\n')

        self.plugin.perform_conversion(conf, 'access')

        self.kong_mock.request.set_body.assert_called_once_with(expected_xml)

    def test_invalid_source_json(self):
        """
        Test Case 2: Terminates the request if the source JSON is malformed.
        """
        conf = {**self.base_conf}
        malformed_json = '{"key": "value"' # Missing closing brace
        self.kong_mock.request.get_raw_body.return_value = malformed_json

        self.plugin.perform_conversion(conf, 'access')

        self.kong_mock.response.exit.assert_called_once_with(400, 'Conversion Failed')

    def test_on_error_continue_true(self):
        """
        Test Case 3: Does not terminate request on error if on_error_continue is true.
        """
        conf = {**self.base_conf, 'on_error_continue': True}
        malformed_json = '{"key": "value"' # Missing closing brace
        self.kong_mock.request.get_raw_body.return_value = malformed_json

        self.plugin.perform_conversion(conf, 'access')

        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
