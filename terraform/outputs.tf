output "site_bucket_name" {
  description = "Name of the S3 bucket for static blog assets."
  value       = aws_s3_bucket.site.bucket
}

output "site_bucket_arn" {
  description = "ARN of the S3 bucket for static blog assets."
  value       = aws_s3_bucket.site.arn
}

output "site_bucket_regional_domain_name" {
  description = "Regional S3 domain name to use later as the CloudFront origin."
  value       = aws_s3_bucket.site.bucket_regional_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution serving the blog."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution allowed to read the private S3 bucket."
  value       = aws_cloudfront_distribution.site.arn
}

output "cloudfront_domain_name" {
  description = "Temporary CloudFront domain name for viewing the blog before adding a custom domain."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "site_domain_name" {
  description = "Custom domain name for the blog."
  value       = var.domain_name
}

output "site_url" {
  description = "HTTPS URL for the custom blog domain."
  value       = "https://${var.domain_name}"
}

output "cloudfront_logs_bucket_name" {
  description = "S3 bucket receiving CloudFront access logs."
  value       = aws_s3_bucket.cloudfront_logs.bucket
}

output "cloudfront_logs_prefix" {
  description = "S3 prefix where CloudFront access logs are stored."
  value       = var.cloudfront_logs_prefix
}

output "athena_database_name" {
  description = "Athena database for CloudFront access logs."
  value       = aws_glue_catalog_database.cloudfront_logs.name
}

output "athena_cloudfront_table_name" {
  description = "Athena table for CloudFront standard access logs."
  value       = aws_glue_catalog_table.cloudfront_standard_logs.name
}

output "athena_workgroup_name" {
  description = "Athena workgroup for CloudFront log analysis."
  value       = aws_athena_workgroup.cloudfront_logs.name
}

output "ses_domain_identity_arn" {
  description = "SES domain identity ARN for the blog domain."
  value       = aws_ses_domain_identity.site.arn
}

output "ses_inbound_mx_record" {
  description = "MX record used to route inbound email to Amazon SES."
  value       = aws_route53_record.ses_inbound_mx.records
}

output "ses_forward_to_email_identity" {
  description = "SES email identity that must be verified while SES is in sandbox."
  value       = aws_ses_email_identity.forward_to.email
}

output "contact_email_address" {
  description = "Domain email address handled by SES receipt rules."
  value       = local.contact_email_address
}

output "inbound_email_bucket_name" {
  description = "S3 bucket storing raw inbound SES emails."
  value       = aws_s3_bucket.inbound_email.bucket
}

output "ses_forwarder_lambda_name" {
  description = "Lambda function forwarding inbound SES emails."
  value       = aws_lambda_function.ses_forwarder.function_name
}

output "alerts_topic_arn" {
  description = "SNS topic ARN used by CloudWatch alarms."
  value       = aws_sns_topic.alerts.arn
}

output "alerts_email_address" {
  description = "Email address subscribed to infrastructure alerts."
  value       = local.alert_email_address
}

output "github_actions_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions blog deployments."
  value       = aws_iam_role.github_actions_deploy.arn
}
