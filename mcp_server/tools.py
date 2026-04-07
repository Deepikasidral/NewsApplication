from datetime import datetime
from bson import ObjectId
from mcp_server.db import filtered_news
import os
import requests
from datetime import datetime, timedelta
from pytz import timezone
from mcp_server.company_mapper import get_best_symbol
FINEDGE_API_TOKEN = os.getenv("FINEDGE_API_TOKEN")
FINEDGE_BASE = "https://data.finedgeapi.com/api/v1"
IST = timezone("Asia/Kolkata")

# --------------------------------
# Helpers
# --------------------------------
def serialize_doc(obj):
    if isinstance(obj, dict):
        return {k: serialize_doc(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [serialize_doc(item) for item in obj]
    elif isinstance(obj, ObjectId):
        return str(obj)
    elif isinstance(obj, datetime):
        return obj.isoformat()
    else:
        return obj


def compress_news(doc):
    """Return token-safe news signal"""
    return {
        "headline": doc.get("Headline"),
        "summary": doc.get("summary"),
        "impact": doc.get("impact"),
        "sentiment": doc.get("sentiment"),
    }


# --------------------------------
# Search news
# --------------------------------
def search_news(query: str, limit: int = 5):
    docs = list(
        filtered_news.find(
            {
                "$or": [
                    {"Headline": {"$regex": query, "$options": "i"}},
                    {"summary": {"$regex": query, "$options": "i"}},
                    {"companies": {"$regex": query, "$options": "i"}},
                ]
            },
            {
                "_id": 0,
                "Headline": 1,
                "summary": 1,
                "impact": 1,
                "sentiment": 1,
            }
        ).limit(min(limit, 5))
    )

    return [compress_news(d) for d in docs]


# --------------------------------
# Latest news
# --------------------------------
def get_latest_news(limit: int = 5):
    docs = list(
        filtered_news.find(
            {
                "impact": {"$in": ["Very High"]},
                "sentiment": {"$in": ["Very Bullish", "Very Bearish"]},
            },
            {
                "_id": 0,
                "Headline": 1,
                "summary": 1,
                "impact": 1,
                "sentiment": 1,
            }
        )
        .sort("PublishedAt", -1)
        .limit(min(limit, 5))
    )

    return [compress_news(d) for d in docs]


# --------------------------------
# Company news
# --------------------------------
def get_news_by_company(company: str, limit: int = 5):
    docs = list(
        filtered_news.find(
            {"companies": {"$regex": company, "$options": "i"}},
            {
                "_id": 0,
                "Headline": 1,
                "summary": 1,
                "impact": 1,
                "sentiment": 1,
            }
        )
        .sort("PublishedAt", -1)
        .limit(min(limit, 5))
    )

    return [compress_news(d) for d in docs]


# --------------------------------
# Sentiment-based news
# --------------------------------
def get_news_by_sentiment(sentiment: str, limit: int = 5):
    docs = list(
        filtered_news.find(
            {"sentiment": sentiment},
            {
                "_id": 0,
                "Headline": 1,
                "summary": 1,
                "impact": 1,
                "sentiment": 1,
            }
        ).limit(min(limit, 5))
    )

    return [compress_news(d) for d in docs]


# --------------------------------
# Impact-based news
# --------------------------------
def get_news_by_impact(impact: str, limit: int = 5):
    docs = list(
        filtered_news.find(
            {"impact": impact},
            {
                "_id": 0,
                "Headline": 1,
                "summary": 1,
                "impact": 1,
                "sentiment": 1,
            }
        ).limit(min(limit, 5))
    )

    return [compress_news(d) for d in docs]


# --------------------------------
# Company + Finedge quote
# --------------------------------
def finedge_company_tool(company: str, limit: int = 5):
    if not company:
        return {"error": "Company name not detected"}

    # 🔥 Clean input
    company_clean = company.lower().strip()

    # 🔥 Use intelligent mapper
    symbol = get_best_symbol(company_clean)

    print("🔍 INPUT COMPANY:", company)
    print("🔍 MAPPED SYMBOL:", symbol)

    news = get_news_by_company(company_clean, limit)

    finedge = {}
    try:
        resp = requests.get(
            f"{FINEDGE_BASE}/quote",
            params={"symbol": symbol, "token": FINEDGE_API_TOKEN},
            timeout=5
        )

        data = resp.json()
        print("🔥 API RESPONSE:", data)

        symbol_data = data.get(symbol, {})

        price = symbol_data.get("current_price")
        change = symbol_data.get("change")

        trend = "upward" if change and "+" in str(change) else "downward"

        finedge = {
            "price": price,
            "change": change,
            "trend": trend   # 🔥 ADD THIS
        }

    except Exception as e:
        print("❌ API ERROR:", str(e))
        finedge["error"] = str(e)

    return {
        "company": company_clean,
        "symbol": symbol,
        "quote": finedge,
        "news": news
    }

# --------------------------------
# Market news by date (today / yesterday / any date)
# --------------------------------
def get_market_news_by_date(date: str, limit: int = 10):
    try:
        dt = datetime.strptime(date, "%Y-%m-%d")
        start = IST.localize(dt).astimezone(timezone("UTC"))
        end = start + timedelta(days=1)
    except ValueError:
        return {"error": "Invalid date format. Use YYYY-MM-DD"}

    docs = list(
        filtered_news.find(
            {
                "ingested_at": {
                    "$gte": start,
                    "$lt": end
                },
                "impact": {"$regex": "High", "$options": "i"},
                "sentiment": {"$regex": "Bullish|Bearish", "$options": "i"},
            },
            {
                "_id": 0,
                "Headline": 1,
                "summary": 1,
                "impact": 1,
                "sentiment": 1,
                "ingested_at": 1,
            }
        )
        .sort("ingested_at", -1)
        .limit(limit)
    )

    return {
        "date": date,
        "count": len(docs),
        "news": [compress_news(d) for d in docs],
    }

def finedge_full_analysis_tool(company: str):
    if not company:
        return {"error": "Company name not provided"}

    symbol = company.upper()

    data = fetch_comprehensive_analysis(symbol)

    news = get_news_by_company(company, 5)

    return {
        "company": company,
        "symbol": symbol,
        "financials": data,
        "news": news
    }

def fetch_comprehensive_analysis(symbol: str):
    try:
        resp = requests.get(
            f"{FINEDGE_BASE}/quote",
            params={"symbol": symbol, "token": FINEDGE_API_TOKEN},
            timeout=10
        )
        return resp.json()
    except Exception as e:
        return {"error": str(e)}