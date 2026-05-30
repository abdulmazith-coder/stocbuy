from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.auth.models import *
from myapp.auth.otp_generate import generate_otp, hash_otp, send_otp

class ResendOtpView(APIView):
    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({'error': 'Email is required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            record = Otp.objects.filter(email=email).exists()
            if not record:
                return Response({'error': 'Invalid email'}, status=status.HTTP_400_BAD_REQUEST)
            otp = generate_otp()
            hashed_otp = hash_otp(otp)
            Otp.objects.update(email=email, otp=hashed_otp)
            send_otp(email, otp)
            return Response({'message': 'OTP sent to email'}, status=status.HTTP_200_OK)

        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)