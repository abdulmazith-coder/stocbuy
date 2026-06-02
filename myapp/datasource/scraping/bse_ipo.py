import os
import httpx
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import asyncio
load_dotenv()


class ScrapingBSEIPO:

    def __init__(self):
        self.base_url = os.getenv("BSE_IPO_URL")

    async def scraping_bse_ipo(self):
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
            "sec-ch-ua": '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
            "sec-ch-ua-mobile": "?0",
            "sec-ch-ua-platform": '"Windows"',
            "Referer": "https://www.google.com/",
        }

        try:
            async with httpx.AsyncClient(
                headers=headers,
                follow_redirects=True,
                timeout=30.0,
            ) as client:
                response = await client.get(self.base_url)
                response.raise_for_status()

                # ✅ Parse inside the async with block while client/response is still alive
                soup = BeautifulSoup(response.text, "html.parser")

            table_div = soup.select_one("div.col-lg-12")
            if not table_div:
                print("Table div not found")
                return {"current_ipo": [], "upcoming_ipo": []}

            # Extract headings
            headings = [
                th.get_text(strip=True)
                for th in table_div.select("thead th")
                if th.get_text(strip=True)
            ]

            # Extract rows
            all_ipos = []
            for row in table_div.select("tbody tr"):
                cols = [
                    td.get_text(strip=True)
                    for td in row.select("td")
                    if td.get_text(strip=True)
                ]
                if cols and len(cols) == len(headings):
                    all_ipos.append(dict(zip(headings, cols)))

            # Categorize
            current_ipo = []
            upcoming_ipo = []

            for ipo in all_ipos:
                status = ipo.get("Issue Status", "").lower()
                if status == "live":
                    current_ipo.append(ipo)
                elif status == "forthcoming":
                    upcoming_ipo.append(ipo)

            return {
                "current_ipo": current_ipo,
                "upcoming_ipo": upcoming_ipo,
            }

        except httpx.HTTPStatusError as e:
            print(f"HTTP error: {e.response.status_code}")
            return {"current_ipo": [], "upcoming_ipo": []}
        except Exception as e:
            print(f"Error: {e}")
            return {"current_ipo": [], "upcoming_ipo": []}


a = ScrapingBSEIPO()
value = asyncio.run(a.scraping_bse_ipo())
print(value)