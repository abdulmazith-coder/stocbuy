from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.auth.models import *
from django.contrib.auth import authenticate,login,get_user_model,logout
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()

class LoginView(APIView):
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        if not email or not password:
            return Response({'error': 'Email and password are required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            user = authenticate(request,username=email, password=password)
            if not user:
                return Response({'error': 'Invalid credentials'}, status=status.HTTP_400_BAD_REQUEST)
            if not user.is_active:
                return Response({'error': 'Account is not active'}, status=status.HTTP_400_BAD_REQUEST)
            if not user.is_verified:
                return Response({'error': 'Email not verified'}, status=status.HTTP_400_BAD_REQUEST)
            token = RefreshToken.for_user(user)
            return Response({'message':True , 'access_token': str(token.access_token), 'refresh_token': str(token)}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
