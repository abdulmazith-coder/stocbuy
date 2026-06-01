import json
from groq import Groq
import os
from dotenv import load_dotenv
import asyncio
from myapp.ai_funactions.system_instrustion.wordfinding_prompt import system_instruction_wordfinding
from myapp.datasource.all_stock_data import StockData
from myapp.datasource.scraping.company_news import ScrapingNewsData
load_dotenv()


client = Groq(
    api_key=os.getenv("AI_API_KEY")
)

client_2 = Groq(
    api_key=os.getenv("AI_API_KEY_2")
)

client_3 = Groq(
    api_key=os.getenv("AI_API_KEY_3")
    
)

client_4 = Groq(
    api_key=os.getenv("AI_API_KEY_4")
)

class AIAnalsysis:

    @staticmethod
    def aiAnalysis(prompt,data,system_instruction):
        response = client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {"role": "system", "content": system_instruction},
                {"role": "user", "content":f"prompt: {prompt}, data: {data}"}
            ],
            temperature=1,
            max_tokens=1024,
            top_p=1,
        )
        if response.choices[0].message.content:
            return response.choices[0].message.content
        else:
            return None


    @staticmethod
    def aiAnalysis_2(prompt,data,system_instruction):
        response = client_2.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {"role": "system", "content": system_instruction},
                {"role": "user", "content":f"prompt: {prompt}, data: {data}"}
            ],
            temperature=1,
            max_completion_tokens=1024,
            top_p=1,
        )
        if response.choices[0].message.content:
            return response.choices[0].message.content
        else:
            return None

    @staticmethod
    def aiAnalysis_3(prompt,data,system_instruction):
        response = client_3.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {"role": "system", "content": system_instruction},
                {"role": "user", "content":f"prompt: {prompt}, data: {data}"}
            ],
            temperature=1,
            max_completion_tokens=1024,
            top_p=1,
        )
        if response.choices[0].message.content:
            return response.choices[0].message.content
        else:
            
            return None

    @staticmethod
    def aiAnalysis_4(prompt,data,system_instruction):
        response = client_4.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {"role": "system", "content":f"System Instruction: {system_instruction} , company deatils: {data}"},
                {"role": "user", "content":f"prompt: {prompt}"}
            ],
            temperature=1,
            max_completion_tokens=1024,
            top_p=1,
        )
        if response.choices[0].message.content:
            return response.choices[0].message.content
        else:
            return None
