# modules/api_gateway/variables.tf
variable "project_name"      { type = string }
variable "lambda_invoke_arn" { type = string }
variable "lambda_func_name"  { type = string }
variable "domain_name"       { type = string }
