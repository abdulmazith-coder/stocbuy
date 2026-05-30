import yfinance as yf



class TopCompanies:

    def __init__(self):
        self.top_companies = [
    "RELIANCE.NS",      # Reliance Industries
    "TCS.NS",           # Tata Consultancy Services
    "INFY.NS",          # Infosys
    "HDFCBANK.NS",      # HDFC Bank
    "ICICIBANK.NS",     # ICICI Bank
    "SBIN.NS",          # State Bank of India
    "BHARTIARTL.NS",    # Bharti Airtel
    "ITC.NS",           # ITC
    "LT.NS",            # Larsen & Toubro
    "KOTAKBANK.NS",     # Kotak Mahindra Bank
    "HINDUNILVR.NS",    # Hindustan Unilever
    "AXISBANK.NS",      # Axis Bank
    "BAJFINANCE.NS",    # Bajaj Finance
    "ASIANPAINT.NS",    # Asian Paints
    "MARUTI.NS",        # Maruti Suzuki
    "SUNPHARMA.NS",     # Sun Pharma
    "TITAN.NS",         # Titan Company
    "ULTRACEMCO.NS",    # UltraTech Cement
    "WIPRO.NS",         # Wipro
    "ADANIENT.NS"       # Adani Enterprises
        ]

    def get_top_companies(self):
        top_companies_data = []
        for company in self.top_companies:
            ticker = yf.Ticker(company)
            info = ticker.info
            if not info:
                continue
            current_price = info.get("currentPrice")
            previous_close = info.get("previousClose")
            change_percent = (
                (current_price - previous_close) / previous_close * 100
            )
            top_companies_data.append({
                "company":info.get("symbol").replace(".NS", ""),
                "current_price": current_price,
                "change_percent": round(change_percent, 2)
            })
        return top_companies_data
    

