from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.all_stock_data import *
from rest_framework.permissions import IsAuthenticated
from asgiref.sync import async_to_sync
import logging

logger = logging.getLogger(__name__)


class IPOsAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            # ✅ Correct async handling
            ipo_data = async_to_sync(StockData.get_IPOs_Data)()

            # Handle empty data
            if not ipo_data:
                return Response(
                    {
                        "success": True,
                        "message": "No IPO data available",
                        "data": []
                    },
                    status=status.HTTP_200_OK
                )

            return Response(
                {
                    "success": True,
                    "message": "IPO data fetched successfully",
                    "count": len(ipo_data),
                    "data": ipo_data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.error(f"IPOsAPI Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )