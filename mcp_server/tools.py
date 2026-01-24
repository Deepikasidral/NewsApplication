# import logging
# from mcp.server.fastmcp import FastMCP
# from mcp_server.db import filtered_news

# logger = logging.getLogger(__name__)

# logger.info("📦 Loading MCP tools...")

# mcp = FastMCP("RupeeLetter News MCP")

# @mcp.tool()
# def search_news(query: str, limit: int = 5):
#     """Search news by keyword"""
#     return list(filtered_news.find(
#         {
#             "$or": [
#                 {"Headline": {"$regex": query, "$options": "i"}},
#                 {"summary": {"$regex": query, "$options": "i"}},
#                 {"companies": {"$regex": query, "$options": "i"}},
#             ]
#         },
#         {"_id": 0}
#     ).limit(limit))


# @mcp.tool()
# def get_latest_news(limit: int = 5):
#     """Get latest news"""
#     return list(filtered_news.find(
#         {},
#         {"_id": 0}
#     ).sort("processed_at", -1).limit(limit))


# @mcp.tool()
# def get_news_by_company(company: str, limit: int = 5):
#     """Get news for a specific company"""
#     return list(filtered_news.find(
#         {"companies": {"$regex": company, "$options": "i"}},
#         {"_id": 0}
#     ).sort("processed_at", -1).limit(limit))


# @mcp.tool()
# def get_news_by_sentiment(sentiment: str, limit: int = 5):
#     """Get news by sentiment"""
#     return list(filtered_news.find(
#         {"sentiment": sentiment},
#         {"_id": 0}
#     ).limit(limit))


# @mcp.tool()
# def get_news_by_impact(impact: str, limit: int = 5):
#     """Get news by impact"""
#     return list(filtered_news.find(
#         {"impact": impact},
#         {"_id": 0}
#     ).limit(limit))


# @mcp.tool()
# def get_news_by_sector(sector: str, limit: int = 5):
#     """Get news by sector"""
#     return list(filtered_news.find(
#         {"sector": {"$regex": sector, "$options": "i"}},
#         {"_id": 0}
#     ).limit(limit))


from datetime import datetime
from bson import ObjectId
from mcp_server.db import filtered_news
import os
import requests
from datetime import datetime, timedelta
from pytz import timezone

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
    symbol = company.upper()

    

    if not company:
        return {"error": "Company name not detected"}

    symbol = company.upper()

    news = get_news_by_company(company, limit)

    finedge = {}
    try:
        resp = requests.get(
            f"{FINEDGE_BASE}/quote",
            params={"symbol": symbol, "token": FINEDGE_API_TOKEN},
            timeout=10
        )
        data = resp.json()
        finedge = {
            "price": data.get(symbol, {}).get("current_price"),
            "change": data.get(symbol, {}).get("change"),
            "change_percent": data.get(symbol, {}).get("percent_change"),
        }
    except Exception as e:
        finedge["error"] = str(e)

    return {
        "company": company,
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