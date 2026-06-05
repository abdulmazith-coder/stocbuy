import secrets
import hashlib
import os
import sib_api_v3_sdk
from sib_api_v3_sdk.rest import ApiException
from dotenv import load_dotenv
 
load_dotenv()
 
# OPTIMIZED: build client once at import time, not on every send_otp() call
_brevo_config = sib_api_v3_sdk.Configuration()
_brevo_config.api_key['api-key'] = os.getenv('BREVO_API_KEY')
_brevo_client = sib_api_v3_sdk.ApiClient(_brevo_config)
_brevo_api = sib_api_v3_sdk.TransactionalEmailsApi(_brevo_client)
 
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
    # OPTIMIZED: secrets module → cryptographically secure random
    return str(secrets.randbelow(900000) + 100000)
 
 
def hash_otp(otp: str) -> str:
    return hashlib.sha256(otp.encode()).hexdigest()
 
 
def send_otp(email: str, otp: str) -> None:
    send_smtp_email = sib_api_v3_sdk.SendSmtpEmail(
        to=[{"email": email}],
        sender={
            "name": "StocBuy",
            "email": os.environ.get('EMAIL_HOST_USER', 'stocbuyofficial@gmail.com'),
        },
        subject="Your StocBuy OTP Code (Valid for 5 Minutes)",
        html_content=_OTP_HTML_TEMPLATE.format(otp=otp),
        text_content=f"Your OTP is {otp}",
    )
    try:
        _brevo_api.send_transac_email(send_smtp_email)
    except ApiException as e:
        raise Exception(f"Failed to send OTP email: {str(e)}")
 
