from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.market_rsi_service import MarketRSIService




class MarketRSIAPIView(APIView):

    def get(self, request):

        service = MarketRSIService()

        result = service.get_market_rsi()

        if result["success"]:

            return Response(result, status=status.HTTP_200_OK)
        else:
            return Response(result, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
