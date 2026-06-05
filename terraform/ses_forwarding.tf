locals {
  inbound_email_bucket_name = coalesce(var.inbound_email_bucket_name, "${var.site_bucket_name}-inbound-email")
  contact_email_address     = "${var.contact_email_local_part}@${var.domain_name}"
  ses_receipt_rule_arn      = "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:receipt-rule-set/${var.ses_receipt_rule_set_name}:receipt-rule/${var.ses_receipt_rule_name}"
}

data "aws_caller_identity" "current" {}

data "archive_file" "ses_forwarder" {
  type        = "zip"
  source_file = "${path.module}/lambda/ses_forwarder.py"
  output_path = "${path.module}/.terraform/ses_forwarder.zip"
}

resource "aws_s3_bucket" "inbound_email" {
  bucket = local.inbound_email_bucket_name

  tags = {
    Name        = local.inbound_email_bucket_name
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "SES inbound email"
  }
}

resource "aws_s3_bucket_ownership_controls" "inbound_email" {
  bucket = aws_s3_bucket.inbound_email.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "inbound_email" {
  bucket = aws_s3_bucket.inbound_email.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "inbound_email" {
  bucket = aws_s3_bucket.inbound_email.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "inbound_email" {
  bucket = aws_s3_bucket.inbound_email.id

  rule {
    id     = "expire-inbound-email"
    status = "Enabled"

    filter {
      prefix = var.inbound_email_prefix
    }

    expiration {
      days = var.inbound_email_retention_days
    }
  }
}

data "aws_iam_policy_document" "allow_ses_write_inbound_email" {
  statement {
    sid = "AllowSESPutObject"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.inbound_email.arn}/${var.inbound_email_prefix}*",
    ]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [local.ses_receipt_rule_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_ses_write_inbound_email" {
  bucket = aws_s3_bucket.inbound_email.id
  policy = data.aws_iam_policy_document.allow_ses_write_inbound_email.json
}

resource "aws_cloudwatch_log_group" "ses_forwarder" {
  name              = "/aws/lambda/${var.ses_forwarder_lambda_name}"
  retention_in_days = var.lambda_log_retention_days
}

data "aws_iam_policy_document" "ses_forwarder_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ses_forwarder" {
  name               = "${var.project_name}-${var.environment}-ses-forwarder"
  assume_role_policy = data.aws_iam_policy_document.ses_forwarder_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ses-forwarder"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "ses_forwarder" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "${aws_cloudwatch_log_group.ses_forwarder.arn}:*",
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.inbound_email.arn}/${var.inbound_email_prefix}*",
    ]
  }

  statement {
    actions = [
      "ses:SendRawEmail",
    ]

    resources = [
      "*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ses:FromAddress"
      values   = [local.contact_email_address]
    }
  }
}

resource "aws_iam_role_policy" "ses_forwarder" {
  name   = "${var.project_name}-${var.environment}-ses-forwarder"
  role   = aws_iam_role.ses_forwarder.id
  policy = data.aws_iam_policy_document.ses_forwarder.json
}

resource "aws_lambda_function" "ses_forwarder" {
  function_name    = var.ses_forwarder_lambda_name
  role             = aws_iam_role.ses_forwarder.arn
  handler          = "ses_forwarder.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.ses_forwarder.output_path
  source_code_hash = data.archive_file.ses_forwarder.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      FORWARD_FROM = local.contact_email_address
      FORWARD_TO   = var.forward_to_email
      MAIL_BUCKET  = aws_s3_bucket.inbound_email.bucket
      MAIL_PREFIX  = var.inbound_email_prefix
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.ses_forwarder,
    aws_iam_role_policy.ses_forwarder,
  ]

  tags = {
    Name        = var.ses_forwarder_lambda_name
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_lambda_permission" "allow_ses_invoke_forwarder" {
  statement_id   = "AllowExecutionFromSES"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.ses_forwarder.function_name
  principal      = "ses.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_ses_receipt_rule_set" "site" {
  rule_set_name = var.ses_receipt_rule_set_name
}

resource "aws_ses_active_receipt_rule_set" "site" {
  rule_set_name = aws_ses_receipt_rule_set.site.rule_set_name
}

resource "aws_ses_receipt_rule" "forward_contact_email" {
  name          = var.ses_receipt_rule_name
  rule_set_name = aws_ses_receipt_rule_set.site.rule_set_name
  recipients    = [local.contact_email_address]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = aws_s3_bucket.inbound_email.bucket
    object_key_prefix = var.inbound_email_prefix
    position          = 1
  }

  lambda_action {
    function_arn    = aws_lambda_function.ses_forwarder.arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_lambda_permission.allow_ses_invoke_forwarder,
    aws_s3_bucket_policy.allow_ses_write_inbound_email,
    aws_ses_domain_identity_verification.site,
  ]
}
