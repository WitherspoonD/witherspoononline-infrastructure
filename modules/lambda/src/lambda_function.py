# modules/lambda/src/lambda_function.py
# ─────────────────────────────────────────────────────────────────────────────
# Visitor counter — same logic as your original CRC Lambda,
# cleaned up with proper error handling and structured logging.
#
# Improvements over original:
# - Uses environment variable for table name (no hardcoding)
# - Returns proper CORS headers
# - Structured error responses
# - Type hints for readability
# ─────────────────────────────────────────────────────────────────────────────

import json
import os
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["DYNAMODB_TABLE"]


def lambda_handler(event: dict, context) -> dict:
    """
    Increment visitor counter and return the new count.
    Called by API Gateway on every page load.
    """
    table = dynamodb.Table(TABLE_NAME)

    try:
        response = table.update_item(
            Key={"id": "visitors"},
            UpdateExpression="ADD #count :increment",
            ExpressionAttributeNames={"#count": "count"},
            ExpressionAttributeValues={":increment": 1},
            ReturnValues="UPDATED_NEW",
        )

        count = int(response["Attributes"]["count"])
        logger.info({"action": "visitor_count_updated", "count": count})

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://witherspoononline.com",
                "Access-Control-Allow-Methods": "GET,OPTIONS",
            },
            "body": json.dumps({"count": count}),
        }

    except ClientError as e:
        logger.error({
            "action": "dynamodb_error",
            "error": e.response["Error"]["Code"],
            "message": e.response["Error"]["Message"],
        })
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Failed to update visitor count"}),
        }
