import unittest
from unittest.mock import Mock

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()
        self.cache = Mock()

class SemanticCacheLookupHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def resolve_fragment_value(self, fragment_ref):
        if fragment_ref == "request.uri":
            return self.kong.request.get_uri()
        elif fragment_ref.startswith("request.headers."):
            return self.kong.request.get_header(fragment_ref[16:])
        elif fragment_ref.startswith("shared_context."):
            return self.kong.ctx['shared'].get(fragment_ref[15:])
        return fragment_ref # Literal

    def access(self, conf):
        key_parts = []
        if conf.get('cache_key_prefix'):
            key_parts.append(conf['cache_key_prefix'])
        
        for frag in conf.get('cache_key_fragments', []):
            value = self.resolve_fragment_value(frag)
            if value:
                key_parts.append(str(value))
        
        cache_key = ":".join(key_parts)
        
        if not cache_key:
            # An empty key is a cache miss. Set header and continue.
            self.kong.response.set_header(conf.get('cache_hit_header_name', 'X-Cache-Status'), "MISS")
            return

        cached_content, err = self.kong.cache.get(cache_key)
        
        if cached_content:
            # Set the main cache status header
            self.kong.response.set_header(conf.get('cache_hit_header_name', 'X-Cache-Status'), "HIT")

            # Set any additional custom headers for a cache hit
            for key, value in conf.get('cache_hit_headers', {}).items():
                self.kong.response.set_header(key, value)

            if conf.get('assign_to_shared_context_key'):
                self.kong.ctx['shared'][conf['assign_to_shared_context_key']] = cached_content
            
            if conf.get('respond_from_cache_on_hit', True):
                return self.kong.response.exit(conf.get('cache_hit_status', 200), cached_content)
            # If not responding from cache, we've already set the headers, so we just continue
        else:
            self.kong.response.set_header(conf.get('cache_hit_header_name', 'X-Cache-Status'), "MISS")

class TestSemanticCacheLookupFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = SemanticCacheLookupHandler(self.kong_mock)
        self.base_conf = {
            'cache_key_prefix': 'my-cache',
            'cache_key_fragments': ['request.uri', 'request.headers.Accept'],
            'cache_hit_header_name': 'X-Cache'
        }
        self.kong_mock.request.get_uri.return_value = '/api/resource'
        self.kong_mock.request.get_header.return_value = 'application/json'

    def test_cache_hit_respond_from_cache(self):
        """
        Test Case 1: Serves cached content directly on a cache hit.
        """
        conf = {
            **self.base_conf,
            'respond_from_cache_on_hit': True,
            'cache_hit_status': 200
        }
        cached_response_body = '{"data": "from cache"}'
        self.kong_mock.cache.get.return_value = (cached_response_body, None)
        
        self.plugin.access(conf)

        expected_key = "my-cache:/api/resource:application/json"
        self.kong_mock.cache.get.assert_called_once_with(expected_key)
        self.kong_mock.response.set_header.assert_called_once_with('X-Cache', 'HIT')
        self.kong_mock.response.exit.assert_called_once_with(200, cached_response_body)

    def test_cache_hit_continue_processing(self):
        """
        Test Case 2: Stores cached content in shared context and continues processing.
        """
        conf = {
            **self.base_conf,
            'respond_from_cache_on_hit': False, # Key for this test
            'assign_to_shared_context_key': 'cached_data'
        }
        cached_content = 'some string data'
        self.kong_mock.cache.get.return_value = (cached_content, None)

        self.plugin.access(conf)

        expected_key = "my-cache:/api/resource:application/json"
        self.kong_mock.cache.get.assert_called_once_with(expected_key)
        self.assertEqual(self.kong_mock.ctx['shared']['cached_data'], cached_content)
        self.kong_mock.response.set_header.assert_called_once_with('X-Cache', 'HIT')
        self.kong_mock.response.exit.assert_not_called()

    def test_cache_miss(self):
        """
        Test Case 3: Sets X-Cache-Status to MISS and allows request to proceed.
        """
        conf = {**self.base_conf}
        self.kong_mock.cache.get.return_value = (None, "not found") # Cache miss

        self.plugin.access(conf)

        expected_key = "my-cache:/api/resource:application/json"
        self.kong_mock.cache.get.assert_called_once_with(expected_key)
        self.kong_mock.response.set_header.assert_called_once_with('X-Cache', 'MISS')
        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
