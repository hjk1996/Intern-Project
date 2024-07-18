output "certificate_arn" {
  value = var.enable_dns ?  aws_acm_certificate.main[0].arn : null
}