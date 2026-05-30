from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.market_breadth import *
import logging

logger = logging.getLogger(__name__)

class MarketBreadthAPI(APIView):
    
    def get(self, request):
        try:
            config = MarketBreadthConfig()
            breadth_result = MarketBreadthService(config).calculate()
            if not breadth_result:
                return Response(
                    {
                        "success": True,
                        "message": "No market breadth data available",
                        "data": None
                    },
                    status=status.HTTP_200_OK
                )

            return Response(
                {
                    "success": True,
                    "message": "Market breadth data fetched successfully",
                    "data": breadth_result
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.error(f"MarketBreadthAPI Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )