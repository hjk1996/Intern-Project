
resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-alb-waf"
  scope = "REGIONAL"


  default_action {
    allow {}

  }


  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1



    override_action {
      count {

      }

    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }



  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "friendly-metric-name"
    sampled_requests_enabled   = false
  }
}


resource "aws_wafv2_web_acl_association" "alb" {
  web_acl_arn  = aws_wafv2_web_acl.main.arn
  resource_arn = var.alb_arn
}