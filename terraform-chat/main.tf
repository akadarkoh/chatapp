provider "aws" {
  region = "us-east-2"
}

#DynamoDB Table for Chat Messages
resource "aws_dynamodb_table" "chat_messages" {
    name = "chat_messages"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "session_id"
    range_key = "timestamp"

    attribute {
      name = "session_id"
      type = "S"
    }

    attribute {
      name = "timestamp"
      type = "S"
    }

    tags = {
        Environment = "ChatApp"
    }
}

#DynamoDB Table for WebSocket Connections
resource "aws_dynamodb_table" "websocket_connections" {
  name = "WebSocketConnections"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "ConnectionID"

  attribute {
    name = "ConnectionID"
    type = "S"
  }

  tags = {
    Environment = "ChatApp"
  }
}

#IAM Role for Lambda Function
resource "aws_iam_role" "lambda_execution_role" {
    name = "ChatAppLambdaRole"

    assume_role_policy = jsonencode ({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principle = {
                    Service = "lambda.amazonaws.com"
                }
            }]
    })

    }
    
resource "aws_iam_role_policy" "ChatAppLambdaPolicy" {
    name = "ChatAppLambdaPolicy"
    role = aws_iam_role.lambda_execution_role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ]
                Effect = "Allow"
                Resource = "*"
            },
            {
                Action = [
                    "dynamodb:*"
                ]
                Effect = "Allow"
                Resource = "*"
            }
        ]
    })
}

#Lambda Functions
resource "aws_lambda_function" "connect_handler" {
    function_name = "ChatAppConnect"
    role = aws_iam_role.lambda_execution_role.arn
    runtime = "python3.9"
    handler = "connect.lambda_handler"
    filename = "connect.zip"

    environment {
      variables = {
        DynamoDB_TABLE = aws_dynamodb_table.websocket_connections.name
      }
    }
}

resource "aws_lambda_function" "disconnect_handler" {
  function_name = "ChatAppDisconnect"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "python3.9"
  handler       = "disconnect.lambda_handler"
  filename      = "disconnect.zip" # Pre-packaged zip file of your Lambda code

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.websocket_connections.name
    }
  }
}

resource "aws_lambda_function" "send_message_handler" {
  function_name = "ChatAppSendMessage"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "python3.9"
  handler       = "send_message.lambda_handler"
  filename      = "send_message.zip" # Pre-packaged zip file of your Lambda code

  environment {
    variables = {
      CHAT_TABLE = aws_dynamodb_table.chat_messages.name
    }
  }
}

# API Gateway WebSocket API
resource "aws_apigatewayv2_api" "websocket_api" {
    name = "ChatAppWebSocketAPI"
    protocol_type = "WEBSOCKET"
    route_selection_expression = "$request.body.action"
}

#API Gateway Routes
resource "aws_apigatewayv2_route" "connect_route" {
    api_id = aws_apigatewayv2_api.websocket_api.id
    route_key = "$connect"
    target = aws_lambda_function.connect_handler.arn
}

resource "aws_apigatewayv2_route" "disconnect_route" {
    api_id = aws_apigatewayv2_api.websocket_api.id
    route_key = "$disconnect"
    target = aws_lambda_function.disconnect_handler.arn
}

resource "aws_apigatewayv2_route" "send_message_route" {
    api_id = aws_apigatewayv2_api.websocket_api.id
    route_key = "sendMessage"
    target = aws_lambda_function.send_message_handler.arn
}

# Deploy API Gateway
resource "aws_apigatewayv2_stage" "websocket_stage" {
    api_id = aws_apigatewayv2_api.websocket_api.id
    name = "production"
    auto_deploy = true
}

#Permissions for API Gateway to Invoke Lambda
resource "aws_lambda_permission" "apigateway_connect" {
    statement_id = "AllowAPIGatewayInvokeConnect"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.connect_handler.function_name
    principal = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "apigateway_disconnect" {
    statement_id = "AllowAPIGatewayInvokeDisconnect"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.disconnect_handler.function_name
    principal = "apigateway.amazonaws.com"
}


resource "aws_lambda_permission" "apigateway_send_message" {
  statement_id  = "AllowAPIGatewayInvokeSendMessage"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_message_handler.function_name
  principal     = "apigateway.amazonaws.com"
}
