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
 
    if user_has_feature(user, 'analysis_unlimited'):
        return {'allowed': True, 'is_unlimited': True}
 
    # OPTIMIZED: single COUNT query — no intermediate save needed
    used_today = AiAnalysisRecord.objects.filter(user=user, date=today).count()
    limit = user.ai_analysis_daily_limit
 
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
 
 
def record_analysis(user, stock_symbol: str, cost: int = 1) -> None:
    today = timezone.now().date()
 
    if cost == 1:
        # Fast path: single get_or_create
        AiAnalysisRecord.objects.get_or_create(
            user=user,
            stock_symbol=stock_symbol.upper(),
            date=today,
        )
    else:
        # OPTIMIZED: build all records and bulk_create with ignore_conflicts
        # → 1 DB round-trip instead of N round-trips
        records = [
            AiAnalysisRecord(
                user=user,
                stock_symbol=f'{stock_symbol}_{i}'.upper(),
                date=today,
            )
            for i in range(cost)
        ]
        AiAnalysisRecord.objects.bulk_create(records, ignore_conflicts=True)
 
    used_today = AiAnalysisRecord.objects.filter(user=user, date=today).count()
    limit = user.ai_analysis_daily_limit
 
    # OPTIMIZED: update_fields → writes only 2 columns instead of full row
    user.ai_analysis_used_today = used_today
    user.ai_analysis_date = today
    user.save(update_fields=['ai_analysis_used_today', 'ai_analysis_date'])
 
    ContactRequest.objects.filter(user=user).update(
        ai_analysis_used=used_today,
        ai_analysis_limit=limit,
        ai_analysis_remaining=max(0, limit - used_today),
    )
