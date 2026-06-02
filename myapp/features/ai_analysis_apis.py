import asyncio
import json
import queue
import threading

from django.http import StreamingHttpResponse
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from myapp.ai_funactions.ai_config.analysis import AnalysisStatement
from myapp.auth.models import AiAnalysisRecord
from myapp.auth.permission import (
    can_request_analysis,
    record_analysis,
    user_has_feature,
)

_SENTINEL = object()


class AiAnalysisAPI(APIView):
    permission_classes = [IsAuthenticated]

    # ------------------------------------------------------------------
    # Internal: run the async generator in a dedicated event loop thread
    # and bridge results to a thread-safe queue.
    # ------------------------------------------------------------------
    def _bridge_async_to_queue(self, prompt: str, stock_symbol: str, result_queue: queue.Queue):
        """
        Runs the async analysis pipeline in a fresh event loop (background
        thread) and puts every yielded dict onto *result_queue*.
        Always terminates with _SENTINEL so the consumer loop can exit.
        """
        async def _run():
            try:
                analysis = AnalysisStatement(prompt, stock_symbol.strip().upper())
                async for chunk in analysis.switch_ai_analysis():
                    result_queue.put(chunk)
            except Exception as exc:
                result_queue.put({"status": "error", "message": str(exc)})
            finally:
                result_queue.put(_SENTINEL)

        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(_run())
        finally:
            loop.close()

    # ------------------------------------------------------------------
    # SSE generator: consumes the queue and yields SSE-formatted strings.
    # ------------------------------------------------------------------
    def _sse_stream(self, prompt: str, stock_symbol: str, user):
        """
        Yields Server-Sent Events for the streaming HTTP response.

        Flow:
          1. Start background thread that runs the async pipeline.
          2. Forward every chunk from the queue as an SSE event.
          3. After the pipeline finishes, append a usage summary event.
          4. Send a final "done" event so the client knows the stream ended.
        """
        result_queue: queue.Queue = queue.Queue()

        thread = threading.Thread(
            target=self._bridge_async_to_queue,
            args=(prompt, stock_symbol, result_queue),
            daemon=True,
        )
        thread.start()

        # Stream analysis events
        while True:
            try:
                # Timeout prevents the generator from blocking forever if
                # the background thread crashes without posting _SENTINEL.
                item = result_queue.get(timeout=120)
            except queue.Empty:
                # 2-minute silence → treat as a timeout error and stop.
                yield f"data: {json.dumps({'status': 'error', 'message': 'Analysis timed out'})}\n\n"
                break

            if item is _SENTINEL:
                break

            yield f"data: {json.dumps(item)}\n\n"

        thread.join(timeout=5)   # brief grace period for cleanup

        # Usage summary (sent once, after all analysis events)
        try:
            today = timezone.now().date()
            used_today = AiAnalysisRecord.objects.filter(user=user, date=today).count()
            is_unlimited = user_has_feature(user, "analysis_unlimited")
            limit = user.ai_analysis_daily_limit

            usage_payload = {
                "status":       "usage",
                "plan":         user.plan,
                "is_unlimited": is_unlimited,
                "used":         used_today,
                "limit":        None if is_unlimited else limit,
                "remaining":    None if is_unlimited else max(0, limit - used_today),
            }
            yield f"data: {json.dumps(usage_payload)}\n\n"
        except Exception as exc:
            yield f"data: {json.dumps({'status': 'error', 'message': f'Usage fetch failed: {exc}'})}\n\n"

        # Terminal event — client can close the EventSource on receipt
        yield f"data: {json.dumps({'status': 'done'})}\n\n"

    # ------------------------------------------------------------------
    # GET handler
    # ------------------------------------------------------------------
    def get(self, request):
        stock_symbol: str = (request.query_params.get("stock_symbol") or "").strip()
        prompt: str       = (request.query_params.get("prompt") or "").strip()

        if not stock_symbol or not prompt:
            return Response(
                {"success": False, "message": "stock_symbol and prompt are required"},
                status=400,
            )

        upper_symbol = stock_symbol.upper()

        # ── Guard: daily limit check ──────────────────────────────────
        check = can_request_analysis(request.user, upper_symbol, cost=1)
        if not check["allowed"]:
            return Response(
                {
                    "success":   False,
                    "message":   check["error"],
                    "used":      check["used"],
                    "limit":     check["limit"],
                    "remaining": check["remaining"],
                },
                status=403,
            )

        # ── Record usage *before* streaming ──────────────────────────
        # This intentionally debits one credit even when wordfindingAI
        # returns "general" (no analysis needed). If you want to refund
        # credits in that case, emit a "refund" signal from the pipeline
        # and handle it in the client or a post-stream hook.
        record_analysis(request.user, upper_symbol, cost=1)

        response = StreamingHttpResponse(
            self._sse_stream(prompt, stock_symbol, request.user),
            content_type="text/event-stream",
        )
        response["Cache-Control"]    = "no-cache"
        response["X-Accel-Buffering"] = "no"
        return response