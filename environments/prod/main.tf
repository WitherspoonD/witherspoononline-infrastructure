# environments/prod/main.tf
# ─────────────────────────────────────────────────────────────────────────────
# This is the single file you run `terraform apply` from.
# It wires together every module for the production environment.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — keeps your state file safe in S3 with locking via DynamoDB
  # This prevents two deploys running at the same time from corrupting state.
  backend "s3" {
    bucket         = "witherspoon-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "witherspoon-terraform-locks"
    encrypt        = true
  }
}

# ── Providers ─────────────────────────────────────────────────────────────────
# Primary region for most resources
provider "aws" {
  region = var.aws_region
}

# ACM certificates for CloudFront MUST be in us-east-1, regardless of
# where your other resources live. This is an AWS hard requirement.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# ── IAM (Lambda execution role) ───────────────────────────────────────────────
module "iam" {
  source        = "../../modules/iam"
  project_name  = var.project_name
  dynamodb_arn  = module.dynamodb.table_arn
}

# ── DynamoDB (visitor counter table) ─────────────────────────────────────────
module "dynamodb" {
  source       = "../../modules/dynamodb"
  project_name = var.project_name
  dynamodb_table_name = var.dynamodb_table_name
}

# ── Lambda (visitor counter function) ────────────────────────────────────────
module "lambda" {
  source             = "../../modules/lambda"
  project_name       = var.project_name
  lambda_role_arn    = module.iam.lambda_role_arn
  dynamodb_table_name = module.dynamodb.table_name
  lambda_function_name = var.lambda_function_name
}

# ── WAF (protect CloudFront with managed rules) ───────────────────────────────
# NOTE: WAF for CloudFront must also be in us-east-1
module "waf" {
  source       = "../../modules/waf"
  project_name = var.project_name

  providers = {
    aws = aws.us_east_1
  }
}

# ── S3 (website bucket — private, no public access) ──────────────────────────
module "s3" {
  source       = "../../modules/s3"
  project_name = var.project_name
  domain_name  = var.domain_name
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
}

# ── DNS + ACM Certificate ─────────────────────────────────────────────────────
module "dns" {
  source              = "../../modules/dns"
  domain_name         = var.domain_name
  cloudfront_domain   = module.cloudfront.distribution_domain
  cloudfront_zone_id  = module.cloudfront.distribution_hosted_zone_id

  providers = {
    aws = aws.us_east_1
  }
}

# ── CloudFront (CDN + OAC — S3 is only reachable through here) ───────────────
module "cloudfront" {
  source              = "../../modules/cloudfront"
  project_name        = var.project_name
  domain_name         = var.domain_name
  s3_bucket_id        = module.s3.bucket_id
  s3_bucket_arn       = module.s3.bucket_arn
  s3_regional_domain  = module.s3.regional_domain_name
  acm_certificate_arn = module.dns.certificate_arn
  waf_acl_arn         = module.waf.web_acl_arn

  providers = {
    aws = aws.us_east_1
  }
}

# ── API Gateway (HTTP API → Lambda) ──────────────────────────────────────────
module "api_gateway" {
  source             = "../../modules/api_gateway"
  project_name       = var.project_name
  lambda_invoke_arn  = module.lambda.invoke_arn
  lambda_func_name   = module.lambda.function_name
  domain_name        = var.domain_name
}

# ── Monitoring (CloudWatch alarms + SNS email alerts) ────────────────────────
module "monitoring" {
  source             = "../../modules/monitoring"
  project_name       = var.project_name
  lambda_func_name   = module.lambda.function_name
  api_id             = module.api_gateway.api_id
  alert_email        = var.alert_email
  aws_region         = var.aws_region
}
