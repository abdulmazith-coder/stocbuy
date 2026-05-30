from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.nse_exchange_apis import *
from rest_framework.permissions import IsAuthenticated

class TopGainStocksAPI(APIView):

    def get(self, request):
        try:
            top_gain_stocks = NSEExchangeApis().get_top_gains_stocks()
            if not top_gain_stocks:
                return Response(
                    {
                        "success": True,
                        "message": "No top gain stocks found",
                        "data": []
                    },
                    status=status.HTTP_200_OK
                )
            return Response(
                {
                    "success": True,
                    "message": "Top gain stocks fetched successfully",
                    "data": top_gain_stocks
                },
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {
                    "success": False,
                    "message": str(e),
                    "data": []
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )