from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from myapp.auth.models import Users, Otp
from myapp.auth.otp_generate import generate_otp, hash_otp, send_otp
from rest_framework.permissions import AllowAny


class SignupView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email')
        username = request.data.get('username')
        password = request.data.get('password')

        if not email or not username or not password:
            return Response(
                {'error': 'Email, username and password are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if Users.objects.filter(email=email).exists():
            return Response(
                {'error': 'Email already exists'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user = Users(email=email, username=username)
            user.set_password(password)
            user.is_verified = False
            user.is_active = False
            user.save()

            otp = generate_otp()
            Otp.objects.update_or_create(
                email=email,
                defaults={'otp': hash_otp(otp), 'created_at': timezone.now()},
            )
            send_otp(email, otp)
            return Response({'message': True}, status=status.HTTP_201_CREATED)

        except Exception as e:
            # Roll back the user if OTP sending failed so they can retry signup
            Users.objects.filter(email=email).delete()
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )