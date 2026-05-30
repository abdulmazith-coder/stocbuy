"""
Stock Target Price & Recommendation Calculator
Uses yfinance to fetch real-time data and returns JSON output.
"""

import json
import yfinance as yf
import warnings

from myapp.clean_data.validate_exchange import validate_exchange
warnings.filterwarnings("ignore")


def get_recommendation(upside_pct: float) -> str:
    if upside_pct > 20:
        return "STRONG BUY"
    elif upside_pct > 10:
        return "BUY"
    elif upside_pct >= -10:
        return "HOLD"
    elif upside_pct >= -20:
        return "SELL"
    else:
        return "STRONG SELL"


def safe_get(info: dict, *keys, default=None):
    for key in keys:
        val = info.get(key)
        if val is not None and val != 0:
            return val
    return default


def analyze_stock(ticker: str, industry_pe: float = None, industry_pb: float = None) -> dict:
    """
    Fetch stock data and return target price analysis as a dict.

    Parameters
    ----------
    ticker       : Stock ticker symbol (e.g., 'RELIANCE.NS', 'AAPL')
    industry_pe  : Override industry P/E ratio (optional)
    industry_pb  : Override industry P/B ratio (optional)

    Returns
    -------
    dict with fundamentals, method-wise targets, and consensus
    """
    stock = validate_exchange(ticker)
    info  = stock.info

    name = info.get("longName") or info.get("shortName") or ticker
    cmp  = safe_get(info, "currentPrice", "regularMarketPrice", "previousClose")

    if cmp is None:
        return {"ticker": ticker, "error": "Could not fetch price. Check the ticker symbol."}

    # Key metrics
    eps         = safe_get(info, "trailingEps", "forwardEps")
    book_val    = safe_get(info, "bookValue")
    trailing_pe = safe_get(info, "trailingPE", "forwardPE")
    trailing_pb = safe_get(info, "priceToBook")
    ebitda      = safe_get(info, "ebitda")
    total_debt  = safe_get(info, "totalDebt",  default=0)
    cash        = safe_get(info, "totalCash",  default=0)
    shares_out  = safe_get(info, "sharesOutstanding")
    ev_ebitda   = safe_get(info, "enterpriseToEbitda")
    analyst_tp  = safe_get(info, "targetMeanPrice")

    fundamentals = {
        "company_name":       name,
        "ticker":             ticker.upper(),
        "current_price":      cmp,
        "eps":                eps,
        "book_value":         book_val,
        "trailing_pe":        trailing_pe,
        "trailing_pb":        trailing_pb,
        "ebitda":             ebitda,
        "ev_ebitda":          ev_ebitda,
        "total_debt":         total_debt,
        "cash":               cash,
        "shares_outstanding": shares_out,
    }

    methods = {}

    # Method 1: P/E
    if eps and eps > 0:
        target_pe = industry_pe if industry_pe else (round(trailing_pe * 1.05, 2) if trailing_pe else 15)
        tp_pe     = round(eps * target_pe, 2)
        upside_pe = round((tp_pe - cmp) / cmp * 100, 2)
        methods["pe_method"] = {
            "formula":        f"EPS ({eps}) × Target P/E ({target_pe})",
            "target_price":   tp_pe,
            "upside_pct":     upside_pe,
            "recommendation": get_recommendation(upside_pe),
        }

    # Method 2: P/B
    if book_val and book_val > 0:
        target_pb = industry_pb if industry_pb else (round(trailing_pb * 1.05, 2) if trailing_pb else 1.5)
        tp_pb     = round(book_val * target_pb, 2)
        upside_pb = round((tp_pb - cmp) / cmp * 100, 2)
        methods["pb_method"] = {
            "formula":        f"Book Value ({book_val}) × Target P/B ({target_pb})",
            "target_price":   tp_pb,
            "upside_pct":     upside_pb,
            "recommendation": get_recommendation(upside_pb),
        }

    # Method 3: EV/EBITDA
    if ebitda and ebitda > 0 and shares_out and shares_out > 0:
        target_ev = round(ev_ebitda * 1.05, 2) if ev_ebitda else 10
        net_debt  = total_debt - cash
        tp_ev     = round(((ebitda * target_ev) - net_debt) / shares_out, 2)
        upside_ev = round((tp_ev - cmp) / cmp * 100, 2)
        methods["ev_ebitda_method"] = {
            "formula":        f"(EBITDA ({ebitda}) × EV/EBITDA ({target_ev}) - Net Debt ({net_debt})) / Shares ({shares_out})",
            "target_price":   tp_ev,
            "upside_pct":     upside_ev,
            "recommendation": get_recommendation(upside_ev),
        }

    # Consensus
    consensus = {}
    if methods:
        prices     = [m["target_price"] for m in methods.values()]
        avg_target = round(sum(prices) / len(prices), 2)
        avg_upside = round((avg_target - cmp) / cmp * 100, 2)
        consensus  = {
            "average_target_price": avg_target,
            "upside_pct":           avg_upside,
            "recommendation":       get_recommendation(avg_upside),
            "methods_used":         list(methods.keys()),
        }

    # Analyst target (from yfinance)
    analyst = {}
    if analyst_tp:
        analyst_upside = round((analyst_tp - cmp) / cmp * 100, 2)
        analyst = {
            "target_price":   analyst_tp,
            "upside_pct":     analyst_upside,
            "recommendation": get_recommendation(analyst_upside),
        }

    return {
        "fundamentals":    fundamentals,
        "methods":         methods,
        "consensus":       consensus,
        "analyst_target":  analyst,
    }


# # ─────────────────────────────────────────────
# #  MAIN
# # ─────────────────────────────────────────────
# if __name__ == "__main__":
#     ticker = input("Enter stock name (e.g. RELIANCE.NS / TCS.NS / AAPL): ").strip()
#     result = analyze_stock(ticker)
#     print(json.dumps(result, indent=2))