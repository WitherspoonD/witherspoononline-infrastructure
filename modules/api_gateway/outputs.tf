# modules/api_gateway/outputs.tf
output "api_url" {
  description = "Full invoke URL for the visitor counter — update your frontend JS to use this"
  value       = "${aws_apigatewayv2_stage.prod.invoke_url}/count"
}

output "api_id" {
  value = aws_apigatewayv2_api.visitor_counter.id
}

output "execution_arn" {
  description = "Passed to Lambda module for invoke permission"
  value       = aws_apigatewayv2_api.visitor_counter.execution_arn
}
