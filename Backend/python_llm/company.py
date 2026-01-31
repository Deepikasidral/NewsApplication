import pandas as pd
from pymongo import MongoClient

# ---------------- CONFIG ----------------
MONGO_URI = "mongodb+srv://deepikasidral:deep@cluster0.dq1txpn.mongodb.net/New_application?retryWrites=true&w=majority&appName=Cluster0"
DB_NAME = "New_application"
COLLECTION_NAME = "Company_data"
CSV_FILE_PATH = "New_Company_Data.csv"
#---------------------------------------

def clean_value(val):
    if pd.isna(val):
        return ""
    return str(val).strip()

def main():
    client = MongoClient(MONGO_URI)
    db = client[DB_NAME]
    collection = db[COLLECTION_NAME]

    # 🔥 FULL REPLACE
    result = collection.delete_many({})
    print(f"🗑️ Deleted {result.deleted_count} existing records")

    # READ CSV
    df = pd.read_csv(CSV_FILE_PATH)

    documents = []

    for _, row in df.iterrows():
        doc = {
            "SYMBOL": clean_value(row.get("SYMBOL")),
            "NAME OF COMPANY": clean_value(row.get("NAME OF COMPANY")),
            "ISIN NUMBER": clean_value(row.get("ISIN NUMBER")),
            "EXCHANGE": clean_value(row.get("Exchange"))
        }

        # Skip empty symbols (important)
        if not doc["SYMBOL"]:
            continue

        documents.append(doc)

    if documents:
        collection.insert_many(documents)
        print(f"✅ Inserted {len(documents)} new records")

    # 🔒 CREATE INDEXES (VERY IMPORTANT)
    collection.create_index("SYMBOL", unique=True)


    print("🎉 Company_data collection fully replaced & indexed")

if __name__ == "__main__":
    main()



#news delete

# from datetime import datetime, timedelta
# from pymongo import MongoClient
# import os

# # -----------------------------
# # MongoDB Atlas Connection
# # -----------------------------
# MONGO_URI ="mongodb+srv://deepikasidral:deep@cluster0.dq1txpn.mongodb.net/New_application?retryWrites=true&w=majority&appName=Cluster0"

# DB_NAME = "New_application"
# COLLECTION_NAME = "filtered_news"

# client = MongoClient(MONGO_URI)
# db = client[DB_NAME]
# collection = db[COLLECTION_NAME]

# # -----------------------------
# # Calculate last week date
# # -----------------------------
# last_week = datetime.utcnow() - timedelta(days=4)

# # -----------------------------
# # Delete old news
# # -----------------------------
# result = collection.delete_many({
#     "ingested_at": {
#         "$lt": last_week
#     }
# })

# # -----------------------------
# # Output
# # -----------------------------
# print(f"Deleted {result.deleted_count} news articles older than 7 days")

# client.close()


#api news 

# import requests
# import json
# from datetime import datetime, timedelta
# from urllib.parse import quote
# from pytz import timezone as pytz_timezone
# import time

# # ==============================
# # CONFIG
# # ==============================
# IST = pytz_timezone("Asia/Kolkata")

# START_TIME = IST.localize(datetime(2026, 1, 24, 8, 0, 0))
# END_TIME = datetime.now(IST)

# CHUNK_MINUTES = 30   # PTI API safe window
# OUTPUT_FILE = "pti_news_21jan_to_now.json"

# BASE_URL = (
#     "https://editorial.pti.in/ptiapi/webservice1.asmx/JsonFile1"
#     "?centercode=17102025001RL"
# )

# HEADERS = {
#     "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
#     "Accept": "application/json, text/plain, */*",
#     "Accept-Language": "en-US,en;q=0.9",
#     "Referer": "https://editorial.pti.in/",
#     "Origin": "https://editorial.pti.in",
#     "Connection": "keep-alive",
# }
# def get_article_date(article):
#     """
#     Extract YYYY-MM-DD from PTI FileName.
#     Example FileName: 2401202624DEL4 -> 2026-01-24
#     """
#     fname = article.get("FileName", "")
#     if len(fname) >= 8 and fname[:8].isdigit():
#         day = fname[0:2]
#         month = fname[2:4]
#         year = fname[4:8]
#         return f"{year}-{month}-{day}"
#     return "unknown"



# # ==============================
# # FETCH FUNCTION
# # ==============================
# def fetch_pti_news(from_time, to_time, retries=3):
#     url = (
#         f"{BASE_URL}"
#         f"&FromTime={quote(from_time.strftime('%Y/%m/%d %H:%M:%S'))}"
#         f"&EndTime={quote(to_time.strftime('%Y/%m/%d %H:%M:%S'))}"
#     )

#     for attempt in range(1, retries + 1):
#         try:
#             response = requests.get(url, headers=HEADERS, timeout=30)

#             if response.status_code != 200:
#                 print(f"❌ HTTP {response.status_code}")
#                 return []

#             text = response.text.strip()

#             if not text:
#                 print(f"⚠️ Empty response (attempt {attempt}/{retries})")
#                 time.sleep(2)
#                 continue

#             if not (text.startswith("{") or text.startswith("[")):
#                 print("⚠️ Non-JSON response")
#                 return []

#             data = json.loads(text)

#             if isinstance(data, list):
#                 return data
#             elif isinstance(data, dict):
#                 return data.get("Table", [])

#             return []

#         except Exception as e:
#             print(f"❌ Error: {e}")
#             time.sleep(2)

#     # After retries
#     print("⚠️ Giving up on this window")
#     return []



# # ==============================
# # MAIN RUNNER
# # ==============================
# def run():
#     all_articles = []
#     daily_counts = {}   # 🔥 date → count
#     current_start = START_TIME

#     print(f"🚀 Fetching PTI news from {START_TIME} to {END_TIME}")

#     while current_start < END_TIME:
#         current_end = min(current_start + timedelta(minutes=CHUNK_MINUTES), END_TIME)

#         print(f"⏱ Fetching: {current_start} → {current_end}")
#         articles = fetch_pti_news(current_start, current_end)

#         if articles:
#             print(f"✅ Fetched {len(articles)} articles")

#             for article in articles:
#                 all_articles.append(article)

#                 # 🧮 Count per day
#                 date_key = get_article_date(article)
#                 daily_counts[date_key] = daily_counts.get(date_key, 0) + 1
#         else:
#             print("⚠️ No articles in this window")

#         current_start = current_end
#         time.sleep(1)

#     print(f"\n📦 Total articles fetched: {len(all_articles)}")

#     # 🔥 Final structured output
#     final_output = {
#         "daily_counts": daily_counts,
#         "total_articles": len(all_articles),
#         "articles": all_articles
#     }

#     with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
#         json.dump(final_output, f, ensure_ascii=False, indent=2)

#     print(f"💾 Saved to {OUTPUT_FILE}")

# # ==============================
# # ENTRY POINT
# # ==============================
# if __name__ == "__main__":
#     run()
