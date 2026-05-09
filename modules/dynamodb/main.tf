# modules/dynamodb/main.tf
# ─────────────────────────────────────────────────────────────────────────────
# DynamoDB table for the visitor counter
# Mirrors what SAM created, but with encryption and backup enabled
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "visitor_count" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"  # No capacity planning needed at this scale
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Encryption at rest
  server_side_encryption {
    enabled = true
  }

  # Point-in-time recovery — lets you restore to any second in the last 35 days
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

# Seed the initial counter record so Lambda doesn't fail on first invocation
resource "aws_dynamodb_table_item" "initial_count" {
  table_name = aws_dynamodb_table.visitor_count.name
  hash_key   = aws_dynamodb_table.visitor_count.hash_key

  item = jsonencode({
    id    = { S = "visitors" }
    count = { N = "0" }
  })

  # Don't overwrite if item already exists (e.g., on re-apply)
  lifecycle {
    ignore_changes = [item]
  }
}
