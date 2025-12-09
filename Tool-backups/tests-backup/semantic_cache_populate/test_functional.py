import unittest
from unittest.mock import Mock
import json

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()
        self.cache = Mock()
        self.json = Mock() # Mock for kong.json.encode

class SemanticCachePopulateHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def resolve_fragment_value(self, fragment_ref):
        if fragment_ref == "request.uri":
            return self.kong.request.get_uri()
        elif fragment_ref.startswith("request.headers."):
            return self.kong.request.get_header(fragment_ref[16:])
        elif fragment_ref.startswith("shared_context."):
            value = self.kong.ctx['shared'].get(fragment_ref[15:])
            if isinstance(value, dict): # Simulate JSON encoding for tables
                return self.kong.json.encode(value)
            return value
        return fragment_ref # Literal

    def body_filter(self, conf):
        key_parts = []
        if conf.get('cache_key_prefix'):
            key_parts.append(conf['cache_key_prefix'])
        
        for frag in conf.get('cache_key_fragments', []):
            value = self.resolve_fragment_value(frag)
            if value:
                key_parts.append(str(value))
        
        cache_key = ":".join(key_parts)
        
        if not cache_key:
            return

        cache_content = None
        if conf['source'] == 'response_body':
            cache_content = self.kong.response.get_raw_body()
        elif conf['source'] == 'shared_context':
            cache_content = self.kong.ctx['shared'].get(conf['shared_context_key'])
            if isinstance(cache_content, dict): # Simulate JSON encoding for tables
                cache_content = self.kong.json.encode(cache_content)
        
        if not cache_content:
            return

        self.kong.cache.set(cache_key, cache_content, conf['cache_ttl'])


class TestSemanticCachePopulateFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = SemanticCachePopulateHandler(self.kong_mock)
        self.base_conf = {
            'cache_key_prefix': 'my-cache',
            'cache_key_fragments': ['request.uri'],
            'cache_ttl': 60
        }
        self.kong_mock.request.get_uri.return_value = '/api/resource'
        self.kong_mock.json.encode.side_effect = json.dumps # Mock json.encode to use python's json.dumps

    def test_populate_from_response_body(self):
        """
        Test Case 1: Populates cache with content from the response body.
        """
        conf = {
            **self.base_conf,
            'source': 'response_body',
        }
        response_body = '{"status": "ok", "data": 123}'
        self.kong_mock.response.get_raw_body.return_value = response_body
        
        self.plugin.body_filter(conf)

        expected_key = "my-cache:/api/resource"
        self.kong_mock.cache.set.assert_called_once_with(expected_key, response_body, 60)

    def test_populate_from_shared_context(self):
        """
        Test Case 2: Populates cache with content from shared context.
        """
        conf = {
            **self.base_conf,
            'source': 'shared_context',
            'shared_context_key': 'data_to_cache'
        }
        data_from_context = {'key': 'value', 'count': 5}
        self.kong_mock.ctx['shared']['data_to_cache'] = data_from_context
        
        self.plugin.body_filter(conf)

        expected_key = "my-cache:/api/resource"
        # Since the plugin JSON-encodes tables from shared_context
        expected_content = json.dumps(data_from_context) 
        self.kong_mock.cache.set.assert_called_once_with(expected_key, expected_content, 60)

    def test_empty_cache_content(self):
        """
        Test Case 3: Does not populate cache if content source is empty.
        """
        conf = {
            **self.base_conf,
            'source': 'response_body',
        }
        self.kong_mock.response.get_raw_body.return_value = '' # Empty body

        self.plugin.body_filter(conf)

        self.kong_mock.cache.set.assert_not_called()


if __name__ == '__main__':
    unittest.main()
