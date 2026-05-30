from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.all_stock_data import *
from rest_framework.permissions import IsAuthenticated
import logging

logger = logging.getLogger(__name__)


class PeerCompaniesAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            # Get query param
            stock_symbol = request.query_params.get('stock_symbol')

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

            # Clean input
            stock_symbol = stock_symbol.strip().upper()

            # Fetch data
            stock_data = StockData(stock_symbol)
            peers = stock_data.get_peer_competitor()

            # Handle empty data
            if not peers:
                return Response(
                    {
                        "success": True,
                        "message": "No peer companies found",
                        "data": []
                    },
                    status=status.HTTP_200_OK
                )

            return Response(
                {
                    "success": True,
                    "message": "Peer companies fetched successfully",
                    "symbol": stock_symbol,
                    "count": len(peers),
                    "data": peers
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.error(f"PeerCompaniesAPI Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )