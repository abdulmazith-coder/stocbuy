from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.indiavix import *
import logging
logger = logging.getLogger(__name__)


class IndiaVIXDataAPI(APIView):
    
    def get(self, request):
        try:
            market = IndiaVixSentimentSystem()
            result = market.analyze_market()

            if not result:
                return Response(
                    {
                        "success": True,
                        "message": "No India VIX data available",
                        "data": {}
                    },
                    status=status.HTTP_200_OK
                )

            return Response(
                {
                    "success": True,
                    "message": "India VIX data fetched successfully",
                    "data": result
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.error(f"IndiaVIXDataAPI Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )