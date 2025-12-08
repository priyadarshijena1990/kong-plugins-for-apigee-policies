import unittest
from unittest.mock import Mock, ANY
import sys
import os

# Add the project root to the Python path to allow imports from the 'tests' package
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, project_root)

# Reusing the Python implementation from the functional tests
from tests.semantic_cache_lookup.test_functional import SemanticCacheLookupHandler, KongMock

class TestSemanticCacheLookupUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = SemanticCacheLookupHandler(self.kong_mock)
        self.base_conf = {
            'cache_key_prefix': 'my-cache',
            'cache_key_fragments': ['request.uri'],
            'cache_hit_header_name': 'X-Cache'
        }
        self.kong_mock.request.get_uri.return_value = '/api/resource'

    def test_empty_cache_key(self):
        """
        Test Case 1: If the constructed cache key is empty, kong.cache.get() is not called.
        """
        conf = {
            'cache_key_prefix': '',
            'cache_key_fragments': ['shared_context.non_existent_key'], # Will resolve to None
            'cache_hit_header_name': 'X-Cache'
        }
        self.kong_mock.ctx['shared'] = {} # Ensure no value for non_existent_key

        self.plugin.access(conf)

        self.kong_mock.cache.get.assert_not_called()
        self.kong_mock.response.set_header.assert_called_once_with(ANY, 'MISS')
        self.kong_mock.response.exit.assert_not_called()

    def test_custom_cache_hit_headers(self):
        """
        Test Case 2: Custom headers are included in the response on cache hit.
        """
        conf = {
            **self.base_conf,
            'respond_from_cache_on_hit': True,
            'cache_hit_status': 200,
            'cache_hit_headers': {'X-Cache-Generated': 'true', 'X-Custom-Header': 'value'}
        }
        cached_content = 'cached response'
        self.kong_mock.cache.get.return_value = (cached_content, None)
        
        self.plugin.access(conf)

        # Check if set_header was called for custom headers
        self.kong_mock.response.set_header.assert_any_call('X-Cache-Generated', 'true')
        self.kong_mock.response.set_header.assert_any_call('X-Custom-Header', 'value')
        
        # Check that exit was called with the cached content and status
        self.kong_mock.response.exit.assert_called_once_with(200, cached_content)


if __name__ == '__main__':
    unittest.main()
