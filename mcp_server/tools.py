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
from db import filtered_news
import os
import requests
from datetime import datetime, timedelta
from pytz import timezone
from finedge_tools import (
    fetch_comprehensive_analysis,
    fetch_income_statement,
    fetch_balance_sheet,
    fetch_cash_flow,
    fetch_ratios,
    fetch_valuation,
    fetch_quote
)
from yahoo_finance_tools import (
    get_real_time_price,
    get_trending_stocks,
    get_top_gainers,
    get_top_losers,
    get_market_summary,
    search_and_get_price
)

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
# Company Analysis Tool
# --------------------------------
def get_company_analysis(company: str, analysis_type: str = "comprehensive"):
    """Get comprehensive company analysis with all financial data"""
    # Smart symbol mapping
    from symbol_mapper import get_best_symbol, get_company_display_name
    
    symbol = get_best_symbol(company)
    display_name = get_company_display_name(symbol)
    
    print(f"🔍 Mapping '{company}' → '{symbol}' ({display_name})")
    
    if analysis_type == "comprehensive":
        result = fetch_comprehensive_analysis(symbol)
        result["display_name"] = display_name
        result["original_query"] = company
        return result
    elif analysis_type == "financial":
        return {
            "symbol": symbol,
            "display_name": display_name,
            "original_query": company,
            "income_statement": fetch_income_statement(symbol),
            "balance_sheet": fetch_balance_sheet(symbol),
            "cash_flow": fetch_cash_flow(symbol)
        }
    elif analysis_type == "valuation":
        return {
            "symbol": symbol,
            "display_name": display_name,
            "original_query": company,
            "ratios": fetch_ratios(symbol),
            "valuation": fetch_valuation(symbol),
            "quote": fetch_quote(symbol)
        }
    else:
        result = fetch_comprehensive_analysis(symbol)
        result["display_name"] = display_name
        result["original_query"] = company
        return result


# --------------------------------
# Company Financial Health Tool
# --------------------------------
def analyze_financial_health(company: str):
    """Analyze company's financial health with key metrics"""
    from symbol_mapper import get_best_symbol, get_company_display_name
    
    symbol = get_best_symbol(company)
    display_name = get_company_display_name(symbol)
    
    print(f"🔍 Mapping '{company}' → '{symbol}' ({display_name})")
    
    data = fetch_comprehensive_analysis(symbol)
    
    # Extract key health indicators
    health_metrics = {}
    
    try:
        income = data.get("income_statement", {})
        balance = data.get("balance_sheet", {})
        ratios = data.get("ratios", {})
        
        # Revenue growth
        if income.get("revenue"):
            health_metrics["revenue"] = income["revenue"]
        
        # Profitability
        if income.get("net_profit"):
            health_metrics["net_profit"] = income["net_profit"]
            
        # Debt levels
        if balance.get("total_debt"):
            health_metrics["total_debt"] = balance["total_debt"]
            
        # Key ratios
        if ratios.get("debt_to_equity"):
            health_metrics["debt_to_equity"] = ratios["debt_to_equity"]
            
    except Exception as e:
        health_metrics["error"] = str(e)
    
    return {
        "symbol": symbol,
        "display_name": display_name,
        "original_query": company,
        "health_metrics": health_metrics,
        "full_data": data
    }
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

# Yahoo Finance Tools
def get_stock_price(company: str):
    """Get real-time stock price"""
    return search_and_get_price(company)

def get_trending_stocks_today(limit: int = 10):
    """Get today's trending stocks"""
    return get_trending_stocks("today", limit)

def get_trending_stocks_weekly(limit: int = 10):
    """Get weekly trending stocks"""
    return get_trending_stocks("weekly", limit)

def get_top_gainers_today(limit: int = 10):
    """Get top gaining stocks today"""
    return get_top_gainers("today", limit)

def get_top_gainers_weekly(limit: int = 10):
    """Get top gaining stocks this week"""
    return get_top_gainers("weekly", limit)

def get_top_losers_today(limit: int = 10):
    """Get top losing stocks today"""
    return get_top_losers("today", limit)

def get_top_losers_weekly(limit: int = 10):
    """Get top losing stocks this week"""
    return get_top_losers("weekly", limit)

def get_market_overview():
    """Get market overview"""
    return get_market_summary()