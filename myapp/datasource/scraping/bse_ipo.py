import os
import asyncio
from playwright.async_api import async_playwright
from dotenv import load_dotenv

load_dotenv()


class ScrapingBSEIPO:

    def __init__(self):
        self.base_url = os.getenv("BSE_IPO_URL")

    async def scraping_bse_ipo(self):
        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(
                headless=True,
                args=[
                    "--disable-blink-features=AutomationControlled",
                    "--no-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-web-security",
                    "--disable-gpu",
                    "--window-size=1366,768",
                    '--single-process',
                ]
            )
            context = await browser.new_context(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                viewport={"width": 1366, "height": 768},
                locale="en-US",
                timezone_id="Asia/Kolkata",
                extra_http_headers={
                    "Accept-Language": "en-US,en;q=0.9",
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                    "Accept-Encoding": "gzip, deflate, br",
                    "Connection": "keep-alive",
                    "Upgrade-Insecure-Requests": "1",
                    "sec-ch-ua": '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
                    "sec-ch-ua-mobile": "?0",
                    "sec-ch-ua-platform": '"Windows"',
                }
            )

            # Inject stealth scripts manually — no external library needed
            await context.add_init_script("""
                // Hide webdriver
                Object.defineProperty(navigator, 'webdriver', { get: () => undefined });

                // Fake plugins
                Object.defineProperty(navigator, 'plugins', {
                    get: () => [
                        { name: 'Chrome PDF Plugin' },
                        { name: 'Chrome PDF Viewer' },
                        { name: 'Native Client' }
                    ]
                });

                // Fake languages
                Object.defineProperty(navigator, 'languages', {
                    get: () => ['en-US', 'en']
                });

                // Fake chrome object
                window.chrome = {
                    runtime: {},
                    loadTimes: function() {},
                    csi: function() {},
                    app: {}
                };

                // Fake permissions
                const originalQuery = window.navigator.permissions.query;
                window.navigator.permissions.query = (parameters) => (
                    parameters.name === 'notifications'
                        ? Promise.resolve({ state: Notification.permission })
                        : originalQuery(parameters)
                );

                // Hide headless in user agent data
                Object.defineProperty(navigator, 'userAgentData', {
                    get: () => ({
                        brands: [
                            { brand: 'Chromium', version: '120' },
                            { brand: 'Google Chrome', version: '120' },
                            { brand: 'Not_A Brand', version: '8' }
                        ],
                        mobile: false,
                        platform: 'Windows'
                    })
                });
            """)

            page = await context.new_page()

            try:
                await page.goto(self.base_url, wait_until="domcontentloaded", timeout=30000)

                await page.wait_for_selector(
                    'div.col-lg-12 tbody tr',
                    timeout=20000,
                    state="visible"
                )
                await page.wait_for_timeout(2000)

                table = page.locator('div.col-lg-12')
                heading = await table.locator("thead th").all_text_contents()
                heading = [h.strip() for h in heading if h.strip()]

                listofipos = table.locator("tbody tr")
                totalListofIpos = await listofipos.count()

                allIpos = []
                current_ipo = []
                upcoming_ipo = []

                for i in range(totalListofIpos):
                    cols = listofipos.nth(i).locator('td')
                    cols_text = await cols.all_text_contents()
                    cols_text = [text.strip() for text in cols_text if text.strip()]
                    if cols_text and len(cols_text) == len(heading):
                        allIpos.append(dict(zip(heading, cols_text)))

                for ipo in allIpos:
                    status = ipo.get('Issue Status', '').lower()
                    if status == 'live':
                        current_ipo.append(ipo)
                    elif status == 'forthcoming':
                        upcoming_ipo.append(ipo)

                return {
                    'current_ipo': current_ipo,
                    'upcoming_ipo': upcoming_ipo
                }

            except Exception as e:
                print(f"Error: {e}")
                return {'current_ipo': [], 'upcoming_ipo': []}

            finally:
                await browser.close()


# a = ScrapingBSEIPO()
# value = asyncio.run(a.scraping_bse_ipo())
# print(value)