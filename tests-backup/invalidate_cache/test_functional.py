import unittest
from unittest.mock import Mock

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()
        self.cache = Mock()

class InvalidateCacheHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def resolve_fragment_value(self, fragment_ref):
        if fragment_ref.startswith("request.headers."):
            return self.kong.request.get_header(fragment_ref[16:])
        if fragment_ref.startswith("shared_context."):
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
            return

        invalidated, err = self.kong.cache.delete(cache_key)
        
        if not conf.get('continue_on_invalidation', True):
            if invalidated:
                return self.kong.response.exit(conf['on_invalidation_success_status'], conf['on_invalidation_success_body'])
            else:
                return self.kong.response.exit(conf['on_invalidation_failure_status'], conf['on_invalidation_failure_body'])

class TestInvalidateCacheFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = InvalidateCacheHandler(self.kong_mock)

    def test_successful_invalidation(self):
        """
        Test Case 1: Correctly constructs a cache key and calls kong.cache.delete.
        """
        conf = {
            'cache_key_prefix': 'my-api',
            'cache_key_fragments': ['request.headers.user-id', 'shared_context.product_id']
        }
        # Arrange
        self.kong_mock.request.get_header.return_value = 'user123'
        self.kong_mock.ctx['shared']['product_id'] = 'prod456'
        self.kong_mock.cache.delete.return_value = (True, None)
        
        # Act
        self.plugin.access(conf)

        # Assert
        expected_key = "my-api:user123:prod456"
        self.kong_mock.cache.delete.assert_called_once_with(expected_key)
        self.kong_mock.response.exit.assert_not_called() # Should continue by default

    def test_invalidation_with_termination_on_success(self):
        """
        Test Case 2: Terminates request with success status when configured.
        """
        conf = {
            'cache_key_fragments': ['literal-key'],
            'continue_on_invalidation': False,
            'on_invalidation_success_status': 204,
            'on_invalidation_success_body': 'Purged.'
        }
        # Arrange
        self.kong_mock.cache.delete.return_value = (True, None)
        
        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.cache.delete.assert_called_once_with("literal-key")
        self.kong_mock.response.exit.assert_called_once_with(204, 'Purged.')

    def test_invalidation_with_termination_on_failure(self):
        """
        Test Case 3: Terminates request with failure status when configured.
        """
        conf = {
            'cache_key_fragments': ['some-key'],
            'continue_on_invalidation': False,
            'on_invalidation_failure_status': 500,
            'on_invalidation_failure_body': 'Cache error.'
        }
        # Arrange: Mock a cache failure (e.g., Redis is down)
        self.kong_mock.cache.delete.return_value = (None, "connection refused")
        
        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.cache.delete.assert_called_once_with("some-key")
        self.kong_mock.response.exit.assert_called_once_with(500, 'Cache error.')

if __name__ == '__main__':
    unittest.main()
