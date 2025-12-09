import unittest
from unittest.mock import Mock, MagicMock

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.db = MagicMock()
        self.service = Mock()

class FlowCalloutHandler:
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def access(self, conf):
        service_object, err = self.kong.db.services.select_by_name(conf['shared_flow_service_name'])
        if not service_object:
            return

        flow_res_status, _, _, _ = self.kong.service.request(unittest.mock.ANY)
        
        call_succeeded = flow_res_status and flow_res_status < 400
        
        if conf.get('store_flow_response_in_shared_context_key'):
             self.kong.ctx['shared'][conf.get('store_flow_response_in_shared_context_key')] = "some data"

        if not call_succeeded and not conf.get('on_flow_error_continue', False):
            return self.kong.response.exit(500, "Error")

class TestFlowCalloutUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = FlowCalloutHandler(self.kong_mock)
        # Assume the service is always found for these unit tests
        self.kong_mock.db.services.select_by_name.return_value = ({'id': 'service-id'}, None)

    def test_flow_call_failure_with_continue_on_error(self):
        """
        Test Case 1: Request proceeds on flow call failure if on_flow_error_continue is true.
        """
        conf = {
            'shared_flow_service_name': 'my-shared-flow',
            'on_flow_error_continue': True # Key for this test
        }
        # Arrange: Mock a failed service call
        self.kong_mock.service.request.return_value = (500, {}, 'Error', None)

        self.plugin.access(conf)

        # Assert: The request was not terminated
        self.kong_mock.response.exit.assert_not_called()

    def test_no_response_storing(self):
        """
        Test Case 2: Nothing is stored in context if store_flow_response is not configured.
        """
        conf = {
            'shared_flow_service_name': 'my-shared-flow'
            # 'store_flow_response_in_shared_context_key' is omitted
        }
        # Arrange: Mock a successful service call
        self.kong_mock.service.request.return_value = (200, {}, 'Success', None)

        self.plugin.access(conf)

        # Assert: The shared context remains empty
        self.assertEqual(len(self.kong_mock.ctx['shared']), 0)
        self.kong_mock.response.exit.assert_not_called()


if __name__ == '__main__':
    unittest.main()
