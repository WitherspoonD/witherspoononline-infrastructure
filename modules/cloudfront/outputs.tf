# modules/cloudfront/outputs.tf
output "distribution_id" {
  description = "Distribution ID — needed for cache invalidation in CI/CD"
  value       = aws_cloudfront_distribution.website.id
}

output "distribution_domain" {
  description = "CloudFront domain name — used in Route53 alias record"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront hosted zone ID — used in Route53 alias record"
  value       = aws_cloudfront_distribution.website.hosted_zone_id
}

output "distribution_arn" {
  description = "Distribution ARN — used in S3 bucket policy for OAC"
  value       = aws_cloudfront_distribution.website.arn
}
