terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

resource "random_pet" "lambda_bucket_name" {
  prefix = "learn-terraform-functions"
  length = 2
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id

  force_destroy = true
}

resource "aws_s3_bucket_acl" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

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

resource "aws_lambda_function" "hello_world_js" {
  function_name = "HelloWorldJS"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_hello_world_js.key

  runtime = "nodejs12.x"
  handler = "hello.handler"

  source_code_hash = data.archive_file.lambda_hello_world_js.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

data "archive_file" "lambda_python_boto_layer" {
  type = "zip"

  source_dir  = "${path.module}/lambda-layers/python-layers/"
  output_path = "${path.module}/lambda-layers/boto.zip"
}

resource "aws_s3_object" "lambda_python_boto_layer" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "boto.zip"
  source = data.archive_file.lambda_python_boto_layer.output_path

  etag = filemd5(data.archive_file.lambda_python_boto_layer.output_path)
}

resource "aws_lambda_layer_version" "lambda_python_boto_layer" {
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_python_boto_layer.key

  layer_name = "boto2-test"

  compatible_architectures = ["x86_64"]
  compatible_runtimes = ["python3.9"]

  source_code_hash = data.archive_file.lambda_python_boto_layer.output_base64sha256
  
  description = "boto package layer for Python 3.9"
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

resource "aws_cloudwatch_log_group" "hello_world_js" {
  name = "/aws/lambda/${aws_lambda_function.hello_world_js.function_name}"

  retention_in_days = 30
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = ""
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit = 10
  }
}

resource "aws_apigatewayv2_integration" "hello_world_js" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.hello_world_js.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "hello_world_python" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.hello_world_python.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "hello_world_js" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /hello-js"
  target    = "integrations/${aws_apigatewayv2_integration.hello_world_js.id}"
}

resource "aws_apigatewayv2_route" "hello_world_python" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /hello-python"
  target    = "integrations/${aws_apigatewayv2_integration.hello_world_python.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw_js" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world_js.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_python" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world_python.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
