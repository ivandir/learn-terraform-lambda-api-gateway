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
