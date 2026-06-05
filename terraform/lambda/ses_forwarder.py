import boto3
import email
import os
import re
from email.message import EmailMessage
from email.policy import default


s3 = boto3.client("s3")
ses = boto3.client("ses")


def get_message_body(message):
    if message.is_multipart():
        for part in message.walk():
            if part.get_content_disposition() == "attachment":
                continue
            if part.get_content_type() == "text/plain":
                return part.get_content()

        for part in message.walk():
            if part.get_content_disposition() == "attachment":
                continue
            if part.get_content_type() == "text/html":
                return html_to_text(part.get_content())

        return "(No readable message body found.)"

    if message.get_content_type() == "text/plain":
        return message.get_content()

    if message.get_content_type() == "text/html":
        return html_to_text(message.get_content())

    return "(No readable message body found.)"


def html_to_text(html):
    text = re.sub(r"(?is)<(script|style).*?>.*?</\1>", "", html)
    text = re.sub(r"(?i)<br\s*/?>", "\n", text)
    text = re.sub(r"(?i)</p>", "\n\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def lambda_handler(event, context):
    record = event["Records"][0]["ses"]
    mail = record["mail"]
    receipt = record["receipt"]

    bucket = os.environ["MAIL_BUCKET"]
    prefix = os.environ.get("MAIL_PREFIX", "").strip("/")
    recipient = os.environ["FORWARD_TO"]
    source = os.environ["FORWARD_FROM"]

    message_id = mail["messageId"]
    key = f"{prefix}/{message_id}" if prefix else message_id

    raw_object = s3.get_object(Bucket=bucket, Key=key)
    raw_message = raw_object["Body"].read()
    original = email.message_from_bytes(raw_message, policy=default)

    original_from = original.get("From", "unknown sender")
    original_subject = original.get("Subject", "(no subject)")
    original_body = get_message_body(original)

    forwarded = EmailMessage()
    forwarded["From"] = source
    forwarded["To"] = recipient
    forwarded["Reply-To"] = original_from
    forwarded["Subject"] = f"Fwd: {original_subject}"

    delivered_to = ", ".join(receipt.get("recipients", []))
    body = [
        f"Forwarded from: {original_from}",
        f"Delivered to: {delivered_to}",
        "",
        "----- Original message -----",
        "",
        original_body,
    ]
    forwarded.set_content("\n".join(body))

    ses.send_raw_email(
        Source=source,
        Destinations=[recipient],
        RawMessage={"Data": forwarded.as_bytes()},
    )

    return {
        "messageId": message_id,
        "forwardedTo": recipient,
    }
