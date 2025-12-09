import unittest
from unittest.mock import Mock
import json

# Reusing the Python implementation from the functional tests
from tests.semantic_cache_populate.test_functional import SemanticCachePopulateHandler, KongMock

class TestSemanticCachePopulateUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = SemanticCachePopulateHandler(self.kong_mock)
        self.base_conf = {
            'cache_key_prefix': 'my-cache',
            'cache_key_fragments': ['request.uri'],
            'cache_ttl': 60,
            'source': 'response_body',
        }
        self.kong_mock.request.get_uri.return_value = '/api/resource'
        self.kong_mock.response.get_raw_body.return_value = 'some content'
        self.kong_mock.json.encode.side_effect = json.dumps

    def test_empty_cache_key(self):
        """
        Test Case 1: If the constructed cache key is empty, kong.cache.set() is not called.
        """
        conf = {
            **self.base_conf,
            'cache_key_prefix': '',
            'cache_key_fragments': ['shared_context.non_existent_key'] # Will result in empty key parts
        }
        self.kong_mock.ctx['shared'] = {} # Ensure no value for non_existent_key

        self.plugin.body_filter(conf)

        self.kong_mock.cache.set.assert_not_called()

    def test_shared_context_key_not_found(self):
        """
        Test Case 2: If source is shared_context but the key is not found, cache is not populated.
        """
        conf = {
            **self.base_conf,
            'source': 'shared_context',
            'shared_context_key': 'non_existent_data_key'
        }
        self.kong_mock.ctx['shared'] = {} # Ensure key is not present

        self.plugin.body_filter(conf)

        self.kong_mock.cache.set.assert_not_called()

if __name__ == '__main__':
    unittest.main()
