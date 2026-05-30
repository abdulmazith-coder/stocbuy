from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from myapp.datasource.all_stock_data import StockData
import logging

logger = logging.getLogger(__name__)


class StockSearchAPI(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request):

        try:
            query = request.query_params.get("stock_symbol", "").strip()

            # Validation
            if len(query) < 1:
                return Response(
                    {
                        "success": False,
                        "message": "Query is required",
                        "data": []
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            results = StockData.get_search_stock(query)

            return Response(
                {
                    "success": True,
                    "message": "Stocks fetched successfully",
                    "count": len(results),
                    "data": results
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            logger.error(f"StockSearchAPI Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )