resource "aws_api_gateway_rest_api" "blog-backend" {
  name        = "${terraform.workspace}-blog-backend"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  depends_on = [
    module.blog-get-posts.lambda_function_arn
  ]
}

resource "aws_api_gateway_rest_api_policy" "blog-backend-policy" {
  count = terraform.workspace == "main" ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.blog-backend.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "execute-api:Invoke",
            "Resource": "arn:aws:execute-api:*:*:*"
        }
    ]
}
EOF
}

resource "aws_api_gateway_resource" "blog-get-posts" {
  rest_api_id = aws_api_gateway_rest_api.blog-backend.id
  parent_id   = aws_api_gateway_rest_api.blog-backend.root_resource_id
  path_part   = "posts"
}

resource "aws_api_gateway_request_validator" "blog-get-posts-validator" {
  name                        = "${terraform.workspace}-blog-get-posts-validator"
  rest_api_id                 = aws_api_gateway_rest_api.blog-backend.id
  validate_request_body       = true
  validate_request_parameters = true
}

resource "aws_api_gateway_method" "blog-get-posts-method" {
  rest_api_id   = aws_api_gateway_rest_api.blog-backend.id
  resource_id   = aws_api_gateway_resource.blog-get-posts.id
  http_method   = "GET"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.blog-get-posts-validator.id

  request_parameters = {
    "method.request.querystring.slug" = false
    "method.request.querystring.sort" = false
    "method.request.querystring.limit" = false
    "method.request.querystring.page" = false
  }
}

resource "aws_api_gateway_integration" "blog-get-posts-integration" {
  rest_api_id             = aws_api_gateway_rest_api.blog-backend.id
  resource_id             = aws_api_gateway_resource.blog-get-posts.id
  http_method             = aws_api_gateway_method.blog-get-posts-method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${local.region}:lambda:path/2015-03-31/functions/${module.blog-get-posts.lambda_function_arn}/invocations"
  cache_key_parameters = [
    "method.request.querystring.slug",
    "method.request.querystring.sort",
    "method.request.querystring.limit",
    "method.request.querystring.page",
  ]
  request_templates = {
    "application/json" = <<REQUEST_TEMPLATE
      {
        "slug": "$input.params('slug')",
        "sort": "$input.params('sort')",
        "limit": "$input.params('limit')",
        "page": "$input.params('page')"
      }
    REQUEST_TEMPLATE
  }
}

resource "aws_api_gateway_integration_response" "blog-get-posts-integration-response" {
  rest_api_id = aws_api_gateway_rest_api.blog-backend.id
  resource_id = aws_api_gateway_resource.blog-get-posts.id
  http_method = aws_api_gateway_method.blog-get-posts-method.http_method
  status_code = 200
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  depends_on = [
    aws_api_gateway_integration.blog-get-posts-integration
  ]

  response_templates = {
    "application/json" = <<EOF
      #set($context.responseOverride.status = $input.path('$.statusCode'))
      $input.json('$')
    EOF
  }
}

resource "aws_api_gateway_method_response" "blog-get-posts-method-response" {
  rest_api_id = aws_api_gateway_rest_api.blog-backend.id
  resource_id = aws_api_gateway_resource.blog-get-posts.id
  http_method = aws_api_gateway_method.blog-get-posts-method.http_method
  status_code = 200
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_domain_name" "blog-backend-domain" {
  domain_name = terraform.workspace == "main" ? "mysticalforestcat.com" : "dev.mysticalforestcat.com"
  regional_certificate_arn = terraform.workspace == "main" ? local.api_domain_certificate_arn: local.api_domain_certificate_arn_dev

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "blog-backend-deployment" {
  rest_api_id = aws_api_gateway_rest_api.blog-backend.id

  depends_on = [
    aws_api_gateway_method.blog-get-posts-method,
    aws_api_gateway_integration.blog-get-posts-integration
  ]

  triggers = {
    redeployment = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "blog-backend-stage" {
  deployment_id = aws_api_gateway_deployment.blog-backend-deployment.id
  rest_api_id   = aws_api_gateway_rest_api.blog-backend.id
  stage_name    = "blog"

  cache_cluster_enabled = terraform.workspace == "main" ? true : false
  cache_cluster_size    = terraform.workspace == "main" ? "0.5" : null
}

resource "aws_api_gateway_method_settings" "blog-backend-settings" {
  rest_api_id = aws_api_gateway_rest_api.blog-backend.id
  stage_name = aws_api_gateway_stage.blog-backend-stage.stage_name
  method_path = "*/*"

  settings {
    data_trace_enabled = true
    throttling_burst_limit = 5000
    throttling_rate_limit = 10000
  }
}

resource "aws_api_gateway_base_path_mapping" "blog-backend-base-path-mapping" {
  api_id = aws_api_gateway_rest_api.blog-backend.id
  stage_name  = aws_api_gateway_stage.blog-backend-stage.stage_name
  domain_name = aws_api_gateway_domain_name.blog-backend-domain.domain_name
}