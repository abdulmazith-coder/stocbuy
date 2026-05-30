from myapp.ai_funactions.ai_config.ai_config import AIAnalsysis
from myapp.ai_funactions.system_instrustion.normalchat_prompt import normal_chat_prompt
import yfinance as yf

from myapp.clean_data.validate_exchange import validate_exchange

class NormalChatAI:
    def __init__(self, user_response,stock_symbol):
        self.user_response = user_response
        self.stock_symbol = stock_symbol
        self.ticker = validate_exchange(self.stock_symbol)
    def normalChatAI(self):
        if not self.user_response:
            return None
        if not self.stock_symbol:
            return AIAnalsysis.aiAnalysis_4(
            self.user_response,None,normal_chat_prompt
        )
        info = self.ticker.info
        if not info:
            return None
        data = info
        aiResponse = AIAnalsysis.aiAnalysis_4(
            self.user_response,data,normal_chat_prompt
        )
        if not aiResponse:
            return None
        return aiResponse.strip().lower()