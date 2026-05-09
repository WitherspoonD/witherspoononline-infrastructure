# modules/s3/outputs.tf
output "bucket_id" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.website.id
}

output "bucket_arn" {
  description = "S3 bucket ARN — used in bucket policy and IAM"
  value       = aws_s3_bucket.website.arn
}

output "regional_domain_name" {
  description = "Regional domain for CloudFront OAC origin (NOT the website endpoint)"
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}
