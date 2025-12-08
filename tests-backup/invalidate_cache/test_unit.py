import unittest
from unittest.mock import Mock

# Reusing the Python implementation from the functional tests
from tests.invalidate_cache.test_functional import InvalidateCacheHandler, KongMock

class TestInvalidateCacheUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = InvalidateCacheHandler(self.kong_mock)

    def test_empty_cache_key(self):
        """
        Test Case 1: Does not call kong.cache.delete if the generated key is empty.
        """
        # Arrange: Config that resolves to nothing
        conf = {
            'cache_key_prefix': '',
            'cache_key_fragments': ['shared_context.non_existent_key']
        }
        self.kong_mock.ctx['shared'] = {} # Ensure key is not present

        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.cache.delete.assert_not_called()
        # The real plugin would log an error, which we assume for this test.
        # It should also not terminate the request.
        self.kong_mock.response.exit.assert_not_called()

    def test_invalidation_failure_with_continue(self):
        """
        Test Case 2: Request continues by default if cache invalidation fails.
        """
        conf = {
            'cache_key_fragments': ['some-key'],
            'continue_on_invalidation': True # Default behavior
        }
        # Arrange: Mock a cache failure
        self.kong_mock.cache.delete.return_value = (None, "cache unavailable")

        # Act
        self.plugin.access(conf)

        # Assert
        self.kong_mock.cache.delete.assert_called_once_with('some-key')
        # The request should NOT be terminated
        self.kong_mock.response.exit.assert_not_called()


if __name__ == '__main__':
    unittest.main()
