# modules/monitoring/variables.tf
variable "project_name"      { type = string }
variable "lambda_func_name"  { type = string }
variable "api_id"            { type = string }
variable "alert_email"       { type = string }
variable "aws_region"        { type = string }
