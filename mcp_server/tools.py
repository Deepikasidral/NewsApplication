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


def serialize_doc(obj):
    """
    Recursively convert MongoDB document to JSON-serializable format
    - ObjectId -> str
    - datetime -> ISO string
    """
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
            {"_id": 0}  # still fine to exclude _id
        ).limit(limit)
    )

    return [serialize_doc(d) for d in docs]


def get_latest_news(limit: int = 5):
    docs = list(
        filtered_news.find(
            {},
            {"_id": 0}
        ).sort("processed_at", -1).limit(limit)
    )

    return [serialize_doc(d) for d in docs]


def get_news_by_company(company: str, limit: int = 5):
    docs = list(
        filtered_news.find(
            {"companies": {"$regex": company, "$options": "i"}},
            {"_id": 0}
        ).sort("processed_at", -1).limit(limit)
    )

    return [serialize_doc(d) for d in docs]


def get_news_by_sentiment(sentiment: str, limit: int = 5):
    docs = list(
        filtered_news.find(
            {"sentiment": sentiment},
            {"_id": 0}
        ).limit(limit)
    )

    return [serialize_doc(d) for d in docs]


def get_news_by_impact(impact: str, limit: int = 5):
    docs = list(
        filtered_news.find(
            {"impact": impact},
            {"_id": 0}
        ).limit(limit)
    )

    return [serialize_doc(d) for d in docs]