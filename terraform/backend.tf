// api gateway

resource "aws_apigatewayv2_api" "crc_api_gateway" {
  name          = "crc-api-gateway"
  protocol_type = "HTTP"
  target        = aws_lambda_function.fn_lambda.arn
  cors_configuration {
    allow_origins = ["${var.FRONTEND_DOMAIN_NAME}"] 
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.crc_api_gateway.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.fn_lambda.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_route" {
  api_id    = aws_apigatewayv2_api.crc_api_gateway.id
  route_key = "GET /crc"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "crc_lambda_api" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.crc_api_gateway.execution_arn}/*/*/crc"
}

resource "aws_apigatewayv2_domain_name" "crc_api_dname" {
  domain_name = var.BACKEND_DOMAIN_NAME

  domain_name_configuration {
    certificate_arn = var.CERT_ARN
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "crc_api_mapping" {
  api_id      = aws_apigatewayv2_api.crc_api_gateway.id
  domain_name = aws_apigatewayv2_domain_name.crc_api_dname.id
  stage       = "$default"
}

// lambda

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_role_policy" {
  statement {
    effect    = "Allow"
    resources = ["${aws_dynamodb_table.crc_dydb_rs.arn}", "${aws_dynamodb_table.crc_dydb_rs.arn}/*"]
    actions   = ["dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:PutItem"]
  }
}

data "aws_iam_policy_document" "lambda_role_policy_dydb" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role" "iam_lambda" {
  name               = "iam-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy_dydb"
  role = aws_iam_role.iam_lambda.id

  policy = data.aws_iam_policy_document.lambda_role_policy.json
}

resource "aws_iam_role_policy" "lambda_policy_cw" {
  name = "lambda_policy_cw"
  role = aws_iam_role.iam_lambda.id

  policy = data.aws_iam_policy_document.lambda_role_policy_dydb.json
}

resource "aws_lambda_function" "fn_lambda" {
  filename      = "view_counter.zip"
  function_name = "view_counter"
  role          = aws_iam_role.iam_lambda.arn
  handler       = "view_counter.lambda_handler"

  runtime = "python3.10"
}

// db

resource "aws_dynamodb_table" "crc_dydb_rs" {
  name           = "aws-cloud-resume-challenge"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "crc_dbitem_rs" {
  table_name = aws_dynamodb_table.crc_dydb_rs.name
  hash_key   = aws_dynamodb_table.crc_dydb_rs.hash_key

  item = <<ITEM
    {
        "id": {
            "S": "view_count"
        },
        "views": {
            "N": "0"
        }
    }
  ITEM
}