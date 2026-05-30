from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from myapp.datasource.all_stock_data import *
from asgiref.sync import async_to_sync
import logging


logger = logging.getLogger(__name__)


class CompanyNewsAPI(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        try:
            # Get query param
            stock_symbol = request.query_params.get('stock_symbol')
            days = request.query_params.get('days')

            # Validation
            if not stock_symbol:
                return Response(
                    {
                        "success": False,
                        "message": "Stock symbol is required",
                        "data": []
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            stock_symbol = stock_symbol.strip().upper()

            # Initialize
            stock_data = ScrapingNewsData(stock_symbol)

            # ✅ Correct way to call async in Django
            stock_news = async_to_sync(stock_data.scrapingNews)(f"when:{days}d")

            # Empty data handling
            if not stock_news:
                return Response(
                    {
                        "success": True,
                        "message": "No news found for this stock",
                        "data": []
                    },
                    status=status.HTTP_200_OK
                )

            return Response(
                {
                    "success": True,
                    "message": "Stock news fetched successfully",
                    "count": len(stock_news),
                    "data": stock_news
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.error(f"CompanyNewsAPI Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

