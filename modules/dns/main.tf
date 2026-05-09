# modules/dns/main.tf
# ─────────────────────────────────────────────────────────────────────────────
# ACM certificate + Route53 DNS records
#
# This module looks up your existing Route53 hosted zone by domain name.
# It does NOT create the hosted zone — you already have one from your
# original setup. It just adds/updates the records.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

# Look up your existing Route53 hosted zone — don't recreate it
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# ── ACM Certificate ───────────────────────────────────────────────────────────
# Covers both witherspoononline.com AND www.witherspoononline.com
resource "aws_acm_certificate" "website" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"] # updated to wildcard for both apex and www
  validation_method         = "DNS"

  # Best practice: create a new cert before destroying the old one
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project   = "witherspoon-resume"
    ManagedBy = "terraform"
  }
}

# ── DNS validation records (auto-creates the CNAME in Route53) ───────────────
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.website.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Wait for cert to be issued before continuing
resource "aws_acm_certificate_validation" "website" {
  certificate_arn         = aws_acm_certificate.website.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ── Route53 A record → CloudFront (apex domain) ───────────────────────────────
resource "aws_route53_record" "apex" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# ── Route53 A record → CloudFront (www subdomain) ────────────────────────────
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_domain
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}
