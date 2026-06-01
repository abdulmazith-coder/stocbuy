# import requests
# from dotenv import load_dotenv
# import os
# import logging
# from urllib.parse import urlencode

# load_dotenv()
# logger = logging.getLogger(__name__)


# class SEBIRegisterApis:
#     """
#     Service to fetch SEBI Registered Advisors from Supabase
#     """

#     BASE_HEADERS = {
#         "apikey": os.getenv("SUPABASE_KEY_SEBI_REGISTER"),
#         "Authorization": f"Bearer {os.getenv('SUPABASE_KEY_SEBI_REGISTER')}",
#         "Content-Type": "application/json"
#     }

#     TIMEOUT = 10

#     def _get_request(self, url: str):
#         try:
#             response = requests.get(url, headers=self.BASE_HEADERS, timeout=self.TIMEOUT)

#             if response.status_code != 200:
#                 logger.error(f"Supabase API failed: {url} | Status: {response.status_code}")
#                 return None

#             return response.json()

#         except requests.exceptions.Timeout:
#             logger.error(f"Timeout while calling Supabase API: {url}")
#         except requests.exceptions.RequestException as e:
#             logger.error(f"Request error: {str(e)}")
#         except Exception as e:
#             logger.error(f"Unexpected error: {str(e)}")

#         return None

#     def get_sebi_register_data(self, state=None, city=None, advisor_name=None, register_number=None):
#         base_url = os.getenv("SUPABASE_TABLE_SEBI_REGISTER")

#         filters = {}

#         if state:
#             filters["State"] = f"eq.{state.strip().upper()}"
#         if city:
#             filters["City"] = f"eq.{city.strip().upper()}"
#         if advisor_name:
#             filters["Name"] = f"eq.{advisor_name.strip().upper()}"
#         if register_number:
#             filters["Register_Number"] = f"eq.{register_number.strip()}"

#         # Build query string correctly
#         query_string = urlencode(filters)
#         url = f"{base_url}?{query_string}&select=*"

#         data = self._get_request(url)

#         return {
#             "count": len(data) if data else 0,
#             "data": data or []
#         }


# a = SEBIRegisterApis()
# print(a.get_sebi_register_data(state="Tamil Nadu"))