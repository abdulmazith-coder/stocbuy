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

        # The new limit the user is requesting (optional, must be a positive int)
        requested_limit_raw = data.get('requested_analysis_limit')
        try:
            requested_analysis_limit = int(requested_limit_raw) if requested_limit_raw is not None else None
            if requested_analysis_limit is not None and requested_analysis_limit <= 0:
                raise ValueError
        except (ValueError, TypeError):
            return Response(
                {'error': 'requested_analysis_limit must be a positive integer.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

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
            existing_request = ContactRequest.objects.filter(email=email).first()

            if existing_request:
                if existing_request.status == ContactRequest.STATUS_PENDING:
                    return Response(
                        {
                            'error': 'Your request is currently pending review. '
                                     'Please wait for our team to get back to you.',
                            'action': 'pending',
                        },
                        status=status.HTTP_409_CONFLICT,
                    )

                if existing_request.status == ContactRequest.STATUS_APPROVED:
                    # Merge previously approved filters with newly requested ones
                    req_penny              = req_penny or existing_request.request_filter_penny
                    req_mid                = req_mid or existing_request.request_filter_mid
                    req_large              = req_large or existing_request.request_filter_large
                    req_growth             = req_growth or existing_request.request_filter_growth
                    req_analysis_unlimited = req_analysis_unlimited or existing_request.request_analysis_unlimited
                    existing_request.delete()

                # If rejected → fall through and allow fresh re-submission

        # ── Limit tracking ──────────────────────────────────────────────
        today = timezone.now().date()
        FREE_DAILY_LIMIT = 3

        # Current limit: whatever the admin has set (or the free default)
        current_limit = max(user_account.ai_analysis_daily_limit, FREE_DAILY_LIMIT)

        # Requested limit: what the user is asking for.
        # Must be greater than their current limit to make sense.
        if requested_analysis_limit is not None and requested_analysis_limit <= current_limit:
            return Response(
                {
                    'error': f'requested_analysis_limit must be greater than your '
                             f'current limit of {current_limit}.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        used_today = AiAnalysisRecord.objects.filter(
            user=user_account,
            date=today,
        ).count()
        # ────────────────────────────────────────────────────────────────

        contact = ContactRequest.objects.create(
            email=email,
            phone=phone,
            # Current state
            ai_analysis_used=used_today,
            ai_analysis_limit=current_limit,                        # user's current limit
            ai_analysis_remaining=max(0, current_limit - used_today),
            # What the user wants
            requested_analysis_limit=requested_analysis_limit,      # user's requested new limit (nullable)
            request_filter_penny=req_penny,
            request_filter_mid=req_mid,
            request_filter_large=req_large,
            request_filter_growth=req_growth,
            request_analysis_unlimited=req_analysis_unlimited,
            user=user_account,
            status=ContactRequest.STATUS_PENDING,
        )

        contact.save()
        return Response(
            {
                'success': True,
                'message': 'Request submitted. We will contact you soon.',
                'current_analysis_limit': current_limit,
                'requested_analysis_limit': requested_analysis_limit,
            },
            status=status.HTTP_201_CREATED,
        )