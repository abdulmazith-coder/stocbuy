import yfinance as yf


def validate_exchange(stock_symbol: str):
    if not stock_symbol:
        return "Invalid stock symbol"

    stock_symbol = stock_symbol.upper()

    try:
        # Try NSE first
        ns_ticker = yf.Ticker(f"{stock_symbol}.NS")
        if ns_ticker.balance_sheet.empty:
            bo_ticker = yf.Ticker(f"{stock_symbol}.BO")
            if bo_ticker.balance_sheet.empty:
                return None
            else:
                return bo_ticker
        else:
            return ns_ticker

    except Exception as error:
        return f"Error fetching stock data: {error}"

