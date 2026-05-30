from rest_framework.views import APIView
from rest_framework.response import Response        
from rest_framework import status
from myapp.datasource.all_stock_data import *
from myapp.datasource.target.eps_target_price import analyze_stock
import logging
logger = logging.getLogger(__name__)

class FutureTargetAPI(APIView):
    
    def get(self, request):
        try:
            stock_symbol = request.query_params.get("stock_symbol", "").strip()
            if not stock_symbol:
                return Response(
                    {
                        "success": False,
                        "message": "Missing required parameter: stock_symbol"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            analysis = analyze_stock(stock_symbol)

            if "error" in analysis:
                return Response(
                    {
                        "success": False,
                        "message": analysis["error"]
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            return Response(
                {
                    "success": True,
                    "message": f"Target price analysis successfully",
                    "data": analysis
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.error(f"FutureTargetAPI Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )