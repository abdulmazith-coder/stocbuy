from django.http import StreamingHttpResponse
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
import asyncio
import json
import queue
import threading

from myapp.ai_funactions.ai_config.analysis import AnalysisStatement
from django.utils import timezone
from myapp.auth.models import AiAnalysisRecord
from myapp.auth.permission import (
    can_request_analysis,
    record_analysis,
    user_has_feature,
)

_SENTINEL = object()


class AiAnalysisAPI(APIView):
    permission_classes = [IsAuthenticated]

    def stream_analysis(self, prompt, stock_symbol, user):
        result_queue = queue.Queue()

        async def _run():
            try:
                stockSymbol = stock_symbol.strip().upper()
                ai_analysis = AnalysisStatement(prompt, stockSymbol)
                async for data in ai_analysis.switch_ai_analysis():
                    result_queue.put(data)
            except Exception as e:
                result_queue.put({"status": "error", "message": str(e)})
            finally:
                result_queue.put(_SENTINEL)

        def _thread():
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                loop.run_until_complete(_run())
            finally:
                loop.close()

        thread = threading.Thread(target=_thread, daemon=True)
        thread.start()

        while True:
            item = result_queue.get()
            if item is _SENTINEL:
                break
            yield f"data: {json.dumps(item)}\n\n"

        while True:
            item = result_queue.get()

            if item is _SENTINEL:
                break

            print("SSE SEND:", item)

            yield f"data: {json.dumps(item)}\n\n"

        # ── Send usage as final SSE event ─────────────────────────────────
        today = timezone.now().date()
        used_today = AiAnalysisRecord.objects.filter(
            user=user,
            date=today,
        ).count()
        is_unlimited = user_has_feature(user, 'analysis_unlimited')
        limit = user.ai_analysis_daily_limit

        usage_event = {
            "status": "usage",
            "plan": user.plan,
            "is_unlimited": is_unlimited,
            "used": used_today,
            "limit": None if is_unlimited else limit,
            "remaining": None if is_unlimited else max(0, limit - used_today),
        }
        yield f"data: {json.dumps(usage_event)}\n\n"

    def get(self, request):
        stock_symbol = request.query_params.get("stock_symbol")
        prompt = request.query_params.get("prompt")

        if not stock_symbol or not prompt:
            return Response(
                {"success": False, "message": "Stock symbol and prompt are required"},
                status=400,
            )

        # ── Check daily limit (AI analysis costs 1) ───────────────────────
        check = can_request_analysis(request.user, stock_symbol.strip().upper(), cost=1)
        if not check['allowed']:
            return Response(
                {
                    'success': False,
                    'message': check['error'],
                    'used': check['used'],
                    'limit': check['limit'],
                    'remaining': check['remaining'],
                },
                status=403,
            )

        # ── Record the analysis (costs 1) ─────────────────────────────────
        record_analysis(request.user, stock_symbol.strip().upper(), cost=1)

        # ── Stream response ───────────────────────────────────────────────
        response = StreamingHttpResponse(
            self.stream_analysis(prompt, stock_symbol, request.user),
            content_type="text/event-stream",
        )
        response["Cache-Control"] = "no-cache"
        response["X-Accel-Buffering"] = "no"
        return response