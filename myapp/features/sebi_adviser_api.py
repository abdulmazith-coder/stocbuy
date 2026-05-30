from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.utils.translation import gettext as _
import logging
from rest_framework.permissions import IsAuthenticated
from myapp.datasource.all_stock_data import *

logger = logging.getLogger(__name__)


class SEBIAdvisorAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            # Get query params
            state = request.query_params.get('state')
            city = request.query_params.get('city')
            advisor_name = request.query_params.get('advisor_name')
            register_number = request.query_params.get('register_number')

            # Validation
            if not any([state, city, advisor_name, register_number]):
                return Response(
                    {
                        "success": False,
                        "message": _("At least one filter parameter is required"),
                        "data": []
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Fetch data
            data = StockData.get_sebi_register_data(
                state=state,
                city=city,
                advisor_name=advisor_name,
                register_number=register_number
            )

            # Handle empty result
            if not data:
                return Response(
                    {
                        "success": True,
                        "message": _("No advisors found"),
                        "data": []
                    },
                    status=status.HTTP_200_OK
                )

            return Response(
                {
                    "success": True,
                    "message": _("Advisors fetched successfully"),
                    "count": len(data),
                    "data": data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.error(f"SEBI Advisor API Error: {str(e)}")

            return Response(
                {
                    "success": False,
                    "message": _("Internal server error"),
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )