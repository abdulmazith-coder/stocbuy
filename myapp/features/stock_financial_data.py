from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.all_stock_data import *
from myapp.clean_data.convert_timestamps import *
import logging
from rest_framework.permissions import IsAuthenticated

logger = logging.getLogger(__name__)


class StockFinancialDataAPI(APIView):
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
                        "data": {}
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Clean input
            stock_symbol = stock_symbol.strip().upper()

            # Fetch data
            stock_data = StockData(stock_symbol)
            financial_data = stock_data.get_Stocks_Financial_Statement()

            # Handle empty data
            if not financial_data:
                return Response(
                    {
                        "success": True,
                        "message": "No financial data found",
                        "data": {}
                    },
                    status=status.HTTP_200_OK
                )

            # Convert timestamps
            serializable_data = convert_timestamps(financial_data)

            # Optional: structure data (important for frontend)
            structured_data = {
                "income_statement": serializable_data.get("income_statement"),
                "balance_sheet": serializable_data.get("balance_sheet"),
                "cash_flow": serializable_data.get("cash_flow"),
                "share_holders": serializable_data.get("share_holders"),
            }

            return Response(
                {
                    "success": True,
                    "message": "Financial data fetched successfully",
                    "symbol": stock_symbol,
                    "data": structured_data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.error(f"StockFinancialDataAPI Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
