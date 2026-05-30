from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.auth.models import *
from myapp.auth.otp_generate import generate_otp, hash_otp, send_otp
from datetime import timedelta
from django.utils import timezone

class VerifySignupView(APIView):
    def post(self, request):
        email = request.data.get('email')
        otp = request.data.get('otp')
        if not email or not otp:
            return Response({'error': 'Email and OTP are required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            record = Otp.objects.filter(email=email, otp=hash_otp(otp)).last()
            if not record:
                return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)
            if record.created_at < timezone.now() - timedelta(minutes=5):
                return Response({'error': 'OTP expired'}, status=status.HTTP_400_BAD_REQUEST)
            user = Users.objects.filter(email=email).last()
            if not user:
                return Response({'error': 'User not found'}, status=status.HTTP_400_BAD_REQUEST)
            user.is_active = True
            user.is_verified = True
            user.save()
            return Response({'message': True}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)