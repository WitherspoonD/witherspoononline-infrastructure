# modules/s3/variables.tf
variable "project_name" { type = string }
variable "domain_name"  { type = string }

# Passed in from cloudfront module — creates a dependency
# The bucket policy needs to know which CloudFront distribution is allowed
variable "cloudfront_distribution_arn" {
  type    = string
  default = ""   # Empty on first apply (chicken-and-egg); CloudFront sets this
}
