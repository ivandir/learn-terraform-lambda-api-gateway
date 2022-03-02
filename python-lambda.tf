data "archive_file" "lambda_hello_world_python" {
  type = "zip"

  source_dir  = "${path.module}/hello-world-python"
  output_path = "${path.module}/hello-world-python.zip"
}

resource "aws_s3_object" "lambda_hello_world_python" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "hello-world-python.zip"
  source = data.archive_file.lambda_hello_world_python.output_path

  etag = filemd5(data.archive_file.lambda_hello_world_python.output_path)
}

resource "aws_lambda_function" "hello_world_python" {
  function_name = "HelloWorldPython"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_hello_world_python.key

  runtime = "python3.9"
  handler = "hello.lambda_handler"

  source_code_hash = data.archive_file.lambda_hello_world_python.output_base64sha256

  layers = [aws_lambda_layer_version.lambda_python_boto_layer.arn]

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      greeting = "Hello"
    }
  }
}

resource "aws_lambda_permission" "api_gw_python" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world_python.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
