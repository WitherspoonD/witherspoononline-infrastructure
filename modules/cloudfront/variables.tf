# modules/cloudfront/variables.tf
variable "project_name"        { type = string }
variable "domain_name"         { type = string }
variable "s3_bucket_id"        { type = string }
variable "s3_bucket_arn"       { type = string }
variable "s3_regional_domain"  { type = string }
variable "acm_certificate_arn" { type = string }
variable "waf_acl_arn"         { type = string }
