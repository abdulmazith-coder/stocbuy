from django.utils import timezone
from myapp.auth.models import AiAnalysisRecord, ContactRequest

FREE_DAILY_LIMIT = 3


def user_has_feature(user, feature_name: str) -> bool:
    if user.plan != 'premium':
        return False
    if user.is_premium_expired():
        user.expire_premium()
        return False
    return getattr(user, f'feature_{feature_name}', False)


def can_request_analysis(user, stock_symbol: str, cost: int = 1) -> dict:
    today = timezone.now().date()

    # Premium + unlimited → no cap
    if user_has_feature(user, 'analysis_unlimited'):
        return {'allowed': True, 'is_unlimited': True}

    # Reset daily counter if it's a new day
    if user.ai_analysis_date != today:
        user.ai_analysis_used_today = 0
        user.ai_analysis_date = today
        user.save(update_fields=['ai_analysis_used_today', 'ai_analysis_date'])

    limit = user.ai_analysis_daily_limit

    used_today = AiAnalysisRecord.objects.filter(user=user, date=today).count()

    # Check if enough remaining for the cost
    if used_today + cost > limit:
        return {
            'allowed': False,
            'error': f'Daily limit of {limit} analyses reached. Connect with us to upgrade.',
            'remaining': max(0, limit - used_today),
            'limit': limit,
            'used': used_today,
        }

    return {
        'allowed': True,
        'remaining': limit - used_today,
        'limit': limit,
        'used': used_today,
    }


def record_analysis(user, stock_symbol: str, cost: int = 1):
    today = timezone.now().date()

    # Insert `cost` number of unique records
    for i in range(cost):
        token = f'{stock_symbol}_{i}' if cost > 1 else stock_symbol
        AiAnalysisRecord.objects.get_or_create(
            user=user,
            stock_symbol=token.upper(),
            date=today,
        )

    used_today = AiAnalysisRecord.objects.filter(user=user, date=today).count()
    limit = user.ai_analysis_daily_limit

    user.ai_analysis_used_today = used_today
    user.ai_analysis_date = today
    user.save(update_fields=['ai_analysis_used_today', 'ai_analysis_date'])

    ContactRequest.objects.filter(user=user).update(
        ai_analysis_used=used_today,
        ai_analysis_limit=limit,
        ai_analysis_remaining=max(0, limit - used_today),
    )