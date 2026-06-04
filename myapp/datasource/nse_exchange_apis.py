from dotenv import load_dotenv
import yfinance as yf
import os
import logging
import requests

load_dotenv()
logger = logging.getLogger(__name__)


class NSEExchangeApis:
    """
    Wrapper for NSE APIs (IPO, Market Status, Peer Companies)
    """

    BASE_HEADERS = {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json"
    }

    TIMEOUT = 10  # seconds

    def _get_request(self, url: str):
        try:
            if not url:
                raise ValueError("URL is missing")

            response = requests.get(url, headers=self.BASE_HEADERS, timeout=self.TIMEOUT)

            # Check HTTP status
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

    def get_current_ipo(self):
        url = os.getenv("NSE_Current_IPO_URL")
        data = self._get_request(url)

        return {
            "type": "current",
            "data": data or []
        }

    def get_upcoming_ipo(self):
        url = os.getenv("NSE_UPCOMING_IPO_URL")
        data = self._get_request(url)

        return {
            "type": "upcoming",
            "data": data or []
        }

    def get_market_status(self):
        url = os.getenv("NSE_MARKET_ACTIVATE_URL")
        data = self._get_request(url)

        return {
            "market_status": data or {}
        }

    def get_peer_companies(self, stock_symbol: str):
        base_url = os.getenv("NSE_PEER_COMPETITOR_URL")
        param = os.getenv("NSE_PEER_COMPETITOR_URL_PARAM")

        if not stock_symbol:
            return {"data": []}

        url = f"{base_url}{stock_symbol}{param}"
        data = self._get_request(url)

        return {
            "symbol": stock_symbol,
            "data": data or []
        }


    def get_top_gains_stocks(self):
        url = os.getenv("NSE_TOP_GAINS_STOCKS_URL")

        data = self._get_request(url)

        if not data:return {
            "success": False,
            "message": "Unable to fetch top gainers",
            "data": []
        }

        stocks = []

        try:
            for item in data.get("NIFTY", {}).get("data", [])[:10]:
                symbol = item.get("symbol")

            try:
                ticker = yf.Ticker(f"{symbol}.NS")

                fast_info = dict(ticker.fast_info)

                stocks.append({
                    "symbol": symbol,
                    "change": item.get("change"),
                    "pChange": item.get("pChange"),
                    "lastPrice": item.get("lastPrice"),
                    "marketCap": fast_info.get("market_cap"),
                    "currency": fast_info.get("currency"),
                    "dayHigh": fast_info.get("day_high"),
                    "dayLow": fast_info.get("day_low"),
                })

            except Exception as stock_error:
                logger.error(
                    f"Yahoo error for {symbol}: {stock_error}"
                )

            return {
            "success": True,
            "message": "Top gainers fetched successfully",
            "data": stocks
        }

        except Exception as e:
            logger.error(f"Top gainers error: {str(e)}")

            return {
            "success": False,
            "message": str(e),
            "data": []
        }

    
    def get_top_losers_stocks(self):
        list_of_stocks_nse = []
        list_of_stocks_bse = []
        list_of_stocks = []
        url = os.getenv("NSE_TOP_LOSERS_STOCKS_URL")
        data = self._get_request(url)
        for item in data["NIFTY"]["data"]:
            Nse_exchange = yf.Ticker(f"{item['symbol']}.NS")
            bse_exchange = yf.Ticker(f"{item['symbol']}.BO")
            if Nse_exchange:
                list_of_stocks_nse.append(Nse_exchange.info)
            if bse_exchange:
                list_of_stocks_bse.append(bse_exchange.info)
        list_of_stocks.append({"nse": list_of_stocks_nse, "bse": list_of_stocks_bse})
        return list_of_stocks






# a = NSEExchangeApis()
# # print(a.get_peer_companies("TCS"))
# # print(a.get_current_ipo())
# # print(a.get_upcoming_ipo())
# print(a.get_top_gains_stocks())
        


    