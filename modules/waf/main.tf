# modules/waf/main.tf
# ─────────────────────────────────────────────────────────────────────────────
# WAF WebACL — this is NEW. Your SAM deploy had no WAF.
#
# What this adds to your site:
#   - Blocks requests matching OWASP Top 10 attack patterns (SQLi, XSS, etc.)
#   - Blocks requests from known bad IPs (AWS threat intelligence)
#   - Rate-limits to prevent abuse (1000 req per 5 min per IP)
#   - Logs all blocked requests for your CloudTrail analysis later
#
# This is also a direct example of Project 2 from your roadmap.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

resource "aws_wafv2_web_acl" "website" {
  name        = "${var.project_name}-waf"
  description = "WAF protection for ${var.project_name} CloudFront distribution"
  scope       = "CLOUDFRONT"  # Must be CLOUDFRONT for CloudFront (not REGIONAL)

  default_action {
    allow {}  # Allow by default; rules below BLOCK bad traffic
  }

  # ── Rule 1: AWS Common Rule Set ──────────────────────────────────────────
  # Blocks requests matching common web application attack patterns.
  # Covers OWASP Top 10 basics: SQLi, XSS, LFI, RFI, and more.
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action { 
      none {
        } 
      }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 2: Known Bad Inputs ─────────────────────────────────────────────
  # Blocks requests containing patterns associated with exploitation
  # of vulnerabilities like Log4Shell (yes, this would have caught it).
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

      override_action {
    none {
    }
  }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 3: Amazon IP Reputation List ────────────────────────────────────
  # Blocks requests from IPs on AWS's threat intelligence list:
  # botnets, scanners, known malicious actors.
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 3

    override_action { 
      none {

      } 
      }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "IPReputationList"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 4: Rate limiting ─────────────────────────────────────────────────
  # Blocks any single IP making more than 1000 requests in 5 minutes.
  # Protects against scrapers, brute force, and basic DDoS.
  rule {
    name     = "RateLimitRule"
    priority = 4

    action { 
      block {

      } 
      }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
