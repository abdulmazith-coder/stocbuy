from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.all_stock_data import *


class ExchangeActiveAPI(APIView):

    def get(self, request):
        try:
            # Fetch market status
            nse_active = StockData.is_market_open("^NSEI","NSE")
            bse_active = StockData.is_market_open("^BSESN","BSE")

            # Build response
            data = {
                "NSE": {
                    "is_open": nse_active
                },
                "BSE": {
                    "is_open": bse_active
                }
            }

            # Determine overall status
            if nse_active['is_active'] =='CLOSED' and bse_active['is_active'] =='CLOSED':
                message = "Both markets are closed"
            elif nse_active['is_active'] =='OPEN' and bse_active['is_active'] =='OPEN':
                message = "Both markets are open"
            elif nse_active['is_active'] =='OPEN' and bse_active['is_active'] =='CLOSED':
                message = "NSE is open, BSE is closed"
            elif nse_active['is_active'] =='CLOSED' and bse_active['is_active'] =='OPEN':
                message = "NSE is closed, BSE is open"
            elif nse_active['is_active'] =='PER' and bse_active['is_active'] =='PER':
                message = "NSE is pre-open, BSE is pre-open"
            elif nse_active['is_active'] =='POST' and bse_active['is_active'] =='POST':
                message = "NSE is post-open, BSE is post-open"

            return Response(
                {
                    "success": True,
                    "message": message,
                    "data": data
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



