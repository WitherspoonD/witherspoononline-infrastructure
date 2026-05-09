# environments/prod/outputs.tf
# Values printed after `terraform apply` — useful for debugging and the README

output "website_url" {
  description = "Your live website URL"
  value       = "https://${var.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "Needed to invalidate CloudFront cache in GitHub Actions"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_domain_name" {
  description = "Raw CloudFront domain (useful before DNS propagates)"
  value       = module.cloudfront.distribution_domain
}

output "s3_bucket_name" {
  description = "S3 bucket that holds your website files"
  value       = module.s3.bucket_id
}

output "api_gateway_url" {
  description = "Visitor counter API endpoint — used in your frontend JavaScript"
  value       = module.api_gateway.api_url
}

output "dynamodb_table_name" {
  description = "DynamoDB table storing the visitor count"
  value       = module.dynamodb.table_name
}

output "waf_web_acl_arn" {
  description = "WAF ACL ARN protecting your CloudFront distribution"
  value       = module.waf.web_acl_arn
}
