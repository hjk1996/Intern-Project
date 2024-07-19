resource "aws_route53_zone" "main" {
  count = var.enable_dns ? 1 : 0
  name  = var.zone_name
}

resource "aws_acm_certificate" "main" {
  count             = var.enable_dns ? 1 : 0
  domain_name       = "*.${var.zone_name}"
  validation_method = "DNS"
}


resource "aws_route53_record" "dns_validation" {
  for_each = var.enable_dns ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
    } : {

  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main[0].zone_id
}


resource "aws_acm_certificate_validation" "main" {
  count                   = var.enable_dns ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.dns_validation : record.fqdn]


  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_route53_record" "alb" {
  count   = var.enable_dns ? 1 : 0
  zone_id = aws_route53_zone.main[0].zone_id
  name    = "madang.${var.zone_name}"
  type    = "CNAME"
  ttl     = "60"
  records = [var.lb_dns]
}