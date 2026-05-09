# modules/waf/outputs.tf
output "web_acl_arn" {
  description = "WAF WebACL ARN — attached to CloudFront distribution"
  value       = aws_wafv2_web_acl.website.arn
}
