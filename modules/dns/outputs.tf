# modules/dns/outputs.tf
output "certificate_arn" {
  description = "Validated ACM certificate ARN — passed to CloudFront"
  value       = aws_acm_certificate_validation.website.certificate_arn
}
