from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from myapp.ai_funactions.ai_config.normal_chat_ai import NormalChatAI


class NormalChatAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            user_response = request.query_params.get('prompt')
            stock_symbol = request.query_params.get('stock_symbol') or None
            if not user_response:
                return Response(
                    {
                        "success": False,
                        "message": "User response and stock symbol are required",
                        "data": {}
                    },
                    status=status.HTTP_400_BAD_REQUEST   
                )
            normal_chat = NormalChatAI(user_response,stock_symbol)
            response = normal_chat.normalChatAI()
            return Response(
                {
                    "success": True,
                    "message": "Normal chat response fetched successfully",
                    "data": response
                },
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )