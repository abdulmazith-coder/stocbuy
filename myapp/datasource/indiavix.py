import yfinance as yf
import pandas as pd


class IndiaVixSentimentSystem:

    def __init__(self):
        self.vix_symbol = "^INDIAVIX"
        self.nifty_symbol = "^NSEI"

    # -----------------------------
    # Fetch Market Data
    # -----------------------------
    def fetch_data(self):

        vix = yf.Ticker(self.vix_symbol)
        nifty = yf.Ticker(self.nifty_symbol)

        vix_data = vix.history(period="10d")
        nifty_data = nifty.history(period="10d")

        return vix_data, nifty_data

    # -----------------------------
    # Current India VIX
    # -----------------------------
    def get_current_vix(self, vix_data):

        return round(vix_data["Close"].iloc[-1], 2)

    # -----------------------------
    # Daily VIX Change %
    # -----------------------------
    def get_vix_change_percent(self, vix_data):

        today = vix_data["Close"].iloc[-1]
        yesterday = vix_data["Close"].iloc[-2]

        change = ((today - yesterday) / yesterday) * 100

        return round(change, 2)

    # -----------------------------
    # NIFTY Daily Change %
    # -----------------------------
    def get_nifty_change_percent(self, nifty_data):

        today = nifty_data["Close"].iloc[-1]
        yesterday = nifty_data["Close"].iloc[-2]

        change = ((today - yesterday) / yesterday) * 100

        return round(change, 2)

    # -----------------------------
    # Market Sentiment
    # -----------------------------
    def market_sentiment(self, current_vix):

        if current_vix < 12:
            return {
                "sentiment": "Very Calm",
                "market_condition": "Stable Bullish",
                "risk_level": "Low"
            }

        elif current_vix < 18:
            return {
                "sentiment": "Normal",
                "market_condition": "Healthy Market",
                "risk_level": "Medium"
            }

        elif current_vix < 25:
            return {
                "sentiment": "Fear Increasing",
                "market_condition": "Volatile Market",
                "risk_level": "High"
            }

        else:
            return {
                "sentiment": "Panic",
                "market_condition": "Highly Volatile",
                "risk_level": "Very High"
            }

    # -----------------------------
    # Detect Panic Selling
    # -----------------------------
    def detect_panic_selling(
        self,
        nifty_change,
        vix_change
    ):

        if nifty_change < -1 and vix_change > 5:
            return True

        return False

    # -----------------------------
    # Sentiment Score
    # -----------------------------
    def sentiment_score(self, current_vix):

        score = max(0, 100 - (current_vix * 4))

        return round(score, 2)

    # -----------------------------
    # Final Analysis
    # -----------------------------
    def analyze_market(self):

        vix_data, nifty_data = self.fetch_data()

        current_vix = self.get_current_vix(vix_data)

        vix_change = self.get_vix_change_percent(vix_data)

        nifty_change = self.get_nifty_change_percent(nifty_data)

        sentiment = self.market_sentiment(current_vix)

        panic = self.detect_panic_selling(
            nifty_change,
            vix_change
        )

        score = self.sentiment_score(current_vix)

        result = {
            "India_VIX": float(current_vix),
            "VIX_Change_%": float(vix_change),
            "NIFTY_Change_%": float(nifty_change),
            "Sentiment": sentiment["sentiment"],
            "Market_Condition": sentiment["market_condition"],
            "Risk_Level": sentiment["risk_level"],
            "Sentiment_Score": float(score),
            "Panic_Selling": panic
        }

        return result


# -----------------------------------
# Run System
# -----------------------------------

# market = IndiaVixSentimentSystem()

# result = market.analyze_market()

# print(result)