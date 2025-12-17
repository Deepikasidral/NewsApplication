from pymongo import MongoClient
import os
from dotenv import load_dotenv

load_dotenv()

client = MongoClient(os.getenv("MONGO_URI"))
db = client[os.getenv("DB_NAME")]

def normalize(text: str) -> str:
    return text.lower().replace("limited", "").replace("ltd", "").strip()

def load_companies():
    cursor = db["Company_data"].find({}, {"_id": 0, "SYMBOL": 1, "NAME OF COMPANY": 1})

    keyword_to_company = {}
    keywords = set()

    STOPWORDS = {
        "limited", "ltd", "india", "company", "finance",
        "bank", "capital", "financial", "services"
    }

    for row in cursor:
        symbol = row["SYMBOL"].lower()
        name = normalize(row["NAME OF COMPANY"])

        words = [w for w in name.split() if w not in STOPWORDS]

        if not words:
            continue

        primary = words[0]   # 🔑 FIRST UNIQUE WORD

        # Symbol match
        keyword_to_company[symbol] = primary
        keywords.add(symbol)

        # Word matches
        for w in words:
            keyword_to_company[w] = primary
            keywords.add(w)

    return sorted(keywords, key=len, reverse=True), keyword_to_company
