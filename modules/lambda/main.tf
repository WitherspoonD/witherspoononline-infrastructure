# modules/lambda/main.tf
# ─────────────────────────────────────────────────────────────────────────────
# Lambda function — visitor counter
# The Python code is the same logic you wrote for the CRC,
# just packaged and deployed via Terraform instead of SAM.
# ─────────────────────────────────────────────────────────────────────────────

# Package the Lambda code into a zip file
# Terraform does this automatically from the source directory
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "visitor_counter" {
  function_name    = var.lambda_function_name
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = var.lambda_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }

  # Structured logging to CloudWatch — easier to query than plain text
  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

# Explicit log group with retention — without this, logs never expire
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-visitor-counter"
  retention_in_days = 30

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  # source_arn    = "${var.api_gateway_execution_arn}/*/*"
}
