import re
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

CACHE_HOURS = 24

BALANCE_SHEET      = "balance_sheet"
INCOME_STATEMENT   = "income_statement"
CASH_FLOW          = "cash_flow"
SHAREHOLDERS       = "shareholders"
FINANCIAL_RATIOS   = "financial_ratios"
NEWS               = "news"
FULL_ANALYSIS      = "full_analysis"
FINAL_ANALYSIS     = "final_analysis"

# ─────────────────────────────────────────────────────────────
# FIX 1: All possible strings the wordfinding AI might return
#         for a "full analysis" request, mapped to FULL_ANALYSIS.
#
# Previously only "full_analysis" (underscore) was in route_map,
# but the AI returns natural language like "full analysis",
# "full stock analysis", "complete analysis", etc.
# ─────────────────────────────────────────────────────────────

FULL_ANALYSIS_ALIASES = {
    "full_analysis",
    "full analysis",
    "full stock analysis",
    "complete analysis",
    "all analysis",
    "full",
    "complete",
}


# ─────────────────────────────────────────────────────────────
# SAFE THREAD
# ─────────────────────────────────────────────────────────────

async def _run_in_thread(fn, *args):
    return await asyncio.to_thread(fn, *args)


# ─────────────────────────────────────────────────────────────
# YFINANCE FETCH
# ─────────────────────────────────────────────────────────────

def _fetch_all_yfinance(ticker):
    return {
        "balance_sheet":  ticker.balance_sheet,
        "income_stmt":    ticker.income_stmt,
        "cashflow":       ticker.cashflow,
        "major_holders":  ticker.major_holders,
        "info":           ticker.info,
    }


# ─────────────────────────────────────────────────────────────
# CACHE DATABASE
# ─────────────────────────────────────────────────────────────

class SavingResponse:
    """
    Per-stock, per-analysis_type cache with 24-hour expiry.
    All users share the same cache entry per stock symbol.
    """

    @staticmethod
    async def get_cached_response(stock_symbol: str, analysis_type: str):
        """
        Returns:
          None                                          – no row in DB
          {"cached": True, "expired": False, "response": <data>}  – fresh
          {"cached": True, "expired": True,  "response": <data>}  – stale
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

            now     = timezone.now()
            diff    = now - obj.updated_at if obj.updated_at else timedelta(days=999)
            expired = diff >= timedelta(hours=CACHE_HOURS)

            return {
                "cached":   True,
                "expired":  expired,
                "response": obj.response,
            }

        except Exception as e:
            print(f"[CACHE GET ERROR] ({stock_symbol}/{analysis_type}):", e)
            return None

    @staticmethod
    async def save_response(stock_symbol: str, analysis_type: str, ai_data):
        """
        Upsert: create if not exists, otherwise overwrite + reset timestamp.
        """
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
# AI RUNNER  (with heartbeat progress messages)
# ─────────────────────────────────────────────────────────────

async def _run_ai(
    ai_callable,
    *ai_args,
    progress_queue: asyncio.Queue = None,
    analysis_type: str = "",
):
    ai_task = asyncio.create_task(
        _run_in_thread(ai_callable, *ai_args)
    )

    hb = None

    if progress_queue:
        async def _heartbeat():
            i = 0
            while not ai_task.done():
                await asyncio.sleep(3)
                if not ai_task.done():
                    await progress_queue.put({
                        "status":  "processing",
                        "message": f"AI is analyzing {analysis_type}...",
                    })
                    i += 1

        hb = asyncio.create_task(_heartbeat())

    try:
        ai_data = await ai_task
    finally:
        if hb:
            hb.cancel()

    return ai_data


# ─────────────────────────────────────────────────────────────
# MAIN CLASS
# ─────────────────────────────────────────────────────────────

class AnalysisStatement:

    def __init__(self, userResponsive, stock_symbol):
        self.userResponsive = userResponsive
        self.stock_symbol   = stock_symbol
        self.ticker         = validate_exchange(stock_symbol)
        self.ai_semaphore   = asyncio.Semaphore(2)

    # ─────────────────────────────────────────────────────────

    @staticmethod
    def _info_str(infodata, *keys, default="N/A"):
        if not infodata:
            return default
        for key in keys:
            value = infodata.get(key)
            if value is not None and str(value).strip():
                return str(value).strip()
        return default

    # ─────────────────────────────────────────────────────────

    def _company_context(self, infodata):
        name = self._info_str(
            infodata,
            "longName", "shortName", "name", "symbol",
            default=self.stock_symbol,
        )
        industry = self._info_str(infodata, "industry")
        sector   = self._info_str(infodata, "sector")
        return (
            f"company name: {name}, "
            f"industry: {industry}, "
            f"sector: {sector}, "
            f"user responsive: {self.userResponsive}"
        )

    # ─────────────────────────────────────────────────────────

    async def wordfindingAI(self, prompt):
        if not prompt:
            return None

        ai_response = await asyncio.to_thread(
            AIAnalsysis.aiAnalysis,
            self.userResponsive,
            prompt,
            system_instruction_wordfinding,
        )

        if not ai_response:
            return None

        return ai_response.strip().lower()

    # ─────────────────────────────────────────────────────────

    async def _fetch_yf(self):
        return await _run_in_thread(_fetch_all_yfinance, self.ticker)

    # ─────────────────────────────────────────────────────────
    # CORE STREAM WRAPPER
    # ─────────────────────────────────────────────────────────

    async def _stream_ai(self, analysis_type, label, ai_callable, *ai_args):
        pq = asyncio.Queue()

        async with self.ai_semaphore:
            ai_task = asyncio.create_task(
                _run_ai(
                    ai_callable,
                    *ai_args,
                    progress_queue=pq,
                    analysis_type=analysis_type,
                )
            )

            while not ai_task.done():
                try:
                    msg = await asyncio.wait_for(pq.get(), timeout=3.0)
                    yield msg
                except asyncio.TimeoutError:
                    yield {
                        "status":  "processing",
                        "message": f"AI is still working on {label}...",
                    }

            try:
                result = await ai_task
                print(f"[AI RESULT] {analysis_type}: {result}")
                yield {"__result__": result}
            except Exception as e:
                print(f"[AI ERROR] {analysis_type}: {e}")
                yield {"status": "error", "message": str(e)}

    # ─────────────────────────────────────────────────────────
    # CACHE-AWARE SINGLE ANALYSIS
    # ─────────────────────────────────────────────────────────

    async def _cached_single_analysis(
        self,
        analysis_type: str,
        statement_data,
        info_data,
        ai_function,
        system_prompt,
        response_key: str,
    ):
        # ── 1. Cache check ───────────────────────────────────
        cached = await SavingResponse.get_cached_response(
            self.stock_symbol, analysis_type
        )

        if cached and not cached["expired"]:
            yield {
                "status":        "success",
                "cached":        True,
                "analysis_type": analysis_type,
                response_key:    cached["response"],
            }
            return

        # ── 2. Validate + clean raw data ─────────────────────
        if hasattr(statement_data, "empty") and statement_data.empty:
            yield {"status": "error", "message": f"{analysis_type} data is empty"}
            return

        cleaned = clean_financial_data(statement_data)
        if not cleaned:
            yield {"status": "error", "message": f"Failed cleaning {analysis_type}"}
            return

        ctx    = self._company_context(info_data)
        result = None

        # ── 3. Run AI ────────────────────────────────────────
        async for item in self._stream_ai(
            analysis_type,
            analysis_type,
            ai_function,
            ctx,
            cleaned,
            system_prompt,
        ):
            if "__result__" in item:
                result = item["__result__"]
            else:
                yield item

        # ── 4. Persist to DB ─────────────────────────────────
        if result:
            await SavingResponse.save_response(
                self.stock_symbol, analysis_type, result
            )

        yield {
            "status":        "success",
            "cached":        False,
            "analysis_type": analysis_type,
            response_key:    result,
        }

    # ─────────────────────────────────────────────────────────
    # BALANCE SHEET
    # ─────────────────────────────────────────────────────────

    async def analysisTheBalanceSheet(self):
        yield {"status": "processing", "message": "Fetching balance sheet..."}
        data = await self._fetch_yf()
        async for item in self._cached_single_analysis(
            BALANCE_SHEET,
            data["balance_sheet"],
            data["info"],
            AIAnalsysis.aiAnalysis,
            system_instruction_for_balance_sheet,
            BALANCE_SHEET,
        ):
            yield item

    # ─────────────────────────────────────────────────────────
    # INCOME STATEMENT
    # ─────────────────────────────────────────────────────────

    async def analysisIncomeStatement(self):
        yield {"status": "processing", "message": "Fetching income statement..."}
        data = await self._fetch_yf()
        async for item in self._cached_single_analysis(
            INCOME_STATEMENT,
            data["income_stmt"],
            data["info"],
            AIAnalsysis.aiAnalysis,
            system_instruction_for_income_statement,
            INCOME_STATEMENT,
        ):
            yield item

    # ─────────────────────────────────────────────────────────
    # CASH FLOW
    # ─────────────────────────────────────────────────────────

    async def analysisCashFlow(self):
        yield {"status": "processing", "message": "Fetching cash flow..."}
        data = await self._fetch_yf()
        async for item in self._cached_single_analysis(
            CASH_FLOW,
            data["cashflow"],
            data["info"],
            AIAnalsysis.aiAnalysis,
            system_instruction_for_cash_flow,
            CASH_FLOW,
        ):
            yield item

    # ─────────────────────────────────────────────────────────
    # SHAREHOLDERS
    # ─────────────────────────────────────────────────────────

    async def analysisShareholders(self):
        yield {"status": "processing", "message": "Fetching shareholders..."}
        data = await self._fetch_yf()
        async for item in self._cached_single_analysis(
            SHAREHOLDERS,
            data["major_holders"],
            data["info"],
            AIAnalsysis.aiAnalysis_3,
            system_instruction_for_shareholding_pattern,
            SHAREHOLDERS,
        ):
            yield item

    # ─────────────────────────────────────────────────────────
    # FINANCIAL RATIOS
    # ─────────────────────────────────────────────────────────

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
                FINANCIAL_RATIOS: cached["response"],
            }
            return

        data   = await self._fetch_yf()
        result = None

        async for item in self._stream_ai(
            FINANCIAL_RATIOS,
            FINANCIAL_RATIOS,
            AIAnalsysis.aiAnalysis_2,
            self.userResponsive,
            data["info"],
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
            FINANCIAL_RATIOS: result,
        }

    # ─────────────────────────────────────────────────────────
    # NEWS
    # ─────────────────────────────────────────────────────────

    async def analysisNews(self):
        yield {"status": "processing", "message": "Fetching latest news..."}

        cached = await SavingResponse.get_cached_response(self.stock_symbol, NEWS)
        if cached and not cached["expired"]:
            yield {
                "status":        "success",
                "cached":        True,
                "analysis_type": NEWS,
                NEWS:            cached["response"],
            }
            return

        news_data = ScrapingNewsData(self.stock_symbol).scrapingNews()
        result    = None

        async for item in self._stream_ai(
            NEWS,
            NEWS,
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
            NEWS:            result,
        }

    # ─────────────────────────────────────────────────────────
    # FULL ANALYSIS
    # ─────────────────────────────────────────────────────────

    async def analysisTheStock(self, analysis_type):

        yield {"status": "processing", "message": "Starting full stock analysis..."}

        # ── FIX 2: full_analysis cache now correctly stores AND restores
        #    the complete final_data dict including final_analysis key.
        #    On cache hit, we yield each sub-analysis individually so the
        #    frontend receives the same structure as a fresh run.
        # ─────────────────────────────────────────────────────
        cached_full = await SavingResponse.get_cached_response(
            self.stock_symbol, FULL_ANALYSIS
        )
        if cached_full and not cached_full["expired"]:
            stored = cached_full["response"]  # this is the final_data dict

            # Yield each sub-analysis so frontend handles it identically
            sub_keys = [
                BALANCE_SHEET, INCOME_STATEMENT, CASH_FLOW,
                SHAREHOLDERS, FINANCIAL_RATIOS, NEWS,
            ]
            for key in sub_keys:
                if stored.get(key):
                    yield {
                        "status":        "success",
                        "cached":        True,
                        "analysis_type": key,
                        "data":          stored[key],
                    }

            # Yield the final combined verdict
            yield {
                "status":  "success",
                "message": "Full analysis complete",
                "cached":  True,
                "data":    stored,
            }
            return

        # ── Fetch raw data ────────────────────────────────────
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

        info_data         = yf_data["info"]
        balance_sheet_raw = yf_data["balance_sheet"]
        income_stmt_raw   = yf_data["income_stmt"]
        cashflow_raw      = yf_data["cashflow"]
        holders_raw       = yf_data["major_holders"]

        if not info_data:
            yield {"status": "error", "message": "Stock info empty"}
            return

        # ── Clean raw dataframes ──────────────────────────────
        cleaned  = {}
        datasets = [
            (BALANCE_SHEET,    balance_sheet_raw),
            (INCOME_STATEMENT, income_stmt_raw),
            (CASH_FLOW,        cashflow_raw),
            (SHAREHOLDERS,     holders_raw),
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

        # ── Sub-analysis job definitions ──────────────────────
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

        # ── Run each sub-analysis (cache-aware) ───────────────
        for (label, ai_fn, *args) in ai_jobs:

            sub_cached = await SavingResponse.get_cached_response(
                self.stock_symbol, label
            )

            if sub_cached and not sub_cached["expired"]:
                collected[label] = sub_cached["response"]
                yield {
                    "status":        "success",
                    "cached":        True,
                    "analysis_type": label,
                    "data":          sub_cached["response"],
                }
                continue

            yield {
                "status":  "processing",
                "message": f"Running {label} analysis...",
            }

            result = None

            async for item in self._stream_ai(label, label, ai_fn, *args):
                if "__result__" in item:
                    result = item["__result__"]
                    yield {
                        "status":        "success",
                        "cached":        False,
                        "analysis_type": label,
                        "data":          result,
                    }
                else:
                    yield item

            collected[label] = result

            if result:
                await SavingResponse.save_response(
                    self.stock_symbol, label, result
                )

        # ── FIX 3: Final combined analysis with proper error handling
        #    and guaranteed yield of the final verdict to the user.
        # ─────────────────────────────────────────────────────
        yield {"status": "processing", "message": "Running final combined analysis..."}

        final_response = None

        final_prompt = (
            f"balance sheet: {collected.get(BALANCE_SHEET)}, "
            f"income statement: {collected.get(INCOME_STATEMENT)}, "
            f"cash flow: {collected.get(CASH_FLOW)}, "
            f"shareholders: {collected.get(SHAREHOLDERS)}, "
            f"financial ratios: {collected.get(FINANCIAL_RATIOS)}, "
            f"news: {collected.get(NEWS)}"
        )

        async for item in self._stream_ai(
            FINAL_ANALYSIS,
            FINAL_ANALYSIS,
            AIAnalsysis.aiAnalysis_2,
            self.userResponsive,
            final_prompt,
            system_instruction_for_analysis_ai,
        ):
            if "__result__" in item:
                final_response = item["__result__"]
            else:
                yield item

        # Guard: if AI returned nothing, surface an error instead of silently failing
        if not final_response:
            yield {
                "status":  "error",
                "message": "Final analysis AI returned no result. Sub-analyses above are still available.",
            }
            return

        # ── Assemble + save final data ────────────────────────
        final_data = {
            BALANCE_SHEET:    collected.get(BALANCE_SHEET),
            INCOME_STATEMENT: collected.get(INCOME_STATEMENT),
            CASH_FLOW:        collected.get(CASH_FLOW),
            SHAREHOLDERS:     collected.get(SHAREHOLDERS),
            FINANCIAL_RATIOS: collected.get(FINANCIAL_RATIOS),
            "news_analysis":  collected.get(NEWS),
            FINAL_ANALYSIS:   final_response,   # ← the AI-synthesized verdict
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

        if (
            not user_response
            or (
                isinstance(user_response, str)
                and user_response.strip().lower() == "general"
            )
        ):
            yield {"status": "done", "message": "No analysis needed"}
            return

        # ── Parse the wordfinding AI output into a list of types ──
        if isinstance(user_response, str):
            responses = [
                item.strip().lower()
                for item in re.split(r"[\n,]+", user_response)
                if item.strip()
            ]
        elif isinstance(user_response, list):
            responses = [
                str(item).strip().lower()
                for item in user_response
                if str(item).strip()
            ]
        else:
            responses = [str(user_response).strip().lower()]

        print("FINAL TYPES:", responses)

        # ── FIX 1: Route map now covers all alias strings the AI
        #    might return for "full analysis", plus original keys.
        # ─────────────────────────────────────────────────────
        route_map = {
            "balance sheet":        self.analysisTheBalanceSheet,
            "income statement":     self.analysisIncomeStatement,
            "cash flow":            self.analysisCashFlow,
            "shareholding pattern": self.analysisShareholders,
            "valuation ratios":     self.analysisFinancialRatios,
            "financial ratios":     self.analysisFinancialRatios,
            "news":                 self.analysisNews,
            # All full-analysis aliases resolve to the same handler
            **{alias: lambda: self.analysisTheStock("full_analysis")
               for alias in FULL_ANALYSIS_ALIASES},
        }

        for analysis_type in responses:

            handler = route_map.get(analysis_type)

            if not handler:
                yield {
                    "status":  "error",
                    "message": f"Unknown analysis type: '{analysis_type}' — supported: {list(route_map.keys())}",
                }
                continue

            yield {
                "status":  "processing",
                "message": f"Running {analysis_type}...",
            }

            async for item in handler():
                yield item