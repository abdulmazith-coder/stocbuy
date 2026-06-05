import re
import json
import asyncio
from datetime import timedelta

from django.utils import timezone
from django.db import IntegrityError
from asgiref.sync import sync_to_async

from myapp.ai_funactions.ai_config.ai_config import AIAnalsysis
from myapp.ai_funactions.ai_config.ai_response.models import AIResponse

from myapp.ai_funactions.system_instrustion.balancesheet_prompt import (
    system_instruction_for_balance_sheet,
)
from myapp.ai_funactions.system_instrustion.cashflow_prompt import (
    system_instruction_for_cash_flow,
)
from myapp.ai_funactions.system_instrustion.final_prompt import (
    system_instruction_for_analysis_ai,
)
from myapp.ai_funactions.system_instrustion.financialratios_prompt import (
    system_instruction_for_financial_ratios,
)
from myapp.ai_funactions.system_instrustion.incomesheet_prompt import (
    system_instruction_for_income_statement,
)
from myapp.ai_funactions.system_instrustion.news_pompt import (
    system_instruction_for_news_analysis,
)
from myapp.ai_funactions.system_instrustion.shareholder_prompt import (
    system_instruction_for_shareholding_pattern,
)
from myapp.ai_funactions.system_instrustion.wordfinding_prompt import (
    system_instruction_wordfinding,
)

from myapp.clean_data.validate_exchange import validate_exchange
from myapp.clean_data.financila_statement import clean_financial_data
from myapp.datasource.scraping.company_news import ScrapingNewsData


# ─────────────────────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────────────────────

CACHE_HOURS      = 24

BALANCE_SHEET    = "balance_sheet"
INCOME_STATEMENT = "income_statement"
CASH_FLOW        = "cash_flow"
SHAREHOLDERS     = "shareholders"
FINANCIAL_RATIOS = "financial_ratios"
NEWS             = "news"
FULL_ANALYSIS    = "full_analysis"
FINAL_ANALYSIS   = "final_analysis"

# Every string the wordfinding AI might return meaning "analyse everything"
FULL_ANALYSIS_ALIASES = {
    "full_analysis", "full analysis", "full stock analysis",
    "complete analysis", "all analysis", "full", "complete",
}

# Ordered list of all sub-analysis keys (used for cache restore iteration)
SUB_ANALYSIS_KEYS = [
    BALANCE_SHEET, INCOME_STATEMENT, CASH_FLOW,
    SHAREHOLDERS, FINANCIAL_RATIOS, NEWS,
]


# ─────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────

async def _run_in_thread(fn, *args):
    return await asyncio.to_thread(fn, *args)


def _fetch_all_yfinance(ticker):
    return {
        "balance_sheet": ticker.balance_sheet,
        "income_stmt":   ticker.income_stmt,
        "cashflow":      ticker.cashflow,
        "major_holders": ticker.major_holders,
        "info":          ticker.info,
    }


def _ensure_dict(value) -> dict:
    """
    Safely coerce a DB-stored value to a plain Python dict.

    The AIResponse.response field may come back from the DB as:
      • a dict  (Django JSONField or already-parsed)
      • a str   (JSON string, e.g. '{"balance_sheet": "..."}')
      • None / anything else → return {}

    This is the root cause of the original crash:
        'str' object has no attribute 'get'
    Calling .get() on the raw DB value without this guard fails
    whenever the field is stored as a JSON string.
    """
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        stripped = value.strip()
        if stripped.startswith("{"):
            try:
                parsed = json.loads(stripped)
                if isinstance(parsed, dict):
                    return parsed
            except json.JSONDecodeError:
                pass
    return {}


# ─────────────────────────────────────────────────────────────
# CACHE  (shared across all users, per stock + analysis_type)
# ─────────────────────────────────────────────────────────────

class SavingResponse:
    """
    Behaviour
    ─────────
    • First request for a stock → AI runs → result stored in DB → shown to user.
    • Any later request within 24 h → result loaded from DB → shown to user
      (AI is NOT called again).
    • After 24 h the record is stale → AI runs again → DB row overwritten.
    • All users share one cache row per (stock_symbol, analysis_type).
    """

    @staticmethod
    async def get_cached_response(stock_symbol: str, analysis_type: str):
        """
        Returns
        ───────
        None                                            → no row in DB
        {"cached": True, "expired": False, "response"} → fresh  (< 24 h)
        {"cached": True, "expired": True,  "response"} → stale  (≥ 24 h)
        """
        try:
            obj = await sync_to_async(
                AIResponse.objects.filter(
                    stock_symbol=stock_symbol,
                    analysis_type=analysis_type,
                ).first
            )()
            if not obj:
                return None

            diff    = timezone.now() - (obj.updated_at or timezone.now() - timedelta(days=999))
            expired = diff >= timedelta(hours=CACHE_HOURS)
            return {"cached": True, "expired": expired, "response": obj.response}

        except Exception as e:
            print(f"[CACHE GET ERROR] ({stock_symbol}/{analysis_type}):", e)
            return None

    @staticmethod
    async def save_response(stock_symbol: str, analysis_type: str, ai_data):
        """Upsert: create or overwrite, always reset updated_at."""
        try:
            obj, created = await sync_to_async(
                AIResponse.objects.get_or_create
            )(
                stock_symbol=stock_symbol,
                analysis_type=analysis_type,
                defaults={"response": ai_data},
            )
            if not created:
                obj.response   = ai_data
                obj.updated_at = timezone.now()
                await sync_to_async(obj.save)()
            return ai_data

        except IntegrityError:
            obj = await sync_to_async(
                AIResponse.objects.filter(
                    stock_symbol=stock_symbol,
                    analysis_type=analysis_type,
                ).first
            )()
            return obj.response if obj else ai_data

        except Exception as e:
            print(f"[CACHE SAVE ERROR] ({stock_symbol}/{analysis_type}):", e)
            return ai_data


# ─────────────────────────────────────────────────────────────
# AI RUNNER  (heartbeat while waiting)
# ─────────────────────────────────────────────────────────────

async def _run_ai(ai_callable, *ai_args, progress_queue=None, analysis_type=""):
    ai_task = asyncio.create_task(_run_in_thread(ai_callable, *ai_args))
    hb      = None

    if progress_queue:
        async def _heartbeat():
            while not ai_task.done():
                await asyncio.sleep(3)
                if not ai_task.done():
                    await progress_queue.put({
                        "status":  "processing",
                        "message": f"AI is analyzing {analysis_type}...",
                    })
        hb = asyncio.create_task(_heartbeat())

    try:
        return await ai_task
    finally:
        if hb:
            hb.cancel()


# ─────────────────────────────────────────────────────────────
# MAIN CLASS
# ─────────────────────────────────────────────────────────────

class AnalysisStatement:

    def __init__(self, userResponsive, stock_symbol):
        self.userResponsive = userResponsive
        self.stock_symbol   = stock_symbol
        self.ticker         = validate_exchange(stock_symbol)
        self.ai_semaphore   = asyncio.Semaphore(2)

    # ── helpers ───────────────────────────────────────────────

    @staticmethod
    def _info_str(infodata, *keys, default="N/A"):
        """
        Safely extract a string from info_data.

        FIX: infodata might be a string (e.g. a cached JSON string from DB
        that was not yet parsed). _ensure_dict() normalises it to a plain
        dict before calling .get(), preventing the original crash.
        """
        if not infodata:
            return default
        # Guard: if infodata arrived as a raw JSON string, parse it first.
        safe = _ensure_dict(infodata) if not isinstance(infodata, dict) else infodata
        for key in keys:
            v = safe.get(key)
            if v is not None and str(v).strip():
                return str(v).strip()
        return default

    def _company_context(self, infodata):
        # _ensure_dict protects against infodata being a raw JSON string.
        safe     = _ensure_dict(infodata) if not isinstance(infodata, dict) else infodata
        name     = self._info_str(safe, "longName", "shortName", "name", "symbol",
                                  default=self.stock_symbol)
        industry = self._info_str(safe, "industry")
        sector   = self._info_str(safe, "sector")
        return (
            f"company name: {name}, industry: {industry}, "
            f"sector: {sector}, user responsive: {self.userResponsive}"
        )

    async def _fetch_yf(self):
        return await _run_in_thread(_fetch_all_yfinance, self.ticker)

    # ── wordfinding ───────────────────────────────────────────

    async def wordfindingAI(self, prompt):
        if not prompt:
            return None
        result = await asyncio.to_thread(
            AIAnalsysis.aiAnalysis,
            self.userResponsive,
            prompt,
            system_instruction_wordfinding,
        )
        return result.strip().lower() if result else None

    # ─────────────────────────────────────────────────────────
    # CORE: run one AI call, yield heartbeat messages,
    #       then yield {"__result__": <value>} when done.
    # ─────────────────────────────────────────────────────────

    async def _stream_ai(self, analysis_type, label, ai_callable, *ai_args):
        pq = asyncio.Queue()

        async with self.ai_semaphore:
            ai_task = asyncio.create_task(
                _run_ai(
                    ai_callable, *ai_args,
                    progress_queue=pq,
                    analysis_type=analysis_type,
                )
            )

            # Drain progress messages while AI works
            while not ai_task.done():
                try:
                    msg = await asyncio.wait_for(pq.get(), timeout=3.0)
                    yield msg
                except asyncio.TimeoutError:
                    yield {"status": "processing",
                           "message": f"AI is still working on {label}..."}

            try:
                yield {"__result__": await ai_task}
            except Exception as e:
                print(f"[AI ERROR] {analysis_type}: {e}")
                yield {"status": "error", "message": str(e)}

    # ─────────────────────────────────────────────────────────
    # CACHE-AWARE SINGLE ANALYSIS
    # Yields:
    #   • progress messages while AI works
    #   • one final {"status":"success", "cached":bool,
    #                "analysis_type":…, "data":…}
    # ─────────────────────────────────────────────────────────

    async def _run_single(
        self,
        analysis_type: str,
        statement_data,
        info_data,
        ai_function,
        system_prompt,
    ):
        # 1. Try cache first
        cached = await SavingResponse.get_cached_response(
            self.stock_symbol, analysis_type
        )
        if cached and not cached["expired"]:
            yield {
                "status":        "success",
                "cached":        True,
                "analysis_type": analysis_type,
                "data":          cached["response"],   # ← actual AI text from DB
            }
            return

        # 2. Validate & clean
        if hasattr(statement_data, "empty") and statement_data.empty:
            yield {"status": "error", "message": f"{analysis_type} data is empty"}
            return

        cleaned = clean_financial_data(statement_data)
        if not cleaned:
            yield {"status": "error", "message": f"Failed cleaning {analysis_type}"}
            return

        ctx    = self._company_context(info_data)
        result = None

        # 3. Run AI + stream heartbeats
        async for item in self._stream_ai(
            analysis_type, analysis_type,
            ai_function, ctx, cleaned, system_prompt,
        ):
            if "__result__" in item:
                result = item["__result__"]
            else:
                yield item   # progress message

        # 4. Save to DB
        if result:
            await SavingResponse.save_response(
                self.stock_symbol, analysis_type, result
            )

        # 5. Yield the actual AI result to the frontend
        yield {
            "status":        "success",
            "cached":        False,
            "analysis_type": analysis_type,
            "data":          result,   # ← actual AI text (fresh from AI)
        }

    # ─────────────────────────────────────────────────────────
    # INDIVIDUAL ANALYSIS ENDPOINTS
    # ─────────────────────────────────────────────────────────

    async def analysisTheBalanceSheet(self):
        yield {"status": "processing", "message": "Fetching balance sheet..."}
        data = await self._fetch_yf()
        async for item in self._run_single(
            BALANCE_SHEET, data["balance_sheet"], data["info"],
            AIAnalsysis.aiAnalysis, system_instruction_for_balance_sheet,
        ):
            yield item

    async def analysisIncomeStatement(self):
        yield {"status": "processing", "message": "Fetching income statement..."}
        data = await self._fetch_yf()
        async for item in self._run_single(
            INCOME_STATEMENT, data["income_stmt"], data["info"],
            AIAnalsysis.aiAnalysis, system_instruction_for_income_statement,
        ):
            yield item

    async def analysisCashFlow(self):
        yield {"status": "processing", "message": "Fetching cash flow..."}
        data = await self._fetch_yf()
        async for item in self._run_single(
            CASH_FLOW, data["cashflow"], data["info"],
            AIAnalsysis.aiAnalysis, system_instruction_for_cash_flow,
        ):
            yield item

    async def analysisShareholders(self):
        yield {"status": "processing", "message": "Fetching shareholders..."}
        data = await self._fetch_yf()
        async for item in self._run_single(
            SHAREHOLDERS, data["major_holders"], data["info"],
            AIAnalsysis.aiAnalysis_3, system_instruction_for_shareholding_pattern,
        ):
            yield item

    async def analysisFinancialRatios(self):
        yield {"status": "processing", "message": "Fetching financial ratios..."}

        cached = await SavingResponse.get_cached_response(
            self.stock_symbol, FINANCIAL_RATIOS
        )
        if cached and not cached["expired"]:
            yield {
                "status":        "success",
                "cached":        True,
                "analysis_type": FINANCIAL_RATIOS,
                "data":          cached["response"],
            }
            return

        data   = await self._fetch_yf()

        # FIX: info_data from yfinance must be a dict.
        # If it came back as a JSON string (e.g. from a stale cache path),
        # parse it before passing to the AI so it doesn't crash on .get().
        info_data = _ensure_dict(data["info"]) if not isinstance(data["info"], dict) else data["info"]

        result = None

        async for item in self._stream_ai(
            FINANCIAL_RATIOS, FINANCIAL_RATIOS,
            AIAnalsysis.aiAnalysis_2,
            self.userResponsive, info_data,
            system_instruction_for_financial_ratios,
        ):
            if "__result__" in item:
                result = item["__result__"]
            else:
                yield item

        if result:
            await SavingResponse.save_response(
                self.stock_symbol, FINANCIAL_RATIOS, result
            )

        yield {
            "status":        "success",
            "cached":        False,
            "analysis_type": FINANCIAL_RATIOS,
            "data":          result,
        }

    async def analysisNews(self):
        yield {"status": "processing", "message": "Fetching latest news..."}

        cached = await SavingResponse.get_cached_response(self.stock_symbol, NEWS)
        if cached and not cached["expired"]:
            yield {
                "status":        "success",
                "cached":        True,
                "analysis_type": NEWS,
                "data":          cached["response"],
            }
            return

        news_data = ScrapingNewsData(self.stock_symbol).scrapingNews()
        result    = None

        async for item in self._stream_ai(
            NEWS, NEWS,
            AIAnalsysis.aiAnalysis_3,
            self.userResponsive + " these are 1 day news",
            news_data,
            system_instruction_for_news_analysis,
        ):
            if "__result__" in item:
                result = item["__result__"]
            else:
                yield item

        if result:
            await SavingResponse.save_response(self.stock_symbol, NEWS, result)

        yield {
            "status":        "success",
            "cached":        False,
            "analysis_type": NEWS,
            "data":          result,
        }

    # ─────────────────────────────────────────────────────────
    # FULL ANALYSIS
    # ─────────────────────────────────────────────────────────

    async def analysisTheStock(self, _analysis_type="full_analysis"):
        """
        Flow
        ────
        FIRST TIME (no DB entry):
          1. Fetch yfinance + news
          2. Run all 6 sub-analyses (balance sheet, income, cash flow,
             shareholders, ratios, news) — each saved to DB individually
          3. Run final combined AI verdict
          4. Save full_analysis record to DB
          5. Yield every sub-analysis result + final verdict to user

        REPEAT REQUEST (DB entry fresh < 24 h):
          1. Load stored dict from DB
          2. Yield each sub-analysis from DB   ← user SEES the data
          3. Yield final_analysis from DB      ← user SEES the verdict
          No AI calls made.
        """

        yield {"status": "processing", "message": "Starting full stock analysis..."}

        # ══════════════════════════════════════════════════════
        # CACHE HIT — load everything from DB and show to user
        # ══════════════════════════════════════════════════════
        cached_full = await SavingResponse.get_cached_response(
            self.stock_symbol, FULL_ANALYSIS
        )
        if cached_full and not cached_full["expired"]:
            # ── FIX ──────────────────────────────────────────────────────────
            # cached_full["response"] is whatever Django stored in the DB.
            # If AIResponse.response is a TextField/CharField the ORM returns
            # a raw JSON *string*, not a dict.  Calling .get() on a string
            # raises: 'str' object has no attribute 'get'
            #
            # _ensure_dict() handles all three possible shapes:
            #   • already a dict  → returned as-is
            #   • JSON string     → json.loads() → dict
            #   • anything else   → empty dict (graceful fallback)
            # ─────────────────────────────────────────────────────────────────
            stored = _ensure_dict(cached_full["response"])

            if not stored:
                # Corrupted or unrecognised cache value — fall through to fresh run.
                print(f"[CACHE WARN] full_analysis cache for {self.stock_symbol} "
                      f"could not be parsed as dict, re-running analysis. "
                      f"Raw type: {type(cached_full['response'])}")
            else:
                # Yield each sub-analysis so frontend renders them identically
                for key in SUB_ANALYSIS_KEYS:
                    value = stored.get(key)
                    if value:
                        yield {
                            "status":        "success",
                            "cached":        True,
                            "analysis_type": key,
                            "data":          value,   # ← AI text from DB
                        }

                # Yield the final combined verdict from DB
                final_from_db = stored.get(FINAL_ANALYSIS)
                if final_from_db:
                    yield {
                        "status":        "success",
                        "cached":        True,
                        "analysis_type": FINAL_ANALYSIS,
                        "data":          final_from_db,   # ← final AI verdict from DB
                    }

                yield {
                    "status":  "success",
                    "message": "Full analysis complete (from cache)",
                    "cached":  True,
                    "data":    stored,
                }
                return

        # ══════════════════════════════════════════════════════
        # CACHE MISS — fetch data, run AI, save, show to user
        # ══════════════════════════════════════════════════════

        yield {"status": "processing", "message": "Fetching stock data..."}

        try:
            yf_data = await self._fetch_yf()
        except Exception as e:
            yield {"status": "error", "message": f"Failed fetching stock data: {e}"}
            return

        try:
            news_data = ScrapingNewsData(self.stock_symbol).scrapingNews()
        except Exception as e:
            yield {"status": "error", "message": f"Failed fetching news: {e}"}
            return

        # FIX: yfinance ticker.info can occasionally return a string on
        # network errors or for delisted tickers. Normalise to dict here
        # so every downstream .get() call is safe.
        info_data = yf_data["info"]
        if not isinstance(info_data, dict):
            info_data = _ensure_dict(info_data)

        if not info_data:
            yield {"status": "error", "message": "Stock info empty or unreadable"}
            return

        # Clean raw dataframes
        cleaned  = {}
        datasets = [
            (BALANCE_SHEET,    yf_data["balance_sheet"]),
            (INCOME_STATEMENT, yf_data["income_stmt"]),
            (CASH_FLOW,        yf_data["cashflow"]),
            (SHAREHOLDERS,     yf_data["major_holders"]),
        ]
        for label, raw in datasets:
            if hasattr(raw, "empty") and raw.empty:
                yield {"status": "error", "message": f"{label} data is empty"}
                return
            c = clean_financial_data(raw)
            if not c:
                yield {"status": "error", "message": f"Failed cleaning {label}"}
                return
            cleaned[label] = c

        ctx       = self._company_context(info_data)
        collected = {}

        # Sub-analysis job definitions
        ai_jobs = [
            (
                BALANCE_SHEET,
                AIAnalsysis.aiAnalysis,
                ctx, cleaned[BALANCE_SHEET],
                system_instruction_for_balance_sheet,
            ),
            (
                INCOME_STATEMENT,
                AIAnalsysis.aiAnalysis,
                ctx, cleaned[INCOME_STATEMENT],
                system_instruction_for_income_statement,
            ),
            (
                CASH_FLOW,
                AIAnalsysis.aiAnalysis,
                ctx, cleaned[CASH_FLOW],
                system_instruction_for_cash_flow,
            ),
            (
                SHAREHOLDERS,
                AIAnalsysis.aiAnalysis_3,
                ctx, cleaned[SHAREHOLDERS],
                system_instruction_for_shareholding_pattern,
            ),
            (
                FINANCIAL_RATIOS,
                AIAnalsysis.aiAnalysis_2,
                self.userResponsive, info_data,
                system_instruction_for_financial_ratios,
            ),
            (
                NEWS,
                AIAnalsysis.aiAnalysis_3,
                self.userResponsive + " these are 1 day news",
                news_data,
                system_instruction_for_news_analysis,
            ),
        ]

        # ── Run sub-analyses (each is cache-aware individually) ──
        for (label, ai_fn, *args) in ai_jobs:

            # Check if this sub-analysis is already cached
            sub_cached = await SavingResponse.get_cached_response(
                self.stock_symbol, label
            )
            if sub_cached and not sub_cached["expired"]:
                # FIX: sub-analysis cache values are plain strings (AI text),
                # NOT dicts, so _ensure_dict is NOT applied here.
                # We just pass them through as-is.
                collected[label] = sub_cached["response"]
                yield {
                    "status":        "success",
                    "cached":        True,
                    "analysis_type": label,
                    "data":          sub_cached["response"],
                }
                continue

            yield {"status": "processing", "message": f"Running {label} analysis..."}

            result = None
            async for item in self._stream_ai(label, label, ai_fn, *args):
                if "__result__" in item:
                    result = item["__result__"]
                else:
                    yield item   # heartbeat / progress

            collected[label] = result

            if result:
                await SavingResponse.save_response(
                    self.stock_symbol, label, result
                )

            yield {
                "status":        "success",
                "cached":        False,
                "analysis_type": label,
                "data":          result,
            }

        # ── Final combined AI verdict ─────────────────────────
        yield {"status": "processing", "message": "Running final combined analysis..."}

        final_prompt = (
            f"balance sheet: {collected.get(BALANCE_SHEET)}, "
            f"income statement: {collected.get(INCOME_STATEMENT)}, "
            f"cash flow: {collected.get(CASH_FLOW)}, "
            f"shareholders: {collected.get(SHAREHOLDERS)}, "
            f"financial ratios: {collected.get(FINANCIAL_RATIOS)}, "
            f"news: {collected.get(NEWS)}"
        )

        final_response = None
        async for item in self._stream_ai(
            FINAL_ANALYSIS, FINAL_ANALYSIS,
            AIAnalsysis.aiAnalysis_2,
            self.userResponsive, final_prompt,
            system_instruction_for_analysis_ai,
        ):
            if "__result__" in item:
                final_response = item["__result__"]
            else:
                yield item   # heartbeat

        if not final_response:
            yield {
                "status":  "error",
                "message": "Final analysis AI returned no result. "
                           "Sub-analyses above are still available.",
            }
            return

        yield {
            "status":        "success",
            "cached":        False,
            "analysis_type": FINAL_ANALYSIS,
            "data":          final_response,
        }

        # Assemble and save the complete result to DB
        final_data = {
            BALANCE_SHEET:    collected.get(BALANCE_SHEET),
            INCOME_STATEMENT: collected.get(INCOME_STATEMENT),
            CASH_FLOW:        collected.get(CASH_FLOW),
            SHAREHOLDERS:     collected.get(SHAREHOLDERS),
            FINANCIAL_RATIOS: collected.get(FINANCIAL_RATIOS),
            NEWS:             collected.get(NEWS),       # FIX: use NEWS constant key,
            FINAL_ANALYSIS:   final_response,            # not the mismatched "news_analysis"
        }

        await SavingResponse.save_response(
            self.stock_symbol, FULL_ANALYSIS, final_data
        )

        yield {
            "status":  "success",
            "message": "Full analysis complete",
            "cached":  False,
            "data":    final_data,
        }

    # ─────────────────────────────────────────────────────────
    # ROUTER
    # ─────────────────────────────────────────────────────────

    async def switch_ai_analysis(self):

        user_response = await self.wordfindingAI(self.userResponsive)
        print("RAW RESPONSE:", repr(user_response))

        if not user_response or user_response.strip() == "general":
            yield {"status": "done", "message": "No analysis needed"}
            return

        # Parse comma/newline-separated list from wordfinding AI
        if isinstance(user_response, str):
            responses = [
                t.strip().lower()
                for t in re.split(r"[\n,]+", user_response)
                if t.strip()
            ]
        elif isinstance(user_response, list):
            responses = [str(t).strip().lower() for t in user_response if str(t).strip()]
        else:
            responses = [str(user_response).strip().lower()]

        print("FINAL TYPES:", responses)

        # Route map — covers all alias variants the wordfinding AI might return
        route_map = {
            "balance sheet":        self.analysisTheBalanceSheet,
            "income statement":     self.analysisIncomeStatement,
            "cash flow":            self.analysisCashFlow,
            "shareholding pattern": self.analysisShareholders,
            "valuation ratios":     self.analysisFinancialRatios,
            "financial ratios":     self.analysisFinancialRatios,
            "news":                 self.analysisNews,
            **{alias: self.analysisTheStock for alias in FULL_ANALYSIS_ALIASES},
        }

        for analysis_type in responses:
            handler = route_map.get(analysis_type)

            if not handler:
                yield {
                    "status":  "error",
                    "message": (
                        f"Unknown analysis type: '{analysis_type}'. "
                        f"Supported: {sorted(route_map.keys())}"
                    ),
                }
                continue

            yield {"status": "processing", "message": f"Running {analysis_type}..."}

            async for item in handler():
                yield item