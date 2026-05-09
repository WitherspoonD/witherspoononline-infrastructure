# modules/lambda/src/test_lambda_function.py
# ─────────────────────────────────────────────────────────────────────────────
# Unit tests for the visitor counter Lambda
# Run locally: python -m pytest test_lambda_function.py -v
# These same tests run in GitHub Actions before every deploy.
# ─────────────────────────────────────────────────────────────────────────────

import json
import os
import pytest
from unittest.mock import MagicMock, patch

# Set env var before importing the function
os.environ["DYNAMODB_TABLE"] = "test-visitor-count"


class TestVisitorCounter:

    def test_successful_increment_returns_200(self):
        """Happy path: DynamoDB update succeeds, returns count"""
        mock_table = MagicMock()
        mock_table.update_item.return_value = {
            "Attributes": {"count": 42}
        }

        with patch("lambda_function.dynamodb") as mock_dynamodb:
            mock_dynamodb.Table.return_value = mock_table

            from lambda_function import lambda_handler
            result = lambda_handler({}, None)

        assert result["statusCode"] == 200
        body = json.loads(result["body"])
        assert body["count"] == 42

    def test_response_includes_cors_header(self):
        """CORS header must be present so the browser doesn't block the response"""
        mock_table = MagicMock()
        mock_table.update_item.return_value = {
            "Attributes": {"count": 1}
        }

        with patch("lambda_function.dynamodb") as mock_dynamodb:
            mock_dynamodb.Table.return_value = mock_table

            from lambda_function import lambda_handler
            result = lambda_handler({}, None)

        assert "Access-Control-Allow-Origin" in result["headers"]

    def test_dynamodb_error_returns_500(self):
        """If DynamoDB fails, return 500 (not crash the Lambda)"""
        from botocore.exceptions import ClientError

        mock_table = MagicMock()
        mock_table.update_item.side_effect = ClientError(
            {"Error": {"Code": "ProvisionedThroughputExceededException",
                       "Message": "Rate exceeded"}},
            "UpdateItem"
        )

        with patch("lambda_function.dynamodb") as mock_dynamodb:
            mock_dynamodb.Table.return_value = mock_table

            from lambda_function import lambda_handler
            result = lambda_handler({}, None)

        assert result["statusCode"] == 500
        body = json.loads(result["body"])
        assert "error" in body
