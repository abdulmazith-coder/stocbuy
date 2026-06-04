from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.parsers import JSONParser
from rest_framework.exceptions import ParseError
from django.utils import timezone
from myapp.auth.models import ContactRequest, Users, AiAnalysisRecord


class ContactUsView(APIView):
    parser_classes = [JSONParser]

    def post(self, request):
        try:
            data = request.data
        except ParseError:
            return Response(
                {'error': 'Invalid JSON. Please check your request body.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        email = data.get('email') or (
            request.user.email
            if request.user and hasattr(request.user, 'email')
            else None
        )
        phone = data.get('phone')

        req_penny              = bool(data.get('request_filter_penny', False))
        req_mid                = bool(data.get('request_filter_mid', False))
        req_large              = bool(data.get('request_filter_large', False))
        req_growth             = bool(data.get('request_filter_growth', False))
        req_analysis_unlimited = bool(data.get('request_analysis_unlimited', False))

        if not email:
            return Response({'error': 'Email is required.'}, status=status.HTTP_400_BAD_REQUEST)
        if not phone:
            return Response({'error': 'Phone number is required.'}, status=status.HTTP_400_BAD_REQUEST)

        # Require a registered account
        try:
            user_account = Users.objects.get(email=email)
        except Users.DoesNotExist:
            return Response(
                {
                    'error': 'No account found for this email address. '
                             'Please sign up first before contacting us.',
                    'action': 'signup',
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        # Block if premium is still active
        if user_account.plan == 'premium' and not user_account.is_premium_expired():
            return Response(
                {
                    'error': 'Your premium plan is still active. '
                             'You can contact us again after your plan expires.',
                    'action': 'already_premium',
                },
                status=status.HTTP_409_CONFLICT,
            )

        # If premium expired → clean up and allow re-submission
        if user_account.is_premium_expired():
            user_account.expire_premium()
            ContactRequest.objects.filter(email=email).delete()
        else:
            # Check for an existing contact request and its status
            existing_request = ContactRequest.objects.filter(email=email).first()

            if existing_request:
                # Block if request is still pending
                if existing_request.status == 'pending':
                    return Response(
                        {
                            'error': 'Your request is currently pending review. '
                                     'Please wait for our team to get back to you.',
                            'action': 'pending',
                        },
                        status=status.HTTP_409_CONFLICT,
                    )

                # Allow re-submission if request was approved (user wants to upgrade again)
                if existing_request.status == 'approved':
                    # Delete the old approved request so a fresh one can be created
                    existing_request.delete()

                # If status is something else (e.g. 'rejected'), fall through and allow re-submission

        # Calculate AI analysis usage
        today = timezone.now().date()
        FREE_DAILY_LIMIT = 3
        used_today = AiAnalysisRecord.objects.filter(
            user=user_account,
            date=today,
        ).count()

        # Create the contact request
        contact = ContactRequest.objects.create(
            email=email,
            phone=phone,
            ai_analysis_used=used_today,
            ai_analysis_limit=FREE_DAILY_LIMIT,
            ai_analysis_remaining=max(0, FREE_DAILY_LIMIT - used_today),
            request_filter_penny=req_penny,
            request_filter_mid=req_mid,
            request_filter_large=req_large,
            request_filter_growth=req_growth,
            request_analysis_unlimited=req_analysis_unlimited,
            user=user_account,
            status='pending',  # Always start as pending
        )

        contact.save()
        return Response(
            {
                'success': True,
                'message': 'Request submitted. We will contact you soon.',
            },
            status=status.HTTP_201_CREATED,
        )