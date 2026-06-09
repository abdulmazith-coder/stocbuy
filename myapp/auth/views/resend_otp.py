from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from myapp.auth.models import *
from myapp.auth.otp_generate import generate_otp, hash_otp, send_otp
from rest_framework.permissions import AllowAny
from django.utils import timezone
from myapp.auth.models import Users, Otp

 
 
class ResendOtpView(APIView):
    permission_classes = [AllowAny]
 
    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({'error': 'Email is required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            if not Users.objects.filter(email=email).exists():
                return Response({'error': 'Invalid email'}, status=status.HTTP_400_BAD_REQUEST)
            otp = generate_otp()
            hashed_otp = hash_otp(otp)
            Otp.objects.update_or_create(
                email=email,
                defaults={'otp': hashed_otp, 'created_at': timezone.now()},
            )
            send_otp(email, otp)
            return Response({'message': True}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
