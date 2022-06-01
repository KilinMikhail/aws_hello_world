terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = ">= 1.2.1"
}

provider "aws" {
  region  = "us-east-1"
}

data "archive_file" "app_file" {
  type = "zip"

  source_dir  = "${path.module}/src"
  output_path = "${path.module}/app.zip"
}

resource "aws_iam_role" "empty_lambda_iam_role" {
  name = "EmptyLambdaIamRole"

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Principal = {
            Service = "lambda.amazonaws.com"
          }
          Effect = "Allow"
        }
      ]
    }
  )
}

resource "aws_lambda_function" "hello_world_lambda" {
  filename      = data.archive_file.app_file.output_path
  function_name = "HelloWorldLambda"
  role          = aws_iam_role.empty_lambda_iam_role.arn
  handler       = "app.handler"

  source_code_hash = filebase64sha256(data.archive_file.app_file.output_path)

  runtime = "ruby2.7"
}

resource "aws_api_gateway_rest_api" "hello_world_api_gateway" {
  name        = "HelloWorldApiGateway"
}

resource "aws_api_gateway_resource" "hello_world_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_world_api_gateway.id
  parent_id   = aws_api_gateway_rest_api.hello_world_api_gateway.root_resource_id
  path_part   = "hello_world"
}

resource "aws_api_gateway_method" "get_hello_world_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_world_api_gateway.id
  resource_id   = aws_api_gateway_resource.hello_world_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "hello_world_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.hello_world_api_gateway.id
  resource_id             = aws_api_gateway_resource.hello_world_resource.id
  http_method             = aws_api_gateway_method.get_hello_world_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_world_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "hello_world_deployment" {
  depends_on  = [aws_api_gateway_integration.hello_world_lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.hello_world_api_gateway.id
  stage_name  = "production"
}

resource "aws_lambda_permission" "lambda_gateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.hello_world_api_gateway.execution_arn}/*/*"
}
