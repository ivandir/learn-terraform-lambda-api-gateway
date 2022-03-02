data "archive_file" "lambda_hello_world_js" {
  type = "zip"

  source_dir  = "${path.module}/hello-world-js"
  output_path = "${path.module}/hello-world-js.zip"
}

resource "aws_s3_object" "lambda_hello_world_js" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "hello-world-js.zip"
  source = data.archive_file.lambda_hello_world_js.output_path

  etag = filemd5(data.archive_file.lambda_hello_world_js.output_path)
}

resource "aws_lambda_function" "hello_world_js" {
  function_name = "HelloWorldJS"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_hello_world_js.key

  runtime = "nodejs12.x"
  handler = "hello.handler"

  source_code_hash = data.archive_file.lambda_hello_world_js.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_permission" "api_gw_js" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world_js.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_cloudwatch_log_group" "hello_world_js" {
  name = "/aws/lambda/${aws_lambda_function.hello_world_js.function_name}"

  retention_in_days = 30
}

