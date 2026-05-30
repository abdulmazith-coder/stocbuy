from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from myapp.datasource.top_companies import *
from rest_framework.permissions import IsAuthenticated
import logging

logger = logging.getLogger(__name__)


class TopCompaniesAPI(APIView):

    def get(self, request):
        try:
            top_companies = TopCompanies().get_top_companies()
            if not top_companies:
                return Response(
                    {
                        "success": False,
                        "message": "No top companies found",
                        "data": []
                    },
                    status=status.HTTP_200_OK
                )
            return Response(
            {
                "success": True,
                "message": "Top companies fetched successfully",
                "data": top_companies
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