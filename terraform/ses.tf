resource "aws_ses_domain_identity" "site" {
  domain = var.domain_name
}

resource "aws_route53_record" "ses_domain_verification" {
  zone_id = data.aws_route53_zone.site.zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  records = [aws_ses_domain_identity.site.verification_token]
}

resource "aws_ses_domain_identity_verification" "site" {
  domain = aws_ses_domain_identity.site.id

  depends_on = [
    aws_route53_record.ses_domain_verification,
  ]
}

resource "aws_ses_domain_dkim" "site" {
  domain = aws_ses_domain_identity.site.domain
}

resource "aws_ses_email_identity" "forward_to" {
  email = var.forward_to_email
}

resource "aws_route53_record" "ses_dkim" {
  count   = 3
  zone_id = data.aws_route53_zone.site.zone_id
  name    = "${aws_ses_domain_dkim.site.dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_ses_domain_dkim.site.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "ses_inbound_mx" {
  zone_id = data.aws_route53_zone.site.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 300
  records = [
    "10 inbound-smtp.${var.aws_region}.amazonaws.com",
  ]
}
