import unittest
from unittest.mock import Mock

# Reusing the Python implementation from the functional tests
from tests.reset_quota.test_functional import ResetQuotaHandler, KongMock

class TestResetQuotaUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = ResetQuotaHandler(self.kong_mock)
        self.base_conf = {
            'admin_api_url': 'http://localhost:8001',
            'rate_limiting_plugin_id': 'abc-123-def-456',
            'on_error_status': 400,
            'on_error_body': 'Bad Request'
        }

    def test_missing_scope_id(self):
        """
        Test Case 1: Terminates request if a required scope_id is not found.
        """
        conf = {
            **self.base_conf,
            'scope_type': 'consumer',
            'scope_id_source_type': 'query',
            'scope_id_source_name': 'consumer_id'
        }
        # Arrange: Mock the source to return None
        self.kong_mock.request.get_query_arg.return_value = None
        
        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.http.client.go.assert_not_called()
        self.kong_mock.response.exit.assert_called_once_with(400, 'Bad Request')

    def test_on_error_continue_true(self):
        """
        Test Case 2: Request proceeds on Admin API failure if on_error_continue is true.
        """
        conf = {
            **self.base_conf,
            'on_error_continue': True,
        }
        # Arrange: Mock a failure from the Admin API
        self.kong_mock.http.client.go.return_value = (Mock(status=500), None)
        
        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.http.client.go.assert_called_once()
        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
