"""
Stock Target Price & Recommendation Calculator
Uses yfinance to fetch real-time data and returns JSON output.
"""

import json
import math
import warnings

import yfinance as yf

from myapp.clean_data.validate_exchange import validate_exchange

warnings.filterwarnings("ignore")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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


def _upside(target: float, cmp: float) -> float:
    return round((target - cmp) / cmp * 100, 2)


# ---------------------------------------------------------------------------
# Main function
# ---------------------------------------------------------------------------

def analyze_stock(
    ticker: str,
    industry_pe: float = None,
    industry_pb: float = None,
) -> dict:
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
    info = stock.info

    name = info.get("longName") or info.get("shortName") or ticker
    cmp = safe_get(info, "currentPrice", "regularMarketPrice", "previousClose")

    if cmp is None or cmp <= 0:
        return {"ticker": ticker, "error": "Could not fetch price. Check the ticker symbol."}

    # -----------------------------------------------------------------------
    # Key metrics
    # -----------------------------------------------------------------------
    eps = safe_get(info, "trailingEps", "forwardEps")
    book_val = safe_get(info, "bookValue")
    trailing_pe = safe_get(info, "trailingPE", "forwardPE")
    trailing_pb = safe_get(info, "priceToBook")
    ebitda = safe_get(info, "ebitda")
    total_debt = safe_get(info, "totalDebt", default=0)
    cash = safe_get(info, "totalCash", default=0)
    shares_out = safe_get(info, "sharesOutstanding")
    ev_ebitda = safe_get(info, "enterpriseToEbitda")
    analyst_tp = safe_get(info, "targetMeanPrice")

    # New metrics
    free_cashflow = safe_get(info, "freeCashflow")
    dividend_yield = safe_get(info, "dividendYield", default=0)
    peg_ratio = safe_get(info, "pegRatio")
    revenue_growth = safe_get(info, "revenueGrowth")          # e.g. 0.12 → 12 %
    earnings_growth = safe_get(info, "earningsGrowth")        # e.g. 0.15 → 15 %
    beta = safe_get(info, "beta", default=1.0)
    sector = info.get("sector", "Unknown")
    industry = info.get("industry", "Unknown")

    fundamentals = {
        "company_name": name,
        "ticker": ticker.upper(),
        "current_price": cmp,
        "eps": eps,
        "book_value": book_val,
        "trailing_pe": trailing_pe,
        "trailing_pb": trailing_pb,
        "ebitda": ebitda,
        "ev_ebitda": ev_ebitda,
        "total_debt": total_debt,
        "cash": cash,
        "shares_outstanding": shares_out,
        # New additions
        "free_cashflow": free_cashflow,
        "dividend_yield": round(dividend_yield * 100, 4) if dividend_yield else None,
        "peg_ratio": peg_ratio,
        "revenue_growth_pct": round(revenue_growth * 100, 2) if revenue_growth else None,
        "earnings_growth_pct": round(earnings_growth * 100, 2) if earnings_growth else None,
        "beta": beta,
        "sector": sector,
        "industry": industry,
    }

    methods = {}

    # -----------------------------------------------------------------------
    # Method 1 : P/E Valuation
    # -----------------------------------------------------------------------
    if eps and eps > 0:
        if industry_pe:
            target_pe = industry_pe
            pe_note = "industry P/E override"
        elif trailing_pe and trailing_pe > 0:
            # Cap at 80 to avoid distortion from bubble valuations
            target_pe = round(min(trailing_pe * 1.05, 80), 2)
            pe_note = "trailing P/E × 1.05 (capped at 80)"
        else:
            target_pe = 15.0
            pe_note = "default P/E fallback (15)"

        tp_pe = round(eps * target_pe, 2)
        methods["pe_method"] = {
            "formula": f"EPS ({eps}) × Target P/E ({target_pe}) [{pe_note}]",
            "target_price": tp_pe,
            "upside_pct": _upside(tp_pe, cmp),
            "recommendation": get_recommendation(_upside(tp_pe, cmp)),
        }

    # -----------------------------------------------------------------------
    # Method 2 : P/B Valuation
    # -----------------------------------------------------------------------
    if book_val and book_val > 0:
        if industry_pb:
            target_pb = industry_pb
            pb_note = "industry P/B override"
        elif trailing_pb and trailing_pb > 0:
            target_pb = round(min(trailing_pb * 1.05, 20), 2)
            pb_note = "trailing P/B × 1.05 (capped at 20)"
        else:
            target_pb = 1.5
            pb_note = "default P/B fallback (1.5)"

        tp_pb = round(book_val * target_pb, 2)
        methods["pb_method"] = {
            "formula": f"Book Value ({book_val}) × Target P/B ({target_pb}) [{pb_note}]",
            "target_price": tp_pb,
            "upside_pct": _upside(tp_pb, cmp),
            "recommendation": get_recommendation(_upside(tp_pb, cmp)),
        }

    # -----------------------------------------------------------------------
    # Method 3 : EV / EBITDA
    # -----------------------------------------------------------------------
    if ebitda and ebitda > 0 and shares_out and shares_out > 0:
        target_ev_multiple = round(ev_ebitda * 1.05, 2) if (ev_ebitda and ev_ebitda > 0) else 10.0
        net_debt = (total_debt or 0) - (cash or 0)
        enterprise_value = ebitda * target_ev_multiple
        equity_value = enterprise_value - net_debt
        if equity_value > 0:
            tp_ev = round(equity_value / shares_out, 2)
            methods["ev_ebitda_method"] = {
                "formula": (
                    f"(EBITDA ({ebitda}) × EV/EBITDA ({target_ev_multiple})"
                    f" − Net Debt ({net_debt})) / Shares ({shares_out})"
                ),
                "target_price": tp_ev,
                "upside_pct": _upside(tp_ev, cmp),
                "recommendation": get_recommendation(_upside(tp_ev, cmp)),
            }

    # -----------------------------------------------------------------------
    # Method 4 : Graham Number  √(22.5 × EPS × Book Value)
    # Classic Benjamin Graham intrinsic value formula
    # -----------------------------------------------------------------------
    if eps and eps > 0 and book_val and book_val > 0:
        graham_raw = 22.5 * eps * book_val
        if graham_raw > 0:
            tp_graham = round(math.sqrt(graham_raw), 2)
            methods["graham_number"] = {
                "formula": f"√(22.5 × EPS ({eps}) × Book Value ({book_val}))",
                "target_price": tp_graham,
                "upside_pct": _upside(tp_graham, cmp),
                "recommendation": get_recommendation(_upside(tp_graham, cmp)),
            }

    # -----------------------------------------------------------------------
    # Method 5 : DCF (simplified Free Cash Flow)
    # 5-year FCF growth projection, then terminal value, discounted back
    # -----------------------------------------------------------------------
    if free_cashflow and free_cashflow > 0 and shares_out and shares_out > 0:
        # Growth rate: use earnings growth if available, else conservative 8 %
        if earnings_growth and -0.5 < earnings_growth < 1.0:
            fcf_growth = earnings_growth
        else:
            fcf_growth = 0.08

        # Discount rate: CAPM-style rough estimate  (risk-free 7 % + beta × 5 % ERP)
        risk_free = 0.07                               # India 10-yr Gsec proxy
        erp = 0.05                                     # equity risk premium
        discount_rate = risk_free + (beta or 1.0) * erp
        terminal_growth = 0.04                         # long-term terminal growth

        # Project FCF for 5 years and discount
        dcf_value = 0.0
        fcf = free_cashflow
        for yr in range(1, 6):
            fcf = fcf * (1 + fcf_growth)
            dcf_value += fcf / ((1 + discount_rate) ** yr)

        # Terminal value (Gordon Growth Model) discounted to present
        terminal_fcf = fcf * (1 + terminal_growth)
        if discount_rate > terminal_growth:
            terminal_value = terminal_fcf / (discount_rate - terminal_growth)
            terminal_value_pv = terminal_value / ((1 + discount_rate) ** 5)
            dcf_value += terminal_value_pv

        # Add cash, subtract debt for equity value
        equity_dcf = dcf_value + (cash or 0) - (total_debt or 0)
        if equity_dcf > 0:
            tp_dcf = round(equity_dcf / shares_out, 2)
            methods["dcf_method"] = {
                "formula": (
                    f"5-yr FCF DCF | FCF ({free_cashflow}) | "
                    f"Growth ({round(fcf_growth*100,1)}%) | "
                    f"Discount ({round(discount_rate*100,1)}%) | "
                    f"Terminal ({round(terminal_growth*100,1)}%)"
                ),
                "target_price": tp_dcf,
                "upside_pct": _upside(tp_dcf, cmp),
                "recommendation": get_recommendation(_upside(tp_dcf, cmp)),
                "assumptions": {
                    "fcf_growth_pct": round(fcf_growth * 100, 2),
                    "discount_rate_pct": round(discount_rate * 100, 2),
                    "terminal_growth_pct": round(terminal_growth * 100, 2),
                    "projection_years": 5,
                },
            }

    # -----------------------------------------------------------------------
    # Weighted Consensus  (P/E and Analyst weighted higher)
    # -----------------------------------------------------------------------
    WEIGHTS = {
        "pe_method":      3,
        "pb_method":      1,
        "ev_ebitda_method": 2,
        "graham_number":  2,
        "dcf_method":     2,
    }

    consensus = {}
    if methods:
        total_weight = 0.0
        weighted_sum = 0.0
        for method_key, method_data in methods.items():
            w = WEIGHTS.get(method_key, 1)
            weighted_sum += method_data["target_price"] * w
            total_weight += w

        avg_target = round(weighted_sum / total_weight, 2)
        avg_upside = _upside(avg_target, cmp)

        # Margin of Safety: how far CMP is below the consensus target
        margin_of_safety_pct = round((avg_target - cmp) / avg_target * 100, 2) if avg_target > 0 else None

        consensus = {
            "average_target_price": avg_target,
            "upside_pct": avg_upside,
            "recommendation": get_recommendation(avg_upside),
            "methods_used": list(methods.keys()),
            "margin_of_safety_pct": margin_of_safety_pct,
            "weighting_note": "P/E ×3, EV/EBITDA ×2, Graham ×2, DCF ×2, P/B ×1",
        }

    # -----------------------------------------------------------------------
    # Analyst consensus (from yfinance)
    # -----------------------------------------------------------------------
    analyst = {}
    if analyst_tp:
        analyst_upside = _upside(analyst_tp, cmp)
        analyst = {
            "target_price": analyst_tp,
            "upside_pct": analyst_upside,
            "recommendation": get_recommendation(analyst_upside),
        }

    return {
        "fundamentals": fundamentals,
        "methods": methods,
        "consensus": consensus,
        "analyst_target": analyst,
    }

# # ─────────────────────────────────────────────
# #  MAIN
# # ─────────────────────────────────────────────
# if __name__ == "__main__":
#     ticker = input("Enter stock name (e.g. RELIANCE.NS / TCS.NS / AAPL): ").strip()
#     result = analyze_stock(ticker)
#     print(json.dumps(result, indent=2))