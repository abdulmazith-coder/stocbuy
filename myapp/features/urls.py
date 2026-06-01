from django.urls import path
from myapp.features.company_news_api import *
from myapp.features.exchange_isactive import *
from myapp.features.ipos_apis import *
from myapp.features.peers_companies import *
from myapp.features.sebi_adviser_api import *
from myapp.features.stock_financial_data import *
from myapp.features.stock_info_api import *
from myapp.features.history_price import *
from myapp.features.search_stock_api import *
from myapp.features.stock_filter import *
from myapp.features.top_companies_apis import *
from myapp.features.top_gain_stocks_api import *
from myapp.features.top_loss_stocks_api import *
from myapp.features.ai_analysis_apis import *
from myapp.features.normal_chat_apis import *
from myapp.features.index_apis import *
from myapp.features.future_target import FutureTargetAPI
from myapp.features.indiavix_apis import IndiaVIXDataAPI
from myapp.features.market_breadth_apis import MarketBreadthAPI
from myapp.features.market_rsi_api import MarketRSIAPIView
from myapp.features.rate_limit import AiAnalysisUsageView

urlpatterns = [
    path('company-news/', CompanyNewsAPI.as_view(), name='company-news'),
    path('exchange-isactive/', ExchangeActiveAPI.as_view(), name='exchange-isactive'),
    path('ipos/', IPOsAPI.as_view(), name='ipos'),
    path('peers-companies/', PeerCompaniesAPI.as_view(), name='peers-companies'),
    path('sebi-adviser/', SEBIAdvisorAPI.as_view(), name='sebi-adviser'),
    path('stock-financial-data/', StockFinancialDataAPI.as_view(), name='stock-financial-data'),
    path('stock-info/', StockInfoAPI.as_view(), name='stock-info'),
    path('history-price/', StockPriceAPI.as_view(), name='history-price'),
    path('1m-price-history/', Stock1mPriceAPI.as_view(), name='1m-price-history'),
    path('search-stock/', StockSearchAPI.as_view(), name='search-stock'),
    path('penny-stock-filter/', StockFilterAPI.as_view(), name='penny-stock-filter'),
    path('top-companies/', TopCompaniesAPI.as_view(), name='top-companies'),
    path('top-gain-stocks/', TopGainStocksAPI.as_view(), name='top-gain-stocks'),
    path('top-loss-stocks/', TopLossStocksAPI.as_view(), name='top-loss-stocks'),
    path('ai-analysis/', AiAnalysisAPI.as_view(), name='ai-analysis'),
    path('normal-chat/', NormalChatAPI.as_view(), name='normal-chat'),
    path('index-data/', IndexDataAPI.as_view(), name='index-data'),
    path('future-target/', FutureTargetAPI.as_view(), name='future-target'),
    path('indiavix-data/', IndiaVIXDataAPI.as_view(), name='indiavix-data'),
    path('market-breadth/', MarketBreadthAPI.as_view(), name='market-breadth'),
    path('market-rsi/', MarketRSIAPIView.as_view(), name='market-rsi'),
    path('ai-analysis-usage/', AiAnalysisUsageView.as_view(), name='ai-analysis-usage'),
]