from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from myapp.datasource.all_stock_data import *
import logging

logger = logging.getLogger(__name__)


class StockPriceAPI(APIView):
    permission_classes = [IsAuthenticated]


    def get(self, request):
        try:
            # Get query params
            stock_symbol = request.query_params.get('stock_symbol')
            timing = request.query_params.get('timing')
            interval = request.query_params.get('interval', None)
            istread = request.query_params.get('istread')

            # Validate required fields
            if not all([stock_symbol, timing, istread]):
                return Response(
                    {
                        "success": False,
                        "message": "stock_symbol, timing and isTread are required",
                        "data": []
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )
            stockPrice = StockData(stock_symbol)
            isValue = istread.lower()=='true'
            if isValue == True:
                stock_price = stockPrice.get_stock_price_history(str(timing), isValue,None)
            else:
                stock_price = stockPrice.get_stock_price_history(str(timing), isValue,str(interval))
            if not stock_price:
                return Response(
                    {
                        "success": False,
                        "message": "No stock price history found",
                        "data": []
                    },
                    status=status.HTTP_200_OK
                )
        
            return Response(
                    {
                        "success": True,
                        "message": "Stock price history fetched successfully",
                        "data": stock_price
                    },
                    status=status.HTTP_200_OK
                )

        except Exception as e:
            logger.error(f"StockPriceAPI Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )




class Stock1mPriceAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            stock_symbol = request.query_params.get('stock_symbol')
            stock_price = StockData(stock_symbol).get_1m_price_history()
            if not stock_price:
                return Response(
                    {
                        "success": False,
                        "message": "No stock price history found",
                        "data": []
                    },
                    status=status.HTTP_200_OK
                )
            return Response(
                    {
                        "success": True,
                        "message": "Stock price history fetched successfully",
                        "data": stock_price
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