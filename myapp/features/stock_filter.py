from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.screener.get_good_stock import GetGoodStock
from myapp.auth.permission import user_has_feature, can_request_analysis, record_analysis


class StockFilterAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
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

        feature_map = {
            'penny': 'filter_penny',
            'mid': 'filter_mid',
            'large': 'filter_large',
            'growth': 'filter_growth',
        }
        required_feature = feature_map.get(cap_type.lower())

        if not required_feature:
            return Response(
                {"success": False, "message": "Invalid cap_type."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # ── Check if user has access to this filter ───────────────────────
        if not user_has_feature(request.user, required_feature):
            return Response(
                {
                    'success': False,
                    'message': 'This filter is a premium feature. Connect with us to request access.',
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        # ── Build unique token per call so every filter reduces limit ─────
        timestamp = timezone.now().strftime('%H%M%S%f')
        stock_symbol = f'__filter_{cap_type.lower()}_{timestamp}__'

        # ── Check daily limit (filter costs 2) ───────────────────────────
        check = can_request_analysis(request.user, stock_symbol=stock_symbol, cost=2)
        if not check['allowed']:
            return Response(
                {
                    'success': False,
                    'message': check['error'],
                    'used': check['used'],
                    'limit': check['limit'],
                    'remaining': check['remaining'],
                },
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        # ── Record against daily limit (costs 2) ─────────────────────────
        record_analysis(request.user, stock_symbol, cost=2)

        return GetGoodStock().get_all_stocks(cap_type=cap_type)