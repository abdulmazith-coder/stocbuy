from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.screener.get_good_stock import GetGoodStock


class StockFilterAPI(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):

        # Pass ?cap_type=penny OR ?cap_type=mid OR ?cap_type=large
        # Defaults to penny if not provided
        cap_type = request.query_params.get('cap_type')
        if not cap_type:
            return Response(
                {
                    "success": False,
                    "message": "cap_type is required",
                    "data": []
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        return GetGoodStock().get_all_stocks(cap_type=cap_type)