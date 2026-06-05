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
            # Single query: match email + hashed OTP together
            record = Otp.objects.filter(
                email=email,
                otp=hash_otp(otp),
            ).order_by('-created_at').first()
 
            if not record:
                return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)
            if record.created_at < timezone.now() - timedelta(minutes=5):
                return Response({'error': 'OTP expired'}, status=status.HTTP_400_BAD_REQUEST)
 
            # OPTIMIZED: use .get() — single indexed lookup, no table scan
            try:
                user = Users.objects.get(email=email)
            except Users.DoesNotExist:
                return Response({'error': 'User not found'}, status=status.HTTP_400_BAD_REQUEST)
 
            # OPTIMIZED: update_fields → only writes 2 columns, not entire row
            user.is_active = True
            user.is_verified = True
            user.save(update_fields=['is_active', 'is_verified'])
 
            return Response({'message': True}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
 
