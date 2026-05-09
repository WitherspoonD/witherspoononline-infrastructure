# modules/api_gateway/main.tf
# ─────────────────────────────────────────────────────────────────────────────
# HTTP API Gateway — replaces the REST API from your SAM deploy
# HTTP API is cheaper and simpler than REST API for this use case.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "visitor_counter" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "Visitor counter API for ${var.project_name}"

  # CORS configuration — only your domain can call this API
  cors_configuration {
    allow_headers = ["Content-Type"]
    allow_methods = ["GET", "OPTIONS"]
    allow_origins = ["https://${var.domain_name}"]
    max_age       = 300
  }

  tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

# Lambda integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.visitor_counter.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
}

# Route: GET /count
resource "aws_apigatewayv2_route" "get_count" {
  api_id    = aws_apigatewayv2_api.visitor_counter.id
  route_key = "GET /count"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Auto-deploy stage
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.visitor_counter.id
  name        = "prod"
  auto_deploy = true

  # Access logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 30
}

# Grant API Gateway permission to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "TerraformAllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_func_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_counter.execution_arn}/*/*"
}
