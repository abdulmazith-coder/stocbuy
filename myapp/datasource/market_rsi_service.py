import yfinance as yf
import pandas as pd
from datetime import datetime, UTC


class MarketRSIService:
    def __init__(self, period: int = 14):
        self.period = period

        self.indices = {
            "NIFTY_50": "^NSEI",
            "SENSEX": "^BSESN",
        }

    def calculate_rsi(self, close_prices: pd.Series) -> pd.Series:

        delta = close_prices.diff()

        gain = delta.clip(lower=0)
        loss = -delta.clip(upper=0)

        avg_gain = gain.ewm(
            alpha=1 / self.period,
            min_periods=self.period,
            adjust=False,
        ).mean()

        avg_loss = loss.ewm(
            alpha=1 / self.period,
            min_periods=self.period,
            adjust=False,
        ).mean()

        rs = avg_gain / avg_loss

        rsi = 100 - (100 / (1 + rs))

        return rsi.round(2)

    def get_signal(self, rsi: float) -> str:

        if rsi >= 70:
            return "OVERBOUGHT"

        elif rsi <= 30:
            return "OVERSOLD"

        elif rsi >= 60:
            return "BULLISH"

        elif rsi <= 40:
            return "BEARISH"

        return "NEUTRAL"

    def get_market_rsi(self) -> dict:

        final_output = {
            "success": True,
            "timestamp": datetime.now(UTC).isoformat(),
            "data": {},
        }

        for index_name, symbol in self.indices.items():

            try:

                df = yf.download(
                    symbol,
                    period="6mo",
                    interval="1d",
                    auto_adjust=True,
                    progress=False,
                )

                if df.empty:

                    final_output["data"][index_name] = {
                        "success": False,
                        "message": "No data found",
                    }

                    continue

                # FIX
                close_prices = df["Close"].squeeze()

                rsi_series = self.calculate_rsi(close_prices)

                rsi_clean = rsi_series.dropna()

                latest_rsi = float(rsi_clean.iloc[-1])

                previous_rsi = float(rsi_clean.iloc[-2])

                latest_close = round(
                    float(close_prices.dropna().iloc[-1]),
                    2,
                )

                final_output["data"][index_name] = {
                    "success": True,
                    "symbol": symbol,
                    "close": latest_close,
                    "rsi": round(latest_rsi, 2),
                    "previous_rsi": round(previous_rsi, 2),
                    "rsi_change": round(
                        latest_rsi - previous_rsi,
                        2,
                    ),
                    "signal": self.get_signal(latest_rsi),
                    "market_trend": (
                        "UPTREND"
                        if latest_rsi >= 50
                        else "DOWNTREND"
                    ),
                }

            except Exception as e:

                final_output["data"][index_name] = {
                    "success": False,
                    "message": str(e),
                }

        return final_output


# if __name__ == "__main__":

#     service = MarketRSIService()

#     result = service.get_market_rsi()

#     print(result)