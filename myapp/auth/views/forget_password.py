from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.auth.models import *
from myapp.auth.otp_generate import generate_otp, hash_otp, send_otp
from rest_framework.permissions import AllowAny


class ForgetPasswordView(APIView):
    permission_classes = [AllowAny]
    def post(self, request):
        email = request.data.get('email')
        otp = request.data.get('otp')
        password = request.data.get('password')
        if not email or not otp or not password:
            return Response({'error': 'Email, OTP and password are required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            if not Otp.objects.filter(email=email, otp=hash_otp(otp)).last():
                return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)
            user = Users.objects.get(email=email)
            user.set_password(password)
            user.save()
            return Response({'message': 'Password reset successful'}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)