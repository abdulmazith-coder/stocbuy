from playwright.async_api import async_playwright, TimeoutError
from dotenv import load_dotenv
import asyncio
import os
import yfinance as yf

from myapp.clean_data.validate_exchange import validate_exchange

load_dotenv()


class ScrapingNewsData:
    def __init__(self, companyName):
        self.companyName = companyName
        self.ticker = validate_exchange(companyName)

    def scrapingNews(self):

        try:
            stock = self.ticker
            news_data = stock.news
            return news_data if news_data else None
        except Exception as e:
            print(f"Error fetching news data: {e}")
            return None




        



# a = ScrapingNewsData(companyName="TCS")
# value = a.scrapingNews()
# print(value)

# return news_data if news_data else None