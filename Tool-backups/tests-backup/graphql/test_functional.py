import unittest
from unittest.mock import Mock, MagicMock
import re
import json

class KongMock:
    def __init__(self):
        self.log = Mock()
        self.response = Mock()
        self.ctx = {'shared': {}}
        self.request = Mock()
        # Mock for ngx.re.find
        self.ngx = MagicMock()

class GraphQLHandler:
    # Simplified Python representation for testing
    def __init__(self, kong_mock):
        self.kong = kong_mock

    def extract_graphql_query(self, body):
        try:
            return json.loads(body).get('query', body)
        except (json.JSONDecodeError, AttributeError):
            return body

    def detect_operation_type(self, query):
        if not query: return None
        lower_query = query.lower()
        if lower_query.lstrip().startswith("mutation"): return "mutation"
        if lower_query.lstrip().startswith("query"): return "query"
        return None

    def access(self, conf):
        query = self.extract_graphql_query(self.kong.request.get_raw_body())
        if not query: return

        op_type = self.detect_operation_type(query)

        if conf.get('allowed_operation_types'):
            if op_type not in conf['allowed_operation_types']:
                return self.kong.response.exit(conf['block_status'], conf['block_body'])
        
        for pattern in conf.get('block_patterns', []):
            if re.search(pattern, query):
                return self.kong.response.exit(conf['block_status'], conf['block_body'])

        if conf.get('extract_operation_type_to_shared_context_key') and op_type:
            self.kong.ctx['shared'][conf['extract_operation_type_to_shared_context_key']] = op_type


class TestGraphQLFunctional(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = GraphQLHandler(self.kong_mock)

    def test_allow_block_by_operation_type(self):
        """
        Test Case 1: Allows 'query' but blocks 'mutation' when configured.
        """
        conf = {
            'allowed_operation_types': ['query'],
            'block_status': 403,
            'block_body': 'Operation not allowed.'
        }
        
        # Test 1: Allowed query
        self.kong_mock.request.get_raw_body.return_value = 'query { hero { name } }'
        self.plugin.access(conf)
        self.kong_mock.response.exit.assert_not_called()

        # Test 2: Blocked mutation
        self.kong_mock.request.get_raw_body.return_value = 'mutation { createReview { stars } }'
        self.plugin.access(conf)
        self.kong_mock.response.exit.assert_called_once_with(403, 'Operation not allowed.')

    def test_block_by_regex_pattern(self):
        """
        Test Case 2: Blocks a request matching a regex pattern (e.g., introspection).
        """
        conf = {
            'block_patterns': ['__schema'], # Simple pattern to block introspection
            'block_status': 400,
            'block_body': 'Introspection is disabled.'
        }
        
        # Test 1: Normal query should pass
        self.kong_mock.request.get_raw_body.return_value = 'query { user(id: 4) { name } }'
        self.plugin.access(conf)
        self.kong_mock.response.exit.assert_not_called()

        # Test 2: Introspection query should be blocked
        introspection_query = 'query { __schema { types { name } } }'
        self.kong_mock.request.get_raw_body.return_value = introspection_query
        self.plugin.access(conf)
        self.kong_mock.response.exit.assert_called_once_with(400, 'Introspection is disabled.')

    def test_successful_request_with_context_extraction(self):
        """
        Test Case 3: A valid request passes and its operation type is extracted.
        """
        conf = {
            'extract_operation_type_to_shared_context_key': 'graphql_op'
        }
        query_body = 'query GetHero { hero { name } }'
        self.kong_mock.request.get_raw_body.return_value = query_body

        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_not_called()
        self.assertIn('graphql_op', self.kong_mock.ctx['shared'])
        self.assertEqual(self.kong_mock.ctx['shared']['graphql_op'], 'query')

if __name__ == '__main__':
    unittest.main()
