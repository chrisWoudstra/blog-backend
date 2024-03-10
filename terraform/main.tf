terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    archive = {
      source = "hashicorp/archive"
    }
    null = {
      source = "hashicorp/null"
    }
  }

    required_version = ">= 1.3.7"
}

provider "aws" {
  region = local.region
  access_key = local.aws_access_key
  secret_key = local.aws_secret_key

  default_tags {
    tags = {
      app = "blog-backend"
    }
  }
}
