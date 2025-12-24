# from mcp.server.fastmcp import FastMCP
# from mcp_server.db import filtered_news


# mcp = FastMCP("RupeeLetter News MCP")

# @mcp.tool()
# def search_news(query: str, limit: int = 5):
#     """
#     Generic keyword search across news
#     """
#     docs = filtered_news.find(
#         {
#             "$or": [
#                 {"Headline": {"$regex": query, "$options": "i"}},
#                 {"summary": {"$regex": query, "$options": "i"}},
#                 {"companies": {"$regex": query, "$options": "i"}}
#             ]
#         },
#         {"_id": 0, "Headline": 1, "summary": 1, "sentiment": 1}
#     ).limit(limit)

#     return list(docs)


# @mcp.tool()
# def get_latest_news(limit: int = 5):
#     docs = filtered_news.find(
#         {},
#         {"_id": 0, "Headline": 1, "summary": 1, "sentiment": 1}
#     ).sort("processed_at", -1).limit(limit)

#     return list(docs)

# @mcp.tool()
# def get_news_by_company(
#     company: str | None = None,
#     company_name: str | None = None,
#     limit: int = 5
# ):
#     company_value = company or company_name
#     if not company_value:
#         return []

#     docs = filtered_news.find(
#         {"companies": {"$regex": company_value, "$options": "i"}},
#         {"_id": 0, "Headline": 1, "summary": 1, "sentiment": 1}
#     ).sort("processed_at", -1).limit(limit)

#     return list(docs)


# @mcp.tool()
# def get_news_by_sentiment(sentiment: str, limit: int = 5):
#     docs = filtered_news.find(
#         {"sentiment": sentiment},
#         {"_id": 0, "Headline": 1, "summary": 1}
#     ).limit(limit)

#     return list(docs)

# @mcp.tool()
# def get_news_by_sector(sector: str, limit: int = 5):
#     docs = filtered_news.find(
#         {"sector": {"$regex": sector, "$options": "i"}},
#         {"_id": 0, "Headline": 1, "summary": 1, "sentiment": 1, "impact": 1}
#     ).limit(limit)
#     return list(docs)


# @mcp.tool()
# def get_news_by_impact(impact: str, limit: int = 5):
#     docs = filtered_news.find(
#         {"impact": {"$regex": impact, "$options": "i"}},
#         {"_id": 0, "Headline": 1, "summary": 1, "sentiment": 1}
#     ).limit(limit)
#     return list(docs)


# @mcp.tool()
# def get_news_by_city(city: str, limit: int = 5):
#     docs = filtered_news.find(
#         {
#             "$or": [
#                 {"Headline": {"$regex": city, "$options": "i"}},
#                 {"story": {"$regex": city, "$options": "i"}}
#             ]
#         },
#         {"_id": 0, "Headline": 1, "summary": 1}
#     ).limit(limit)
#     return list(docs)


from mcp_server.db import filtered_news


def search_news(query: str, limit: int = 5):
    return list(filtered_news.find(
        {
            "$or": [
                {"Headline": {"$regex": query, "$options": "i"}},
                {"summary": {"$regex": query, "$options": "i"}},
                {"companies": {"$regex": query, "$options": "i"}},
            ]
        },
        {"_id": 0, "Headline": 1, "summary": 1, "sentiment": 1, "impact": 1}
    ).limit(limit))


def get_latest_news(limit: int = 5):
    return list(filtered_news.find(
        {},
        {"_id": 0, "Headline": 1, "summary": 1, "sentiment": 1, "impact": 1}
    ).sort("processed_at", -1).limit(limit))


def get_news_by_company(company: str, limit: int = 5):
    return list(filtered_news.find(
        {"companies": {"$regex": company, "$options": "i"}},
        {"_id": 0, "Headline": 1, "summary": 1, "sentiment": 1, "impact": 1}
    ).sort("processed_at", -1).limit(limit))


def get_news_by_sentiment(sentiment: str, limit: int = 5):
    return list(filtered_news.find(
        {"sentiment": {"$regex": sentiment, "$options": "i"}},
        {"_id": 0, "Headline": 1, "summary": 1, "impact": 1}
    ).limit(limit))


def get_news_by_impact(impact: str, limit: int = 5):
    return list(filtered_news.find(
        {"impact": {"$regex": impact, "$options": "i"}},
        {"_id": 0, "Headline": 1, "summary": 1, "sentiment": 1}
    ).limit(limit))


def get_news_by_sector(sector: str, limit: int = 5):
    return list(filtered_news.find(
        {"sector": {"$regex": sector, "$options": "i"}},
        {"_id": 0, "Headline": 1, "summary": 1, "sentiment": 1, "impact": 1}
    ).limit(limit))


