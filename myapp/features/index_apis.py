from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.all_stock_data import *
import logging          

logger = logging.getLogger(__name__)

class IndexDataAPI(APIView):

    def get(self, request):
        try:
            index_data = StockData.get_index_data()

            if not index_data:
                return Response(
                    {
                        "success": True,
                        "message": "No index data available",
                        "data": []
                    },
                    status=status.HTTP_200_OK
                )

            return Response(
                {
                    "success": True,
                    "message": "Index data fetched successfully",
                    "count": len(index_data),
                     "data": index_data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.error(f"IndexDataAPI Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )