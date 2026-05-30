from .models import AIResponse
from asgiref.sync import sync_to_async


class SavingResponse:

    @staticmethod
    @sync_to_async
    def alreadyExists(stock_symbol, analysis_type):

        stock_symbol = stock_symbol.strip().upper()

        ai_response = AIResponse.objects.filter(
            stock_symbol=stock_symbol,
            analysis_type=analysis_type
        ).first()

        if ai_response and not ai_response.is_expired():
            return ai_response.response

        return False

    @staticmethod
    @sync_to_async
    def savingTheData(stock_symbol, response, analysis_type):

        stock_symbol = stock_symbol.strip().upper()

        ai_response = AIResponse.objects.create(
            stock_symbol=stock_symbol,
            analysis_type=analysis_type,
            response=response
        )

        return ai_response.response