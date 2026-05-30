import random
import hashlib
from django.core.mail import EmailMultiAlternatives, send_mail

def generate_otp():
    return str(random.randint(100000, 999999))

def hash_otp(otp):
    return hashlib.sha256(otp.encode()).hexdigest()


def send_otp(email, otp):
    subject = 'Your StocBuy OTP Code (Valid for 5 Minutes)'
    from_email = 'stocbuyofficial@gmail.com'

    text_content = f'Your OTP is {otp}'

    html_content = f"""
    <html>
        <body>
            <p>Hi,</p>

            <p>Your One-Time Password (OTP) for verifying your email on <b>StocBuy</b> is:</p>

            <div style="
                font-size: 25px;        /* small font */
                margin-top: 20px;       /* space above */
                margin-bottom: 20px;    /* space below */
                letter-spacing: 3px;    /* spacing between digits */
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

    msg = EmailMultiAlternatives(subject, text_content, from_email, [email])
    msg.attach_alternative(html_content, "text/html")
    msg.send()