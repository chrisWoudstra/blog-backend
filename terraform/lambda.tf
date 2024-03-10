locals {
  binary_path = "${path.module}/zip"
}


resource "null_resource" "blog-get-posts-binary" {
  provisioner "local-exec" {
    command = "GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap main.go"
    working_dir = "${path.module}/../lambda/blog-get-posts"
  }
}

module "blog-get-posts" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 6.0"

  function_name = "${terraform.workspace}-blog-gets-posts"
  handler = "hello.handler"
  runtime = "provided.al2023"
  timeout = 30
  publish = true
  memory_size = 128

  source_path = "${path.module}/../lambda/blog-get-posts/bootstrap"

  vpc_security_group_ids = local.security_groups
  vpc_subnet_ids = local.subnet_ids
  attach_network_policy = true

  environment_variables = {
    DATABASE_URL = local.rds_dsn
  }

  assume_role_policy_statements = {
    account_root = {
      effect  = "Allow",
      actions = ["sts:AssumeRole"],
      principals = [{
        type = "Service",
        identifiers = ["lambda.amazonaws.com", "apigateway.amazonaws.com"]
      }]
    }
  }

  allowed_triggers = {
    APIGatewayAccess = {
      service = "apigateway",
      source_arn = "${aws_api_gateway_rest_api.blog-backend.execution_arn}/*/*"
    }
  }

  depends_on = [
    null_resource.blog-get-posts-binary
  ]
}