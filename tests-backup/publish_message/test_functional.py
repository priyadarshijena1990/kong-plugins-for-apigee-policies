import unittest
from unittest.mock import Mock, ANY
import json
import base64

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.http = Mock()
        self.ctx = {'shared': {}}

class PublishMessageHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def get_value_from_source(self, source_type, source_name):
        if source_type == 'shared_context':
            return self.kong.ctx['shared'].get(source_name)
        elif source_type == 'literal':
            return source_name
        return None

    def log(self, conf):
        access_token = self.get_value_from_source(conf['gcp_access_token_source_type'], conf['gcp_access_token_source_name'])
        if not access_token:
            self.kong.log.err("Missing token")
            return
            
        payload = self.get_value_from_source(conf['message_payload_source_type'], conf['message_payload_source_name']) or ""
        
        url = f"https://pubsub.googleapis.com/v1/projects/{conf['gcp_project_id']}/topics/{conf['pubsub_topic_name']}:publish"
        
        message_body = {
            'messages': [{
                'data': base64.b64encode(str(payload).encode('utf-8')).decode('utf-8')
            }]
        }
        if conf.get('message_attributes'):
            message_body['messages'][0]['attributes'] = conf['message_attributes']

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {access_token}",
        }
        
        self.kong.http.client.go(url, {'headers': headers, 'body': json.dumps(message_body), 'method': 'POST', 'timeout': ANY, 'connect_timeout': ANY, 'ssl_verify': ANY})

class TestPublishMessageFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = PublishMessageHandler(self.kong_mock)
        self.base_conf = {
            'gcp_project_id': 'my-gcp-project',
            'pubsub_topic_name': 'my-topic',
            'gcp_access_token_source_type': 'literal',
            'gcp_access_token_source_name': 'test-token',
        }

    def test_successful_publish(self):
        """
        Test Case 1: Constructs and sends a correct Pub/Sub message.
        """
        conf = {
            **self.base_conf,
            'message_payload_source_type': 'literal',
            'message_payload_source_name': 'Hello Pub/Sub'
        }
        
        # Act
        self.plugin.log(conf)

        # Assert
        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        
        # Check URL
        expected_url = "https://pubsub.googleapis.com/v1/projects/my-gcp-project/topics/my-topic:publish"
        self.assertEqual(call_args[0], expected_url)

        # Check Body
        sent_opts = call_args[1]
        sent_body = json.loads(sent_opts['body'])
        expected_b64_data = base64.b64encode(b'Hello Pub/Sub').decode('utf-8')
        self.assertEqual(sent_body['messages'][0]['data'], expected_b64_data)
        
        # Check Headers
        self.assertEqual(sent_opts['headers']['Authorization'], 'Bearer test-token')

    def test_publish_with_attributes(self):
        """
        Test Case 2: Correctly includes message attributes in the request.
        """
        conf = {
            **self.base_conf,
            'message_payload_source_type': 'literal',
            'message_payload_source_name': 'Payload with attributes',
            'message_attributes': {
                'source': 'kong-gateway',
                'request_id': 'xyz-123'
            }
        }
        
        # Act
        self.plugin.log(conf)

        # Assert
        self.kong_mock.http.client.go.assert_called_once()
        call_args = self.kong_mock.http.client.go.call_args[0]
        sent_body = json.loads(call_args[1]['body'])

        self.assertIn('attributes', sent_body['messages'][0])
        self.assertEqual(sent_body['messages'][0]['attributes']['source'], 'kong-gateway')
        self.assertEqual(sent_body['messages'][0]['attributes']['request_id'], 'xyz-123')

if __name__ == '__main__':
    unittest.main()
