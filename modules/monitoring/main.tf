# modules/monitoring/main.tf
# ─────────────────────────────────────────────────────────────────────────────
# CloudWatch alarms — this is NEW vs your original SAM deploy.
# You'll get an email if your site starts erroring.
# This is also the foundation for SRE Project 3 (SLO burn rate alarms).
# ─────────────────────────────────────────────────────────────────────────────

# SNS topic for email alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── Alarm 1: Lambda errors ────────────────────────────────────────────────────
# Fires if your visitor counter throws more than 3 errors in 5 minutes.
# This is your first SLI: "visitor counter error rate"
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  alarm_description   = "Visitor counter Lambda is throwing errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300   # 5 minutes
  statistic           = "Sum"
  threshold           = 3
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_func_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# ── Alarm 2: API Gateway 5xx errors ──────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-api-5xx-errors"
  alarm_description   = "API Gateway is returning 5xx errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = var.api_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# ── Alarm 3: Lambda duration (P95 latency) ───────────────────────────────────
# Fires if Lambda takes longer than 3 seconds to respond (p95).
# This is your second SLI: "visitor counter latency"
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project_name}-lambda-high-latency"
  alarm_description   = "Visitor counter Lambda is running slow (P95 > 3s)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p95"
  threshold           = 3000  # milliseconds
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_func_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
# One place to see all your key metrics at a glance
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "Lambda Invocations & Errors"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_func_name],
            ["AWS/Lambda", "Errors",      "FunctionName", var.lambda_func_name]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "Lambda Duration (P50 / P95 / P99)"
          region = var.aws_region
          period = 300
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_func_name, { stat = "p50" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_func_name, { stat = "p95" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_func_name, { stat = "p99" }]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "API Gateway Requests & 5xx Errors"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/ApiGateway", "Count",    "ApiId", var.api_id],
            ["AWS/ApiGateway", "5XXError", "ApiId", var.api_id]
          ]
        }
      }
    ]
  })
}
