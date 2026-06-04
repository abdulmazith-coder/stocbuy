import os
import logging
import requests
import yfinance as yf
from concurrent.futures import ThreadPoolExecutor, as_completed

logger = logging.getLogger(__name__)


class NSEExchangeApis:
    """
    Wrapper for NSE APIs (IPO, Market Status, Peer Companies, Top Gainers/Losers)
    """

    BASE_HEADERS = {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json"
    }

    TIMEOUT = 10        # seconds for NSE API requests
    MAX_WORKERS = 10    # parallel threads for yfinance fetches

    # ------------------------------------------------------------------ #
    #  Internal helpers                                                    #
    # ------------------------------------------------------------------ #

    def _get_request(self, url: str):
        """
        Makes a GET request to the given URL and returns parsed JSON.
        Returns None on any error.
        """
        try:
            if not url:
                raise ValueError("URL is missing")

            response = requests.get(url, headers=self.BASE_HEADERS, timeout=self.TIMEOUT)

            if response.status_code != 200:
                logger.error(f"NSE API failed: {url} | Status: {response.status_code}")
                return None

            return response.json()

        except requests.exceptions.Timeout:
            logger.error(f"Timeout error while calling NSE API: {url}")
        except requests.exceptions.RequestException as e:
            logger.error(f"Request error: {str(e)}")
        except ValueError as e:
            logger.error(str(e))
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}")

        return None

    def _fetch_ticker_info(self, symbol: str, exchange: str) -> dict | None:
        """
        Fetches yfinance info for a single symbol + exchange combination.

        Args:
            symbol:   NSE stock symbol e.g. "RELIANCE"
            exchange: "NS" for NSE, "BO" for BSE

        Returns:
            dict with keys {exchange, symbol, info} on success, else None.
        """
        try:
            ticker = yf.Ticker(f"{symbol}.{exchange}")
            info = ticker.info

            # yfinance returns a minimal stub dict when a symbol is invalid;
            # filter those out by checking for a meaningful field.
            if info and info.get("quoteType") not in (None, ""):
                return {"exchange": exchange, "symbol": symbol, "info": info}

        except Exception as e:
            logger.warning(f"Failed to fetch {symbol}.{exchange}: {e}")

        return None

    def _fetch_top_stocks(self, url: str) -> list[dict]:
        """
        Generic method that:
          1. Calls the given NSE URL to get a list of stock symbols.
          2. Fetches yfinance data for every symbol on both NSE and BSE in parallel.
          3. Returns a list with one dict: {"nse": [...], "bse": [...]}.

        Args:
            url: NSE endpoint for top gainers or top losers.

        Returns:
            [{"nse": [<ticker_info>, ...], "bse": [<ticker_info>, ...]}]
        """
        data = self._get_request(url)

        if not data or "NIFTY" not in data:
            logger.error(f"Unexpected or empty response from: {url}")
            return [{"nse": [], "bse": []}]

        symbols = [item["symbol"] for item in data["NIFTY"].get("data", [])]

        if not symbols:
            return [{"nse": [], "bse": []}]

        # Cartesian product: every symbol × both exchanges
        tasks = [
            (symbol, exchange)
            for symbol in symbols
            for exchange in ("NS", "BO")
        ]

        list_of_stocks_nse: list[dict] = []
        list_of_stocks_bse: list[dict] = []

        with ThreadPoolExecutor(max_workers=self.MAX_WORKERS) as executor:
            future_to_task = {
                executor.submit(self._fetch_ticker_info, symbol, exchange): (symbol, exchange)
                for symbol, exchange in tasks
            }

            for future in as_completed(future_to_task):
                try:
                    result = future.result()
                except Exception as e:
                    symbol, exchange = future_to_task[future]
                    logger.warning(f"Unhandled error for {symbol}.{exchange}: {e}")
                    continue

                if result:
                    if result["exchange"] == "NS":
                        list_of_stocks_nse.append(result["info"])
                    else:
                        list_of_stocks_bse.append(result["info"])

        return [{"nse": list_of_stocks_nse, "bse": list_of_stocks_bse}]

    # ------------------------------------------------------------------ #
    #  Public API methods                                                  #
    # ------------------------------------------------------------------ #

    def get_current_ipo(self) -> dict:
        """Returns currently open IPOs from NSE."""
        url = os.getenv("NSE_Current_IPO_URL")
        data = self._get_request(url)
        return {
            "type": "current",
            "data": data or []
        }

    def get_upcoming_ipo(self) -> dict:
        """Returns upcoming IPOs from NSE."""
        url = os.getenv("NSE_UPCOMING_IPO_URL")
        data = self._get_request(url)
        return {
            "type": "upcoming",
            "data": data or []
        }

    def get_market_status(self) -> dict:
        """Returns the current NSE market status (open/closed, etc.)."""
        url = os.getenv("NSE_MARKET_ACTIVATE_URL")
        data = self._get_request(url)
        return {
            "market_status": data or {}
        }

    def get_peer_companies(self, stock_symbol: str) -> dict:
        """
        Returns peer/competitor companies for the given stock symbol.

        Args:
            stock_symbol: NSE ticker symbol e.g. "INFY"
        """
        if not stock_symbol:
            return {"data": []}

        base_url = os.getenv("NSE_PEER_COMPETITOR_URL")
        param = os.getenv("NSE_PEER_COMPETITOR_URL_PARAM")
        url = f"{base_url}{stock_symbol}{param}"
        data = self._get_request(url)

        return {
            "symbol": stock_symbol,
            "data": data or []
        }

    def get_top_gains_stocks(self) -> list[dict]:
        """
        Returns top gaining NIFTY stocks with yfinance data for both NSE and BSE.
        Fetches all tickers in parallel for maximum speed.
        """
        url = os.getenv("NSE_TOP_GAINS_STOCKS_URL")
        return self._fetch_top_stocks(url)

    def get_top_losers_stocks(self) -> list[dict]:
        """
        Returns top losing NIFTY stocks with yfinance data for both NSE and BSE.
        Fetches all tickers in parallel for maximum speed.
        """
        url = os.getenv("NSE_TOP_LOSERS_STOCKS_URL")
        return self._fetch_top_stocks(url)



a = NSEExchangeApis()
# print(a.get_peer_companies("TCS"))
# print(a.get_current_ipo())
# print(a.get_upcoming_ipo())
print(a.get_top_gains_stocks())
        


    