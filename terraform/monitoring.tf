locals {
  alert_email_address = coalesce(var.alert_email_address, var.forward_to_email)
}

resource "aws_sns_topic" "alerts" {
  name = var.alert_topic_name

  tags = {
    Name        = var.alert_topic_name
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = local.alert_email_address
}

resource "aws_budgets_budget" "monthly_cost" {
  name         = "${var.project_name}-${var.environment}-monthly-cost"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [local.alert_email_address]
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-cloudfront-5xx-error-rate"
  alarm_description   = "CloudFront 5xx error rate is above ${var.cloudfront_5xx_error_rate_threshold_percent}%."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = var.cloudfront_5xx_error_rate_threshold_percent
  treat_missing_data  = "notBreaching"

  namespace   = "AWS/CloudFront"
  metric_name = "5xxErrorRate"
  statistic   = "Average"
  period      = 300

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx_error_rate" {
  count               = var.enable_cloudfront_4xx_alarm ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-cloudfront-4xx-error-rate"
  alarm_description   = "CloudFront 4xx error rate is above ${var.cloudfront_4xx_error_rate_threshold_percent}%."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = var.cloudfront_4xx_error_rate_threshold_percent
  treat_missing_data  = "notBreaching"

  namespace   = "AWS/CloudFront"
  metric_name = "4xxErrorRate"
  statistic   = "Average"
  period      = 300

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ses_forwarder_lambda_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-ses-forwarder-lambda-errors"
  alarm_description   = "SES forwarder Lambda has one or more errors."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  treat_missing_data  = "notBreaching"

  namespace   = "AWS/Lambda"
  metric_name = "Errors"
  statistic   = "Sum"
  period      = 300

  dimensions = {
    FunctionName = aws_lambda_function.ses_forwarder.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_function_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-cloudfront-function-errors"
  alarm_description   = "CloudFront Function has one or more execution errors."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  treat_missing_data  = "notBreaching"

  namespace   = "AWS/CloudFront"
  metric_name = "FunctionExecutionErrors"
  statistic   = "Sum"
  period      = 300

  dimensions = {
    FunctionName = aws_cloudfront_function.rewrite_hugo_urls.name
    Region       = "Global"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
