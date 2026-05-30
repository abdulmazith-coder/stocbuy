from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.auth.models import *
from myapp.auth.otp_generate import generate_otp, hash_otp, send_otp

class SignupView(APIView):

    def post(self, request):
        email = request.data.get('email')
        username = request.data.get('username')
        password = request.data.get('password')
        if not email or not username or not password:
            return Response({'error': 'Email, username and password are required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            already_exists = Users.objects.filter(email=email).exists()
            if already_exists:
                return Response({'error': 'Email already exists'}, status=status.HTTP_400_BAD_REQUEST)
            createUser = Users.objects.create_user(email=email, username=username, password=password)
            createUser.is_verified = False
            createUser.is_active = False
            createUser.save()
            otp = generate_otp()
            hashed_otp = hash_otp(otp)
            Otp.objects.create(email=email, otp=hashed_otp)
            send_otp(email, otp)
            return Response({'message': True}, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)