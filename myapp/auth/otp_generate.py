import random
import hashlib
import os
import sib_api_v3_sdk
from sib_api_v3_sdk.rest import ApiException
from dotenv import load_dotenv

load_dotenv()


def generate_otp():
    return str(random.randint(100000, 999999))


def hash_otp(otp):
    return hashlib.sha256(otp.encode()).hexdigest()


def send_otp(email, otp):
    configuration = sib_api_v3_sdk.Configuration()
    configuration.api_key['api-key'] = os.getenv('BREVO_API_KEY')

    api_instance = sib_api_v3_sdk.TransactionalEmailsApi(
        sib_api_v3_sdk.ApiClient(configuration)
    )

    html_content = f"""
    <html>
        <body>
            <p>Hi,</p>
            <p>Your One-Time Password (OTP) for verifying your email on <b>StocBuy</b> is:</p>
            <div style="
                font-size: 25px;
                margin-top: 20px;
                margin-bottom: 20px;
                letter-spacing: 3px;
                font-weight: bold;
            ">
                {otp}
            </div>
            <p>This OTP is valid for 5 minutes. Please do not share this code with anyone.</p>
            <p>If you did not request this, you can safely ignore this email.</p>
            <p>Thanks,<br>StocBuy Team</p>
        </body>
    </html>
    """

    send_smtp_email = sib_api_v3_sdk.SendSmtpEmail(
        to=[{"email": email}],
        sender={
            "name": "StocBuy",
            "email": os.environ.get('EMAIL_HOST_USER', 'stocbuyofficial@gmail.com')
        },
        subject="Your StocBuy OTP Code (Valid for 5 Minutes)",
        html_content=html_content,
        text_content=f"Your OTP is {otp}"
    )

    try:
        api_instance.send_transac_email(send_smtp_email)
        print(f"OTP sent successfully to {email}")
    except ApiException as e:
        print(f"Brevo email failed: {e}")
        raise Exception(f"Failed to send OTP email: {str(e)}")