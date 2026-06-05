import yfinance as yf
from myapp.clean_data.financila_statement import *
from myapp.clean_data.validate_exchange import *
from myapp.clean_data.convert_timestamps import *
import pytz
from datetime import datetime, date, time, timedelta
from myapp.datasource.nse_exchange_apis import *
from myapp.datasource.scraping.bse_ipo import *
from myapp.datasource.scraping.company_news import *
from myapp.datasource.sebi_register_adviser import *
from concurrent.futures import ThreadPoolExecutor, as_completed


class StockData:

    # ─── In-memory cache: { year: frozenset of trading dates } ───────────────
    _trading_dates_cache: dict = {}

    def __init__(self, stock_symbol: str):
        self.stock_symbol = stock_symbol
        self.ticker = validate_exchange(stock_symbol)

    # ═══════════════════════════════════════════════════════════════════════════
    #  PRIVATE ── Holiday Auto-Detection (no manual list needed)
    # ═══════════════════════════════════════════════════════════════════════════

    @staticmethod
    def _get_trading_dates(year: int) -> frozenset:
        """
        Fetch all NSE trading dates for a given year from ^NSEI history.
        Result is cached in _trading_dates_cache so yfinance is called
        only once per year per app session.
        """
        if year in StockData._trading_dates_cache:
            return StockData._trading_dates_cache[year]

        try:
            ticker = yf.Ticker("^NSEI")
            hist = ticker.history(
                start=f"{year}-01-01",
                end=f"{year}-12-31",
                auto_adjust=True,
                actions=False,
            )
            trading_dates = (
                frozenset(d.date() for d in hist.index)
                if not hist.empty
                else frozenset()
            )
        except Exception:
            trading_dates = frozenset()

        StockData._trading_dates_cache[year] = trading_dates
        return trading_dates

    @staticmethod
    def _is_historical_holiday(check_date: date) -> bool:
        """
        A weekday is a holiday if it has NO entry in ^NSEI yearly data.
        Reliable for any date before today (data already finalized).
        """
        trading_dates = StockData._get_trading_dates(check_date.year)
        if not trading_dates:
            return False
        return check_date not in trading_dates

    @staticmethod
    def _is_live_holiday(today: date) -> bool:
        """
        Intraday check — fetch today's 1-min ^NSEI bars.
        Empty result at/after 10:00 AM IST = confirmed holiday.
        """
        try:
            ticker = yf.Ticker("^NSEI")
            hist = ticker.history(
                start=str(today),
                end=str(today + timedelta(days=1)),
                interval="1m",
                actions=False,
            )
            return hist.empty
        except Exception:
            return False

    @staticmethod
    def _detect_holiday(today: date, now_ist: datetime) -> bool:
        """
        Two-stage holiday detection — no manual list required.
        """
        yesterday = today - timedelta(days=1)
        if yesterday >= date(today.year, 1, 1):
            if StockData._is_historical_holiday(today):
                return True

        if now_ist.time() >= time(10, 0):
            return StockData._is_live_holiday(today)

        return False

    # ═══════════════════════════════════════════════════════════════════════════
    #  Search  ── parallel fetch for speed
    # ═══════════════════════════════════════════════════════════════════════════

    @staticmethod
    def get_search_stock(stock_symbol: str):
        """
        Searches for Indian stock symbols using yfinance (NSE and BSE only).
        Returns up to 10 matching stocks.
        Direct ticker lookups run in parallel for speed.
        """
        if not stock_symbol:
            return []

        query = stock_symbol.strip().upper()
        results = []
        seen_symbols = set()

        # ── Strategy 1: Parallel direct ticker lookup (.NS and .BO) ──────────
        def _fetch_direct(suffix):
            direct_symbol = f"{query}{suffix}"
            try:
                ticker = yf.Ticker(direct_symbol)
                info = ticker.info
                if not info or info.get("regularMarketPrice") is None:
                    return None
                name = info.get("shortName") or info.get("longName") or direct_symbol
                exchange = info.get("exchange") or ("NSE" if suffix == ".NS" else "BSE")
                return {
                    "symbol": direct_symbol,
                    "name": name,
                    "exchange": exchange,
                }
            except Exception:
                return None

        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = {
                executor.submit(_fetch_direct, suffix): suffix
                for suffix in [".NS", ".BO"]
            }
            for future in as_completed(futures):
                result = future.result()
                if result and result["symbol"] not in seen_symbols:
                    results.append(result)
                    seen_symbols.add(result["symbol"])

        # ── Strategy 2: Broader suggestions via yf.Search ────────────────────
        try:
            search_result = yf.Search(query, max_results=20)
            quotes = getattr(search_result, "quotes", []) or []
            for quote in quotes:
                symbol = (quote.get("symbol") or "").upper()
                if not (symbol.endswith(".NS") or symbol.endswith(".BO")):
                    continue
                if symbol in seen_symbols:
                    continue
                name = quote.get("shortname") or quote.get("longname") or symbol
                exchange = (quote.get("exchange") or "").upper()
                results.append({
                    "symbol": symbol,
                    "name": name,
                    "exchange": exchange,
                })
                seen_symbols.add(symbol)
        except Exception:
            pass

        return results[:10]

    # ═══════════════════════════════════════════════════════════════════════════
    #  Stock Info & Peers
    # ═══════════════════════════════════════════════════════════════════════════

    def get_Stock_Info(self):
        if not self.ticker.info:
            return "Stock not found"
        return self.ticker.info

    def get_peer_competitor(self):
        stock_symbol = self.stock_symbol.replace(".NS", "")
        peer_competitor = NSEExchangeApis().get_peer_companies(stock_symbol)
        if not peer_competitor:
            return "No peer competitor data found"
        return peer_competitor

    # ═══════════════════════════════════════════════════════════════════════════
    #  Financial Statements  ── parallel fetch for speed
    # ═══════════════════════════════════════════════════════════════════════════

    def get_Stocks_Financial_Statement(self):
        """
        Fetches all four financial statement sheets in parallel threads
        so total wait time = slowest single fetch instead of sum of all.
        """
        def _fetch(attr):
            return getattr(self.ticker, attr)

        keys   = ["income_stmt", "balance_sheet", "cashflow", "major_holders"]
        fields = {}

        with ThreadPoolExecutor(max_workers=4) as executor:
            future_map = {executor.submit(_fetch, k): k for k in keys}
            for future in as_completed(future_map):
                key = future_map[future]
                try:
                    fields[key] = future.result()
                except Exception:
                    fields[key] = None

        income_statement = fields.get("income_stmt")
        balance_sheet    = fields.get("balance_sheet")
        cash_flow        = fields.get("cashflow")
        share_holders    = fields.get("major_holders")

        if (
            income_statement is None or income_statement.empty
            or balance_sheet is None or balance_sheet.empty
            or cash_flow is None or cash_flow.empty
        ):
            return "Stock not found"

        return {
            "share_holders":     clean_financial_data(share_holders),
            "income_statement":  clean_financial_data(income_statement),
            "balance_sheet":     clean_financial_data(balance_sheet),
            "cash_flow":         clean_financial_data(cash_flow),
        }

    # ═══════════════════════════════════════════════════════════════════════════
    #  IPO Data
    # ═══════════════════════════════════════════════════════════════════════════

    @staticmethod
    async def get_IPOs_Data():
        nse_current_ipo  = NSEExchangeApis().get_current_ipo()
        nse_upcoming_ipo = NSEExchangeApis().get_upcoming_ipo()
        bse_ipo          = await ScrapingBSEIPO().scraping_bse_ipo()
        return {
            "nse_current_ipo":  nse_current_ipo,
            "nse_upcoming_ipo": nse_upcoming_ipo,
            "bse_ipo":          bse_ipo,
        }

    # ═══════════════════════════════════════════════════════════════════════════
    #  Market Status ── AUTO holiday detection
    # ═══════════════════════════════════════════════════════════════════════════

    @staticmethod
    def is_market_open(symbol: str, exchange: str):
        try:
            IST           = pytz.timezone("Asia/Kolkata")
            now           = datetime.now(IST)
            today         = now.date()
            market_open   = time(9, 15)
            market_close  = time(15, 30)
            current_time  = now.time()

            is_weekday = now.weekday() < 5
            in_hours   = market_open <= current_time <= market_close

            is_holiday = (
                StockData._detect_holiday_nsei(today)
                if is_weekday else False
            )

            is_open        = is_weekday and in_hours and not is_holiday
            formatted_time = now.strftime("%d-%m-%Y %I:%M:%S %p")

            info = {}
            try:
                info = yf.Ticker(symbol).info or {}
            except Exception:
                pass

            raw_state = info.get("marketState", "UNKNOWN")
            clean_map = {
                "POSTPOST":        "POST",
                "POST POST":       "POST",
                "PREPRE":          "PRE",
                "REGULAREGULAR":   "OPEN",
                "REGULAR":         "OPEN",
                "PRE":             "PRE",
                "POST":            "POST",
            }
            yahoo_state = clean_map.get(raw_state, raw_state)

            return {
                "is_active":          "OPEN" if is_open else "CLOSED",
                "yahoo_state":        yahoo_state,
                "market_time":        formatted_time,
                "market_open_time":   "09:15 AM IST",
                "market_close_time":  "03:30 PM IST",
                "is_weekday":         is_weekday,
                "is_holiday":         is_holiday,
                "exchange":           info.get("exchange", exchange),
            }

        except Exception as e:
            return {
                "is_active": "ERROR",
                "error":     str(e),
            }

    @staticmethod
    def _detect_holiday_nsei(check_date):
        try:
            end_date   = check_date + timedelta(days=1)
            start_date = check_date - timedelta(days=90)

            nsei = yf.Ticker("^NSEI")
            hist = nsei.history(start=start_date, end=end_date)

            if hist is None or hist.empty or check_date not in hist.index.date:
                return True

            return False

        except Exception:
            return False

    # ═══════════════════════════════════════════════════════════════════════════
    #  SEBI Register
    # ═══════════════════════════════════════════════════════════════════════════

    @staticmethod
    def get_sebi_register_data(
        state: str, city: str, advisor_name: str, register_number: str
    ):
        sebi_register_data = SEBIRegisterApis().get_sebi_register_data(
            state, city, advisor_name, register_number
        )
        if not sebi_register_data:
            return "No SEBI register data found"
        return sebi_register_data

    # ═══════════════════════════════════════════════════════════════════════════
    #  Price History
    # ═══════════════════════════════════════════════════════════════════════════

    def get_stock_price_history(self, timing: str, isTread: bool, interval: str = None):
        if isTread:
            history = self.ticker.history(interval=f"{timing}")
        else:
            history = self.ticker.history(period=f"{timing}", interval=interval)

        if history.empty:
            return {"message": "No stock price history found"}

        history.reset_index(inplace=True)

        if "Datetime" in history.columns:
            history["Datetime"] = history["Datetime"].dt.strftime("%Y-%m-%d %H:%M:%S")
        if "Date" in history.columns:
            history["Date"] = history["Date"].dt.strftime("%Y-%m-%d")

        return history.to_dict(orient="records")

    def get_1m_price_history(self):
        history = self.ticker.history(period="1d", interval="1m")
        if history.empty:
            return {"message": "No stock price history found"}

        history.reset_index(inplace=True)
        if "Datetime" in history.columns:
            history["Datetime"] = history["Datetime"].dt.strftime("%Y-%m-%d %H:%M:%S")

        return history.to_dict(orient="records")

    # ═══════════════════════════════════════════════════════════════════════════
    #  Index Data
    # ═══════════════════════════════════════════════════════════════════════════

    @staticmethod
    def get_index_data():
        index_data = yf.Tickers("^NSEI ^BSESN")
        if not index_data:
            return "No index data found"
        return {
            "NSE_BOARD_INDEX": {
                "nifty50": index_data.tickers["^NSEI"].info,
                "sensex":  index_data.tickers["^BSESN"].info,
            }
        }


# ── test ──────────────────────────────────────────────────────────────────────
# if __name__ == "__main__":
#     value = StockData.get_search_stock("TCS")
#     print(value)