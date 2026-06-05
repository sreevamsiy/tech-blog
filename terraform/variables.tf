variable "aws_region" {
  description = "AWS region where the S3 bucket will be created."
  type        = string
  default     = "us-east-1"
}

variable "site_bucket_name" {
  description = "Globally unique S3 bucket name for the static blog assets."
  type        = string
}

variable "domain_name" {
  description = "Apex domain name for the blog."
  type        = string
  default     = "sreevamsi.dev"
}

variable "project_name" {
  description = "Project tag value."
  type        = string
  default     = "tech-blog"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "prod"
}

variable "cloudfront_price_class" {
  description = "CloudFront edge location price class. PriceClass_100 is the lowest-cost option."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition = contains([
      "PriceClass_100",
      "PriceClass_200",
      "PriceClass_All",
    ], var.cloudfront_price_class)
    error_message = "cloudfront_price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "cloudfront_logs_bucket_name" {
  description = "Optional globally unique bucket name for CloudFront access logs. Defaults to site_bucket_name-cloudfront-logs."
  type        = string
  default     = null
}

variable "cloudfront_logs_prefix" {
  description = "S3 prefix for CloudFront access logs."
  type        = string
  default     = "cloudfront/"
}

variable "cloudfront_logs_retention_days" {
  description = "Number of days to retain CloudFront access logs."
  type        = number
  default     = 60
}

variable "athena_database_name" {
  description = "Glue Data Catalog database name for Athena CloudFront log queries."
  type        = string
  default     = "tech_blog_logs"
}

variable "athena_cloudfront_table_name" {
  description = "Glue Data Catalog table name for CloudFront standard access logs."
  type        = string
  default     = "cloudfront_standard_logs"
}

variable "athena_workgroup_name" {
  description = "Athena workgroup name for CloudFront log analysis."
  type        = string
  default     = "tech-blog-cloudfront-logs"
}

variable "athena_results_prefix" {
  description = "S3 prefix for Athena query results."
  type        = string
  default     = "athena-results/"
}

variable "athena_results_retention_days" {
  description = "Number of days to retain Athena query result files."
  type        = number
  default     = 30
}

variable "google_site_verification" {
  description = "Google Search Console domain verification TXT value."
  type        = string
  default     = ""
}

variable "contact_email_local_part" {
  description = "Local part for the domain contact email address."
  type        = string
  default     = "hello"
}

variable "forward_to_email" {
  description = "External email address where inbound domain email should be forwarded."
  type        = string
  default     = ""
}

variable "inbound_email_bucket_name" {
  description = "Optional globally unique bucket name for raw inbound SES emails. Defaults to site_bucket_name-inbound-email."
  type        = string
  default     = null
}

variable "inbound_email_prefix" {
  description = "S3 prefix where SES stores raw inbound emails."
  type        = string
  default     = "inbound/"
}

variable "inbound_email_retention_days" {
  description = "Number of days to retain raw inbound emails."
  type        = number
  default     = 30
}

variable "ses_receipt_rule_set_name" {
  description = "SES receipt rule set name for inbound email."
  type        = string
  default     = "tech-blog-inbound-email"
}

variable "ses_receipt_rule_name" {
  description = "SES receipt rule name for forwarding the contact address."
  type        = string
  default     = "forward-hello-to-gmail"
}

variable "ses_forwarder_lambda_name" {
  description = "Lambda function name for forwarding inbound SES emails."
  type        = string
  default     = "tech-blog-ses-forwarder"
}

variable "lambda_log_retention_days" {
  description = "CloudWatch Logs retention in days for Lambda log groups."
  type        = number
  default     = 14
}

variable "alert_email_address" {
  description = "Email address subscribed to blog infrastructure alerts. Defaults to forward_to_email."
  type        = string
  default     = null
}

variable "alert_topic_name" {
  description = "SNS topic name for blog infrastructure alerts."
  type        = string
  default     = "tech-blog-alerts"
}

variable "monthly_budget_limit_usd" {
  description = "Monthly AWS budget limit in USD."
  type        = number
  default     = 10
}

variable "cloudfront_5xx_error_rate_threshold_percent" {
  description = "CloudFront 5xx error rate threshold percentage."
  type        = number
  default     = 1
}

variable "cloudfront_4xx_error_rate_threshold_percent" {
  description = "CloudFront 4xx error rate threshold percentage."
  type        = number
  default     = 10
}

variable "enable_cloudfront_4xx_alarm" {
  description = "Whether to create the CloudFront 4xx error rate alarm."
  type        = bool
  default     = false
}

variable "github_repository_owner" {
  description = "GitHub username or organization that owns the blog repository."
  type        = string
  default     = "sreevamsiy"
}

variable "github_repository_name" {
  description = "GitHub repository name allowed to deploy the blog."
  type        = string
  default     = "tech-blog"
}

variable "github_deploy_branch" {
  description = "GitHub branch allowed to deploy the blog."
  type        = string
  default     = "main"
}
