from mcp_server import tools

TOOL_REGISTRY = {
    "search_news": tools.search_news,
    "get_latest_news": tools.get_latest_news,
    "get_news_by_company": tools.get_news_by_company,
    "get_news_by_sentiment": tools.get_news_by_sentiment,
    "get_news_by_impact": tools.get_news_by_impact,
    "get_news_by_sector": tools.get_news_by_sector,
}
