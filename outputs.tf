# Output value definitions

output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store function code."

  value = aws_s3_bucket.lambda_bucket.id
}

output "function_name_js" {
  description = "Name of the JS Lambda function."

  value = aws_lambda_function.hello_world_js.function_name
}

output "function_name_python" {
  description = "Name of the Python Lambda function."

  value = aws_lambda_function.hello_world_python.function_name
}

output "base_url" {
  description = "Base URL for API Gateway stage."

  value = aws_apigatewayv2_stage.lambda.invoke_url
}
