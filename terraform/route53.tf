module "blog-backend-certificate" {
  source = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = terraform.workspace == "main" ? "api.mysticalforestcat.com" : "dev.mysticalforestcat.com"
  zone_id     = local.route53_zone_id

  validation_method = "DNS"

  wait_for_validation = true
}

resource "aws_route53_record" "blog-backend-route" {
    zone_id = local.route53_zone_id
    name    = aws_api_gateway_domain_name.blog-backend-domain.domain_name
    type    = "A"

    alias {
        name                   = aws_api_gateway_domain_name.blog-backend-domain.regional_domain_name
        zone_id                = aws_api_gateway_domain_name.blog-backend-domain.regional_zone_id
        evaluate_target_health = false
    }
}