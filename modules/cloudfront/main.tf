# modules/cloudfront/main.tf
# ─────────────────────────────────────────────────────────────────────────────
# CloudFront distribution with Origin Access Control (OAC)
#
# OAC vs OAI: Your original setup may have used Origin Access Identity (OAI).
# OAC is the newer, recommended replacement. Key difference:
#   OAI = legacy, uses a special CloudFront "user" identity
#   OAC = uses IAM Sigv4 signing — more secure, supports more S3 features
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# OAC — tells CloudFront to sign requests to S3 with Sigv4
# This is what allows the bucket policy to verify requests come from CloudFront
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for ${var.domain_name} — restricts S3 to CloudFront only"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Cache policy — controls what gets cached and for how long
resource "aws_cloudfront_cache_policy" "website" {
  name        = "${var.project_name}-cache-policy"
  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config  { cookie_behavior = "none" }
    headers_config  { header_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# The CloudFront distribution
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name, "www.${var.domain_name}"]
  price_class         = "PriceClass_100" # US + Europe only — cheapest option
  web_acl_id          = var.waf_acl_arn  # WAF protection (see waf module)

  # ── S3 origin (private bucket via OAC) ──────────────────────────────────
  origin {
    domain_name              = var.s3_regional_domain   # MUST be regional, not website endpoint
    origin_id                = "S3-${var.domain_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  # ── Default cache behavior (serves your HTML/CSS/JS) ────────────────────
  default_cache_behavior {
    target_origin_id       = "S3-${var.domain_name}"
    viewer_protocol_policy = "redirect-to-https"   # HTTP → HTTPS always
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = aws_cloudfront_cache_policy.website.id
    compress               = true

    # Security headers — adds important HTTP security headers to every response
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # ── Custom error pages (SPA support) ────────────────────────────────────
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  # ── TLS certificate ──────────────────────────────────────────────────────
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"   # Disables old insecure TLS versions
  }

  # ── Access logging ───────────────────────────────────────────────────────
  logging_config {
    include_cookies = false
    bucket          = "${var.s3_bucket_id}-logs.s3.amazonaws.com"
    prefix          = "cloudfront-logs/"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

# ── Security response headers policy ─────────────────────────────────────────
# These headers protect visitors from common web attacks.
# This is something your original SAM deploy didn't have.
resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.project_name}-security-headers"

  security_headers_config {
    # Prevents clickjacking — stops your site from being loaded in an iframe
    frame_options {
      frame_option = "DENY"
      override     = true
    }

    # Prevents MIME-type sniffing attacks
    content_type_options {
      override = true
    }

    # Forces HTTPS for 1 year, including subdomains
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    # Controls what browser features can be used
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}
