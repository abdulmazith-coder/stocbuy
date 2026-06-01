from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.utils import timezone
from myapp.auth.models import AiAnalysisRecord
from myapp.auth.permission import user_has_feature


class AiAnalysisUsageView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        today = timezone.now().date()

        # Reset if date changed
        if user.ai_analysis_date != today:
            user.ai_analysis_used_today = 0
            user.ai_analysis_date = today
            user.save(update_fields=['ai_analysis_used_today', 'ai_analysis_date'])

        is_unlimited = user_has_feature(user, 'analysis_unlimited')

        used_today = AiAnalysisRecord.objects.filter(
            user=user,
            date=today,
        ).count()

        # Sync the stored field with the actual DB count
        if user.ai_analysis_used_today != used_today:
            user.ai_analysis_used_today = used_today
            user.save(update_fields=['ai_analysis_used_today'])

        if is_unlimited:
            return Response({
                'plan': user.plan,
                'is_unlimited': True,
                'used': used_today,
                'limit': None,
                'remaining': None,
                'message': 'You have unlimited AI analysis access.',
            })

        limit = user.ai_analysis_daily_limit  # per-user stored limit, not hardcoded

        return Response({
            'plan': user.plan,
            'is_unlimited': False,
            'used': used_today,
            'limit': limit,
            'remaining': max(0, limit - used_today),
            'message': f'You have used {used_today} of {limit} analyses today.',
        })