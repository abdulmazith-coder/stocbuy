# views.py
from django.http import StreamingHttpResponse
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
import asyncio
import json
import queue
import threading

from myapp.ai_funactions.ai_config.analysis import AnalysisStatement

_SENTINEL = object()  # signals the queue is done

class AiAnalysisAPI(APIView):
    permission_classes = [IsAuthenticated]

    def stream_analysis(self, prompt, stock_symbol):
        """
        Runs the async generator on a dedicated thread with its own event loop.
        Pushes results into a sync queue so StreamingHttpResponse can consume them.
        """
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
                result_queue.put(_SENTINEL)  # always signal done

        def _thread():
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                loop.run_until_complete(_run())
            finally:
                loop.close()

        # Start async work in background thread
        thread = threading.Thread(target=_thread, daemon=True)
        thread.start()

        # Yield results as SSE events
        while True:
            item = result_queue.get()
            if item is _SENTINEL:
                break
            yield f"data: {json.dumps(item)}\n\n"

        thread.join()

    def get(self, request):
        stock_symbol = request.query_params.get("stock_symbol")
        prompt = request.query_params.get("prompt")

        if not stock_symbol or not prompt:
            return Response(
                {"success": False, "message": "Stock symbol and prompt are required"},
                status=400,
            )

        response = StreamingHttpResponse(
            self.stream_analysis(prompt, stock_symbol),
            content_type="text/event-stream",
        )
        response["Cache-Control"] = "no-cache"
        response["X-Accel-Buffering"] = "no"
        return response