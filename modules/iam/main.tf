# modules/iam/main.tf
# ─────────────────────────────────────────────────────────────────────────────
# IAM role for the Lambda function — least privilege
# Lambda can ONLY read/write the visitor count table. Nothing else.
# This is a real security improvement: if Lambda were ever compromised,
# the blast radius is limited to one DynamoDB table.
# ─────────────────────────────────────────────────────────────────────────────

# Trust policy: allows Lambda service to assume this role
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# Permission policy: scoped to only what Lambda actually needs
data "aws_iam_policy_document" "lambda_permissions" {
  # DynamoDB: read and update the visitor counter only
  statement {
    sid    = "DynamoDBVisitorCounter"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:PutItem"
    ]
    resources = [var.dynamodb_arn]
  }

  # CloudWatch Logs: Lambda needs this to write logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.project_name}-lambda-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}
