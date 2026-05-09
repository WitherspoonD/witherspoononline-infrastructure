# modules/s3/main.tf
# ─────────────────────────────────────────────────────────────────────────────
# SECURITY IMPROVEMENT vs your SAM deploy:
# The original S3 static website hosting requires the bucket to be PUBLIC.
# This version keeps the bucket FULLY PRIVATE.
# CloudFront accesses it directly via Origin Access Control (OAC) —
# no public S3 URL exists at all. Direct S3 access returns 403 Forbidden.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "website" {
  bucket = var.domain_name

  tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

# sets the bucket to allow ACLs
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  bucket     = aws_s3_bucket.logs.id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.logs]
}

# Block ALL public access — belt AND suspenders
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt everything at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Enable versioning — lets you recover accidentally deleted/overwritten files
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable access logging — who accessed what, when
# Logs go to a separate logging bucket (created below)
resource "aws_s3_bucket_logging" "website" {
  bucket        = aws_s3_bucket.website.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}

# ── Logging bucket ────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "logs" {
  bucket = "${var.domain_name}-logs"

  tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
    Purpose     = "access-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Auto-delete old logs after 90 days — keeps costs low
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter {}

    expiration {
      days = 90
    }
  }
}

# ── Bucket policy: allow CloudFront OAC only ──────────────────────────────────
# This is the KEY policy. It says:
#   "Only CloudFront (specifically, this distribution) can GetObject from this bucket."
# Any direct request to S3 — from a browser, curl, anyone — gets 403.
# The cloudfront_distribution_arn is passed in from the cloudfront module.
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.s3_cloudfront_oac.json

  # Must wait for public access block to be applied first
  depends_on = [aws_s3_bucket_public_access_block.website]
}

data "aws_iam_policy_document" "s3_cloudfront_oac" {
  statement {
    sid    = "AllowCloudFrontOACAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.cloudfront_distribution_arn]
    }
  }
}
