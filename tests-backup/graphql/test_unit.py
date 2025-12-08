import unittest
from unittest.mock import Mock, MagicMock
import json

# Import the handler from the functional test file to reuse the Python implementation
from tests.graphql.test_functional import GraphQLHandler, KongMock

class TestGraphQLUnit(unittest.TestCase):

    def setUp(self):
        self.kong_mock = KongMock()
        self.plugin = GraphQLHandler(self.kong_mock)

    def test_query_from_json_body(self):
        """
        Test Case 1: Correctly extracts the query from a JSON request body.
        """
        query = "query { user(id: 1) { name } }"
        json_body = json.dumps({"query": query, "variables": {"id": 1}})
        
        extracted_query = self.plugin.extract_graphql_query(json_body)
        
        self.assertEqual(extracted_query, query)

    def test_block_on_no_operation_type(self):
        """
        Test Case 2: Blocks a request if operation type cannot be detected and a filter is active.
        """
        conf = {
            'allowed_operation_types': ['query'], # A filter is active
            'block_status': 400,
            'block_body': 'Bad Request'
        }
        # This query is technically invalid GraphQL, but it serves to test the detection logic.
        # The detector won't find 'query' or 'mutation' at the start.
        ambiguous_query = "{ hero { name } }" 
        self.kong_mock.request.get_raw_body.return_value = ambiguous_query

        self.plugin.access(conf)

        # It should be blocked because the type is not in the allow list
        self.kong_mock.response.exit.assert_called_once_with(400, 'Bad Request')

    def test_no_security_rules(self):
        """
        Test Case 3: A valid query passes when no security rules are configured.
        """
        conf = {} # Empty config
        query = "mutation { createUser { id } }"
        self.kong_mock.request.get_raw_body.return_value = query
        
        self.plugin.access(conf)

        self.kong_mock.response.exit.assert_not_called()

if __name__ == '__main__':
    unittest.main()
