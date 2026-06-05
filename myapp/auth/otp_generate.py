import random
import hashlib
import os

from dotenv import load_dotenv
import sib_api_v3_sdk
from sib_api_v3_sdk.rest import ApiException

load_dotenv()


def generate_otp():
    return str(random.randint(100000, 999999))


def hash_otp(otp):
    return hashlib.sha256(otp.encode()).hexdigest()


def send_otp(email, otp):

    api_key = os.getenv("BREVO_API_KEY")

    if not api_key:
        raise Exception("BREVO_API_KEY not found")

    configuration = sib_api_v3_sdk.Configuration()
    configuration.api_key["api-key"] = api_key

    api_client = sib_api_v3_sdk.ApiClient(configuration)
    api_instance = sib_api_v3_sdk.TransactionalEmailsApi(api_client)

    html_content = f"""
    <html>
    <body>
        <h2>StocBuy Email Verification</h2>

        <p>Hello,</p>

        <p>Your OTP code is:</p>

        <div style="
            font-size:32px;
            font-weight:bold;
            letter-spacing:5px;
            padding:15px;
            background:#f5f5f5;
            display:inline-block;
            border-radius:8px;
        ">
            {otp}
        </div>

        <p>This OTP is valid for 5 minutes.</p>

        <p>Do not share this code with anyone.</p>

        <br>

        <p>Regards,</p>
        <p><strong>StocBuy Team</strong></p>
    </body>
    </html>
    """

    send_smtp_email = sib_api_v3_sdk.SendSmtpEmail(
        to=[{"email": email}],
        sender={
            "name": "StocBuy",
            "email": os.getenv(
                "EMAIL_HOST_USER",
                "stocbuyofficial@gmail.com"
            )
        },
        subject="Your StocBuy OTP Code",
        html_content=html_content,
        text_content=f"Your OTP is {otp}"
    )

    try:
        response = api_instance.send_transac_email(
            send_smtp_email
        )

        print("Email sent successfully")
        print(response)

        return True

    except ApiException as e:
        print("Brevo Error:")
        print(e.body)

        raise Exception(
            f"Failed to send OTP email: {str(e)}"
        )