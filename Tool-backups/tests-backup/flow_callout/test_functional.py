import unittest
from unittest.mock import Mock, MagicMock

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()
        # Mock for kong.db.services:select_by_name
        self.db = MagicMock()
        # Mock for kong.service.request
        self.service = Mock()

class FlowCalloutHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        service_object, err = self.kong.db.services.select_by_name(conf['shared_flow_service_name'])
        if not service_object:
            if not conf.get('on_flow_error_continue', False):
                return self.kong.response.exit(conf.get('on_flow_error_status', 500), conf.get('on_flow_error_body', '...'))
            return

        flow_res_status, flow_res_headers, flow_res_body, flow_err = self.kong.service.request(unittest.mock.ANY)
        
        call_succeeded = flow_res_status and flow_res_status < 400
        
        if conf.get('store_flow_response_in_shared_context_key'):
            self.kong.ctx['shared'][conf.get('store_flow_response_in_shared_context_key')] = {
                'status': flow_res_status, 'body': flow_res_body
            }

        if not call_succeeded and not conf.get('on_flow_error_continue', False):
            return self.kong.response.exit(conf.get('on_flow_error_status', 500), conf.get('on_flow_error_body', '...'))


class TestFlowCalloutFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = FlowCalloutHandler(self.kong_mock)

    def test_successful_flow_call(self):
        """
        Test Case 1: A successful call to the internal service proceeds and stores the response.
        """
        conf = {
            'shared_flow_service_name': 'my-shared-flow',
            'store_flow_response_in_shared_context_key': 'flow_result'
        }
        # Arrange: Mock the DB and service call
        self.kong_mock.db.services.select_by_name.return_value = ({'id': 'service-id'}, None)
        self.kong_mock.service.request.return_value = (200, {}, '{"flow": "success"}', None)

        self.plugin.access(conf)

        self.kong_mock.db.services.select_by_name.assert_called_once_with('my-shared-flow')
        self.kong_mock.service.request.assert_called_once()
        self.assertIn('flow_result', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['flow_result']['status'], 200)
        self.assertEqual(self.kong_mock.ctx['shared']['flow_result']['body'], '{"flow": "success"}')
        self.kong_mock.response.exit.assert_not_called()

    def test_failed_flow_call(self):
        """
        Test Case 2: A failed call (e.g., 500 status) terminates the main request.
        """
        conf = {
            'shared_flow_service_name': 'my-shared-flow',
            'on_flow_error_status': 503,
            'on_flow_error_body': 'Shared flow failed'
        }
        # Arrange: Mock the DB and a failed service call
        self.kong_mock.db.services.select_by_name.return_value = ({'id': 'service-id'}, None)
        self.kong_mock.service.request.return_value = (500, {}, 'Internal Error', None)

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_called_once_with(503, 'Shared flow failed')

    def test_shared_flow_service_not_found(self):
        """
        Test Case 3: Terminates request if the shared flow service doesn't exist.
        """
        conf = {
            'shared_flow_service_name': 'non-existent-flow',
            'on_flow_error_status': 500,
            'on_flow_error_body': 'Configuration error'
        }
        # Arrange: Mock the DB call to return no service
        self.kong_mock.db.services.select_by_name.return_value = (None, "not found")

        self.plugin.access(conf)

        self.kong_mock.db.services.select_by_name.assert_called_once_with('non-existent-flow')
        # The internal service request should not even be attempted
        self.kong_mock.service.request.assert_not_called()
        self.kong_mock.response.exit.assert_called_once_with(500, 'Configuration error')

if __name__ == '__main__':
    unittest.main()
