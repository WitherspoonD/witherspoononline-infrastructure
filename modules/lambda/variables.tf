# modules/lambda/variables.tf
variable "project_name"            { type = string }
variable "lambda_role_arn"         { type = string }
variable "dynamodb_table_name"     { type = string }
variable "lambda_function_name"        { type = string }
variable "api_gateway_execution_arn" {
  type    = string
  default = ""
}
