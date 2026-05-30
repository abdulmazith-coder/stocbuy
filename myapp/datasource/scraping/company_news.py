from playwright.async_api import async_playwright, TimeoutError
from dotenv import load_dotenv
import asyncio
import os

load_dotenv()


class ScrapingNewsData:
    def __init__(self, companyName):
        self.companyName = companyName

    async def scrapingNews(self,days):
        url = os.getenv("Google_NEWS_FIRST_URL")
        base_url = os.getenv("Google_NEWS_SECOND_URL")

        async with async_playwright() as pw:
            browser = await pw.chromium.launch(
                headless=True,
                args=["--no-sandbox", "--disable-dev-shm-usage"]
            )
            page = await browser.new_page()

            # Block heavy resources not needed for scraping
            await page.route(
                "**/*",
                lambda route: route.abort()
                if route.request.resource_type in ["image", "stylesheet", "font", "media"]
                else route.continue_()
            )

            await page.goto(url, wait_until="domcontentloaded")

            search = page.get_by_role(
                "combobox", name="Search for topics, locations & sources"
            )
            await search.fill(f"{self.companyName} company news {days}")
            await search.press("Enter")

            # Wait for news cards to appear
            try:
                await page.wait_for_selector("div.IL9Cne a.JtKRv", timeout=8000)
            except TimeoutError:
                await browser.close()
                return None

            try:
                await page.wait_for_selector(
                    "div.UW0SDc time.hvbAAd", timeout=5000
                )
            except TimeoutError:
                pass

            news_data = await page.evaluate("""
                (baseUrl) => {
                    const links = document.querySelectorAll("div.IL9Cne a.JtKRv");
                    const times = document.querySelectorAll("div.UW0SDc time.hvbAAd");

                    return Array.from(links).map((a, i) => {
                        let href = a.getAttribute("href") || "";
                        if (href.startsWith("./")) href = baseUrl + href.slice(1);
                        return {
                            title: a.innerText.trim(),
                            time: times[i]?.getAttribute("datetime") || times[i]?.innerText?.trim() || null,
                            link: href || null
                        };
                    }).filter(item => item.link);
                }
            """, base_url)
            print(len(news_data))
            
            await browser.close() 
            return news_data if news_data else None
        



# a = ScrapingNewsData(companyName="TCS")
# value = asyncio.run(a.scrapingNews(days="when:7d"))
# print(value)