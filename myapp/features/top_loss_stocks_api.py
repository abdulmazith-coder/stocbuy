from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.nse_exchange_apis import *
from rest_framework.permissions import IsAuthenticated

class TopLossStocksAPI(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        try:
            top_loss_stocks = NSEExchangeApis().get_top_losers_stocks()
            if not top_loss_stocks:
                return Response(
                    {
                        "success": True,
                        "message": "No top loss stocks found",
                        "data": []
                    },
                    status=status.HTTP_200_OK
                )
            return Response(
                {
                    "success": True,
                    "message": "Top loss stocks fetched successfully",
                    "data": top_loss_stocks
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