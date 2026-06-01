from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from myapp.auth.models import Users, Otp
from myapp.auth.otp_generate import generate_otp, hash_otp, send_otp
from myapp.auth.permission import FREE_DAILY_LIMIT


class SignupView(APIView):

    def post(self, request):
        email = request.data.get('email')
        username = request.data.get('username')
        password = request.data.get('password')

        if not email or not username or not password:
            return Response(
                {'error': 'Email, username and password are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            if Users.objects.filter(email=email).exists():
                return Response(
                    {'error': 'Email already exists'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            user = Users.objects.create_user(
                email=email,
                username=username,
                password=password,
            )
            user.is_verified = False
            user.is_active = False
            user.save()

            otp = generate_otp()
            hashed_otp = hash_otp(otp)
            Otp.objects.update_or_create(
                email=email,
                defaults={'otp': hashed_otp, 'created_at': timezone.now()},
            )
            send_otp(email, otp)

            return Response({
                'message': True,
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )