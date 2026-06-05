import secrets
import hashlib
import os
import sib_api_v3_sdk
from sib_api_v3_sdk.rest import ApiException

_OTP_HTML_TEMPLATE = """
<html><body>
<p>Hi,</p>
<p>Your One-Time Password (OTP) for verifying your email on <b>StocBuy</b> is:</p>
<div style="font-size:25px;margin:20px 0;letter-spacing:3px;font-weight:bold;">{otp}</div>
<p>This OTP is valid for 5 minutes. Please do not share this code with anyone.</p>
<p>If you did not request this, you can safely ignore this email.</p>
<p>Thanks,<br>StocBuy Team</p>
</body></html>
"""


def generate_otp() -> str:
    return str(secrets.randbelow(900000) + 100000)


def hash_otp(otp: str) -> str:
    return hashlib.sha256(otp.encode()).hexdigest()


def _get_brevo_api() -> sib_api_v3_sdk.TransactionalEmailsApi:
    """Build a fresh Brevo API client each call so the key is always read from env."""
    api_key = os.environ.get('BREVO_API_KEY')
    if not api_key:
        raise Exception(
            "BREVO_API_KEY is not set. "
            "Add it to your .env file or system environment variables."
        )
    config = sib_api_v3_sdk.Configuration()
    config.api_key['api-key'] = api_key
    return sib_api_v3_sdk.TransactionalEmailsApi(sib_api_v3_sdk.ApiClient(config))


def send_otp(email: str, otp: str) -> None:
    sender_email = os.environ.get('EMAIL_HOST_USER', 'stocbuyofficial@gmail.com')

    send_smtp_email = sib_api_v3_sdk.SendSmtpEmail(
        to=[{"email": email}],
        sender={"name": "StocBuy", "email": sender_email},
        subject="Your StocBuy OTP Code (Valid for 5 Minutes)",
        html_content=_OTP_HTML_TEMPLATE.format(otp=otp),
        text_content=f"Your OTP is {otp}",
    )
    try:
        _get_brevo_api().send_transac_email(send_smtp_email)
    except ApiException as e:
        raise Exception(f"Failed to send OTP email: {str(e)}")