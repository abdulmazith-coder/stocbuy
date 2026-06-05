from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

# ── refresh_token_view.py ────────────────────────────────────
# CHANGE: Catch TokenError specifically → correct 401 status
# CHANGE: No logic changes needed; already lean
 
class RefreshTokenView(APIView):
    def post(self, request):
        data = request.data.get('refresh_token')
        if not data:
            return Response({'error': 'Refresh token is required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            refresh = RefreshToken(data)
            access = refresh.access_token
            return Response({'message': True, 'access_token': str(access)}, status=status.HTTP_200_OK)
        except TokenError as e:
            return Response({'error': str(e)}, status=status.HTTP_401_UNAUTHORIZED)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
 
