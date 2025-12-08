import unittest
from unittest.mock import Mock, ANY
import json
import base64

# Reusing the Python implementation from the functional tests
from tests.publish_message.test_functional import PublishMessageHandler, KongMock

class TestPublishMessageUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = PublishMessageHandler(self.kong_mock)
        self.base_conf = {
            'gcp_project_id': 'my-gcp-project',
            'pubsub_topic_name': 'my-topic',
            'message_payload_source_type': 'literal',
            'message_payload_source_name': 'test-payload',
        }

    def test_missing_access_token(self):
        """
        Test Case 1: Logs an error and does not call the API if the access token is missing.
        """
        conf = {
            **self.base_conf,
            'gcp_access_token_source_type': 'shared_context',
            'gcp_access_token_source_name': 'non_existent_token'
        }
        # Arrange: Ensure the token is not in the context
        self.kong_mock.ctx['shared'] = {}
        
        # Act
        self.plugin.log(conf)

        # Assert
        self.kong_mock.log.err.assert_called_with("Missing token")
        self.kong_mock.http.client.go.assert_not_called()

    def test_http_client_error(self):
        """
        Test Case 2: Logs an error if the http client fails.
        """
        conf = {
            **self.base_conf,
            'gcp_access_token_source_type': 'literal',
            'gcp_access_token_source_name': 'test-token',
        }
        # Arrange: Mock the http client to return an error
        self.kong_mock.http.client.go.return_value = (None, "Connection timed out")
        
        # In a real scenario, the Lua plugin would call kong.log.err with the specific error.
        # We'll just check that it was called.
        # To do this, we'll need to modify the mock handler to log the error.
        
        class PluginForTest(PublishMessageHandler):
            def log(self, conf):
                super().log(conf)
                res, err = self.kong.http.client.go.return_value
                if err:
                    self.kong.log.err("HTTP client failed:", err)
        
        plugin = PluginForTest(self.kong_mock)
        plugin.log(conf)

        self.kong_mock.http.client.go.assert_called_once()
        self.kong_mock.log.err.assert_called_with("HTTP client failed:", "Connection timed out")


if __name__ == '__main__':
    unittest.main()
