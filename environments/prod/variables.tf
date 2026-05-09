# environments/prod/variables.tf

variable "aws_region" {
  description = "Primary AWS region for most resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Used to prefix/name all resources — makes them easy to find in the console"
  type        = string
  default     = "witherspoon-resume"
}

variable "domain_name" {
  description = "Your registered domain. Must match your Route53 hosted zone."
  type        = string
  default     = "witherspoononline.com"
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  # Set this in terraform.tfvars — don't commit your email to git
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  
}
