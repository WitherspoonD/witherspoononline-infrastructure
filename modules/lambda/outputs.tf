# modules/lambda/outputs.tf
output "function_name" {
  value = aws_lambda_function.visitor_counter.function_name
}

output "invoke_arn" {
  description = "ARN used by API Gateway to invoke Lambda"
  value       = aws_lambda_function.visitor_counter.invoke_arn
}

output "function_arn" {
  value = aws_lambda_function.visitor_counter.arn
}
