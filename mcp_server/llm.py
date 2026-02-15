
import json
from openai import OpenAI
from datetime import datetime
from pytz import timezone

from config import OPENAI_API_KEY
from tools import (
    search_news,
    get_latest_news,
    get_news_by_sentiment,
    get_news_by_impact,
    finedge_company_tool,
    get_market_news_by_date,
    get_company_analysis,
    analyze_financial_health,
    get_stock_price,
    get_trending_stocks_today,
    get_trending_stocks_weekly,
    get_top_gainers_today,
    get_top_gainers_weekly,
    get_top_losers_today,
    get_top_losers_weekly,
    get_market_overview
)
from symbol_mapper import get_best_symbol, get_company_display_name

# ============================
# TIME & MEMORY
# ============================
IST = timezone("Asia/Kolkata")
today = datetime.now(IST).strftime("%B %d, %Y")
CHAT_HISTORY = []

# ============================
# 🔐 FINAL ANSWER PROMPT
# ============================
SYSTEM_FINAL_PROMPT = f"""
You are a professional financial analyst and market expert.

CRITICAL INSTRUCTIONS:
- Today's date is {today} (IST).
- You will receive ACTUAL DATA from tools - YOU MUST USE THIS DATA in your response
- NEVER give generic answers when specific data is provided
- Extract and present ALL relevant numbers, prices, percentages, and company names from the data
- If news data is provided, analyze sentiment and impact on investment decisions
- If price data is provided, include current price, change %, volume, and trading range
- Combine multiple data sources (price + news + sentiment) for comprehensive analysis

RESPONSE STYLE:
- Start with a direct answer using ACTUAL DATA from the information provided
- Use bullet points for clarity
- Include ALL specific numbers, percentages, and stock names from the data
- Add sector analysis and market context based on the data
- End with actionable takeaways based on the data

FORMAT EXAMPLES:

**For stock performance queries:**
"Based on latest trading session (date):
Top gainers (NSE/BSE):
• [Stock Name] — up ~X.X% — [reason]
• [Stock Name] — up ~X.X% on [catalyst]

Other notable outperformers:
• [Additional context]

Note: [Market breadth/sector rotation insights]"

**For investment advice:**
"📌 Key takeaway: [Comprehensive 3-line summary covering market context, stock outlook, and strategic recommendation. Include broader market implications and sector dynamics that influence the investment decision.]

Short answer: [Direct recommendation]

Investment Perspective (Long-term)
[Detailed analysis with bullet points]

Trading Perspective (Short-term)
[Technical/momentum analysis]

Actionable Summary
Profile | Action
Long-term investor | [specific action]
Short-term trader | [specific action]"

**For market recap:**
"Weekly/Daily summary (ending date):
• [Major benchmark performance with specific %]
• [Key drivers and catalysts]
• [Sector performance]
• [Currency/commodity impact]

📉/📈 Key takeaway: [Market sentiment summary]"

**For index prices:**
"As of [time/date]:
📈 Nifty 50: ~X,XXX.XX points
📉 Sensex: ~XX,XXX.XX points

Note: [Session highlights and sector performance]"

CORE BEHAVIOR:
1. WHEN data is available → Use specific numbers and company names
2. WHEN data is limited → Provide general market context and methodology
3. ALWAYS include actionable insights
4. Use emojis strategically (📈📉💰⚠️📌)
5. Mention specific sectors, catalysts, and market drivers

MANDATORY:
- End with: "💡 You may also ask:"
- Suggest 2–3 relevant follow-up questions
"""


# ============================
# 🧠 TOOL DECISION PROMPT
# ============================
TOOL_DECISION_PROMPT = f"""
IMPORTANT:
- Today's date is {datetime.now(IST).strftime("%Y-%m-%d")} (IST).
- Never guess dates.
- If a date is mentioned or implied, resolve it carefully.

If the question asks about "top performing stocks" but the information
contains only news-based signals (sentiment, impact, headlines):
- Reframe the answer as "stocks with strong positive news momentum"
- Do NOT claim price performance
- Clearly present it as news-driven performance


DATE RESOLUTION RULES:
- "today" → today’s date
- "yesterday" → today - 1 day
- "day before yesterday" → today - 2 days
- "last week" → today - 7 days
- "last month" → today - 30 days
- Explicit dates (e.g. "Jan 15", "15 Jan 2026") → convert to YYYY-MM-DD
- If the user asks about a previous day or past date, ALWAYS treat it as a date-based query.

TOOL_SELECTION RULES:

1. If the user asks about:
   - market performance on any date
   - top performing stocks on a previous date
   - yesterday / last week / any past day
   - market conditions on a specific date

   → YOU MUST call: get_market_news_by_date
   → Pass the resolved date in YYYY-MM-DD format.

2. If the user asks about:
   - "this week" top gainers/losers
   - "weekly" top gainers/losers
   - best/worst performers "this week"
   
   → YOU MUST call: get_trending_stocks_weekly OR get_top_gainers_today OR get_top_losers_today
   → These tools now support weekly data

3. If the user asks about:
   - a specific company
   - stock price
   - company performance
   - company-related news
   - investment advice ("should I buy", "worth buying", "is X a good investment")
   - company analysis or financial health

   → YOU MUST call: finedge_company_tool

4. If the user asks to search news by keyword or topic:
   → YOU MAY call: search_news

5. If the user asks for latest general news:
   → YOU MAY call: get_latest_news

IMPORTANT:
- Always prefer tools when factual market or historical data is requested.
- Never explain your decision.
"""

SYSTEM_FALLBACK_PROMPT = f"""
You are a financial assistant.

CONTEXT:
- Today's date is {today} (IST).

CORE RULES:
- Respond helpfully and naturally.
- NEVER mention:
  - lack of access
  - missing or unavailable data
  - system or tool limitations
  - phrases such as:
    "I can't provide",
    "not available",
    "I don't have the data",
    "check another source",
    "latest price is unavailable".
- NEVER invent prices, index values, or numeric figures.

WHEN A QUESTION ASKS FOR A CURRENT / LIVE NUMERIC VALUE
AND NO VERIFIED NUMBER IS PROVIDED:
- Do NOT refuse the question.
- Do NOT say the data is missing.
- Do NOT give an exact number.
- Instead:
  - Explain what the asset or index represents.
  - Explain what typically influences its movement.
  - Keep the explanation aligned with the user’s intent.

STYLE:
- Calm, confident, and informative.
- Short paragraphs or bullet points.
- No apologies, no disclaimers, no system references.

EXAMPLE OUTPUTS (FOLLOW THIS PATTERN):

Example 1:
User question:
"Current price of Nifty index"

Good answer:
"The Nifty index represents the performance of India’s 50 largest listed companies and moves continuously during market hours based on buying and selling activity.
Its movement is mainly influenced by heavyweight sectors such as banking, IT, and energy, along with global market cues and domestic economic indicators."

Example 2:
User question:
"Live price of Reliance Industries"

Good answer:
"A stock’s price reflects how investors currently value the company based on earnings expectations, business performance, and overall market sentiment.
For large companies like Reliance Industries, price movements are often driven by quarterly results, performance of key business segments, and broader market trends."

MANDATORY:
- End every response with:
  "💡 You may also ask:"
- Suggest 2–3 relevant follow-up questions.
"""


# ============================
# OPENAI CLIENT
# ============================
def get_openai_client():
    return OpenAI(api_key=OPENAI_API_KEY)

# ============================
# TOOLS (LLM SEES THESE)
# ============================
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_news",
            "description": "Search news by keyword",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"}
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_latest_news",
            "description": "Get the latest general news",
            "parameters": {"type": "object", "properties": {}}
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_news_by_sentiment",
            "description": "Get news filtered by sentiment",
            "parameters": {
                "type": "object",
                "properties": {
                    "sentiment": {"type": "string"}
                },
                "required": ["sentiment"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_news_by_impact",
            "description": "Get news filtered by impact",
            "parameters": {
                "type": "object",
                "properties": {
                    "impact": {"type": "string"}
                },
                "required": ["impact"]
            }
        }
    },
    { 
        "type": "function",
        "function":  {
            "name": "finedge_company_tool",
            "description": "Get company data including news, sentiment, and impact analysis. Use for investment advice.",
            "parameters": {
                "type": "object",
                "properties": {
                "company": { "type": "string" },
                "limit": { "type": "integer", "default": 5 }
                },
                "required": ["company"]
        }
    }
},
    {
        "type": "function",
        "function": {
            "name": "get_company_analysis",
            "description": "Get comprehensive company analysis with financial data",
            "parameters": {
                "type": "object",
                "properties": {
                    "company": {"type": "string"},
                    "analysis_type": {
                        "type": "string",
                        "enum": ["comprehensive", "financial", "valuation"],
                        "default": "comprehensive"
                    }
                },
                "required": ["company"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "analyze_financial_health",
            "description": "Analyze company's financial health and key metrics",
            "parameters": {
                "type": "object",
                "properties": {
                    "company": {"type": "string"}
                },
                "required": ["company"]
            }
        }
    },
   {
    "type": "function",
    "function": {
        "name": "get_market_news_by_date",
        "description": "Use this tool when the user asks about market conditions for today, yesterday, or any specific date. Extract the date from the question and pass it in YYYY-MM-DD format.",
        "parameters": {
            "type": "object",
            "properties": {
                "date": {
                    "type": "string",
                    "description": "Date in YYYY-MM-DD format"
                },
                "limit": {
                    "type": "integer",
                    "default": 10
                }
            },
            "required": ["date"]
        }
    }
},
    {
        "type": "function",
        "function": {
            "name": "get_stock_price",
            "description": "Get real-time stock price from Yahoo Finance",
            "parameters": {
                "type": "object",
                "properties": {
                    "company": {"type": "string"}
                },
                "required": ["company"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_trending_stocks_today",
            "description": "Get today's trending stocks. Use for volatile stocks, top movers queries.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "default": 10}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_trending_stocks_weekly",
            "description": "Get weekly trending stocks with price changes over the past week. Use when user asks about 'this week', 'weekly', or 'past week' performance.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "default": 10}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_top_gainers_today",
            "description": "Get top gaining stocks TODAY. Use only for today's or daily gainers.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "default": 10}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_top_gainers_weekly",
            "description": "Get top gaining stocks THIS WEEK. Use when user asks about 'this week', 'weekly', or 'past week' gainers.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "default": 10}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_top_losers_today",
            "description": "Get top losing stocks TODAY. Use only for today's or daily losers.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "default": 10}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_top_losers_weekly",
            "description": "Get top losing stocks THIS WEEK. Use when user asks about 'this week', 'weekly', or 'past week' losers.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "default": 10}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_market_overview",
            "description": "Get market summary with Nifty 50 data. Use for market sentiment, market status, overall market queries.",
            "parameters": {"type": "object", "properties": {}}
        }
    }
]

# ============================
# TOOL MAP (EXECUTION)
# ============================
TOOL_MAP = {
    "search_news":search_news,
    "get_latest_news":get_latest_news,
    "get_news_by_sentiment": get_news_by_sentiment,
    "get_news_by_impact": get_news_by_impact,
    "finedge_company_tool": finedge_company_tool,
    "get_market_news_by_date": get_market_news_by_date,
    "get_company_analysis": get_company_analysis,
    "analyze_financial_health": analyze_financial_health,
    "get_stock_price": get_stock_price,
    "get_trending_stocks_today": get_trending_stocks_today,
    "get_trending_stocks_weekly": get_trending_stocks_weekly,
    "get_top_gainers_today": get_top_gainers_today,
    "get_top_gainers_weekly": get_top_gainers_weekly,
    "get_top_losers_today": get_top_losers_today,
    "get_top_losers_weekly": get_top_losers_weekly,
    "get_market_overview": get_market_overview,
}


def is_tool_result_relevant(question: str, tool_name: str, tool_result) -> bool:
    q = question.lower()
    print(f"🔍 DEBUG: Question='{q}', Tool='{tool_name}'")
    print(f"🔍 DEBUG: Tool result type={type(tool_result)}")
    
    # -------- MARKET OVERVIEW QUERIES (CHECK FIRST) --------
    if any(word in q for word in ["overview", "summary", "sentiment", "market status", "how is market"]):
        if tool_name == "get_market_overview":
            has_nifty = bool(tool_result.get("nifty_50"))
            print(f"🔍 DEBUG: Market overview - Has nifty data: {has_nifty}")
            return has_nifty
    
    # -------- COMPANY ANALYSIS QUERIES --------
    if any(word in q for word in ["worth", "buying", "buy", "analysis", "company", "stock", "should i", "invest"]):
        print(f"🔍 DEBUG: Matched company analysis keywords")
        if tool_name == "finedge_company_tool":
            print(f"🔍 DEBUG: Tool name matches finedge_company_tool")
            # Check if we have news data (more important than quote for analysis)
            has_news = bool(tool_result and tool_result.get("news") and len(tool_result.get("news", [])) > 0)
            has_company = bool(tool_result and tool_result.get("company"))
            print(f"🔍 DEBUG: Has news: {has_news}, Has company: {has_company}")
            return has_news or has_company
        if tool_name == "get_stock_price":
            has_price = bool(tool_result and tool_result.get("current_price"))
            print(f"🔍 DEBUG: Has price data: {has_price}")
            return has_price
        return False
    
    # -------- DATE / MARKET PERFORMANCE QUERIES --------
    if any(word in q for word in ["yesterday", "performed", "date", "today", "falling", "rising", "why"]):
        print(f"🔍 DEBUG: Matched market query keywords")
        if tool_name == "get_market_news_by_date":
            print(f"🔍 DEBUG: Tool name matches get_market_news_by_date")
            has_news = bool(tool_result.get("news") and len(tool_result.get("news", [])) > 0)
            print(f"🔍 DEBUG: Has news data: {has_news}")
            return has_news
        elif tool_name == "get_latest_news":
            print(f"🔍 DEBUG: Tool name matches get_latest_news")
            has_news = bool(isinstance(tool_result, list) and len(tool_result) > 0)
            print(f"🔍 DEBUG: Has news data: {has_news}")
            return has_news
        return False

    # -------- REAL-TIME PRICE QUERIES --------
    if any(word in q for word in ["price", "current", "live", "real-time", "quote"]):
        if tool_name == "get_stock_price":
            return bool(tool_result.get("current_price"))
        return False

    # -------- TRENDING/GAINERS/LOSERS QUERIES --------
    if any(word in q for word in ["trending", "gainers", "losers", "top", "best", "worst", "volatile"]):
        print(f"🔍 DEBUG: Matched gainers/losers query")
        if tool_name in ["get_trending_stocks_today", "get_trending_stocks_weekly", 
                        "get_top_gainers_today", "get_top_gainers_weekly",
                        "get_top_losers_today", "get_top_losers_weekly"]:
            print(f"🔍 DEBUG: Tool name matches gainers/losers tools")
            has_data = bool(tool_result and len(tool_result) > 0)
            print(f"🔍 DEBUG: Has stock data: {has_data}")
            return has_data
        # If no data from trending tools, still try to answer from news
        if tool_name == "get_latest_news":
            has_news = bool(isinstance(tool_result, list) and len(tool_result) > 0)
            return has_news
        return False

    # -------- DEFAULT: tool relevant --------
    print(f"🔍 DEBUG: Using default relevance = True")
    return True

# ============================
# MAIN LLM FUNCTION
# ============================
def ask_llm(question: str, history: list = None) -> str:
    print("\n==============================")
    print("USER QUESTION:", question)
    print("==============================")

    global CHAT_HISTORY

    client = get_openai_client()

    # -------- Tool decision step (LLM ONLY) --------
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": TOOL_DECISION_PROMPT},
            *CHAT_HISTORY,
            {"role": "user", "content": question},
        ],
        tools=TOOLS,
        tool_choice="auto",
        temperature=0,
    )

    msg = response.choices[0].message

    if msg.tool_calls:
        print("🔧 TOOL CHOSEN BY LLM:", msg.tool_calls[0].function.name)
        print("📦 RAW TOOL ARGS:", msg.tool_calls[0].function.arguments)
    else:
        print("🧠 NO TOOL CHOSEN — LLM ANSWERING DIRECTLY")


    # -------- Tool execution path --------
    if msg.tool_calls:
        tool_call = msg.tool_calls[0]
        tool_name = tool_call.function.name
        args = json.loads(tool_call.function.arguments or "{}")

        print("▶️ EXECUTING TOOL:", tool_name)
        print("▶️ WITH ARGUMENTS:", args)

        tool_result = TOOL_MAP[tool_name](**args)

        if isinstance(tool_result, dict):
            print("✅ TOOL EXECUTED SUCCESSFULLY")
            print("📊 RESULT KEYS:", list(tool_result.keys()))
            if "count" in tool_result:
                print("📰 NEWS COUNT:", tool_result["count"])
            
            # Debug: Print actual data to see what's being returned
            print("🔍 SAMPLE DATA:")
            for key, value in tool_result.items():
                if isinstance(value, dict) and value:
                    print(f"  {key}: {list(value.keys())[:5]}...")  # Show first 5 keys
                    # Show actual values for quote data
                    if key == 'quote' and value:
                        for qkey, qval in list(value.items())[:3]:
                            print(f"    {qkey}: {qval}")
                elif value:
                    print(f"  {key}: {str(value)[:100]}...")  # Show first 100 chars
        elif isinstance(tool_result, list):
            print("✅ TOOL EXECUTED SUCCESSFULLY")
            print("📰 ITEMS RETURNED:", len(tool_result))
        else:
            print("⚠️ TOOL RETURNED UNKNOWN FORMAT")


        use_tool = is_tool_result_relevant(question, tool_name, tool_result)
        print(f"🤔 TOOL RELEVANCE CHECK: {use_tool}")
        
        if use_tool:
            # Tool is relevant → pass data with explicit instruction
            data_context = f"""
USER QUESTION: {question}

ACTUAL DATA FROM DATABASE/API:
{json.dumps(tool_result, indent=2)}

INSTRUCTIONS:
- Analyze the ACTUAL DATA provided above
- Extract ALL relevant numbers, prices, percentages, company names
- If news is provided, analyze sentiment (bullish/bearish) and impact (high/medium/low)
- If price data is provided, mention current_price, change, change_percent, volume, high, low
- Provide investment recommendation based on the data
- Be specific and data-driven, not generic
"""
            final = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": SYSTEM_FINAL_PROMPT},
                    *CHAT_HISTORY,
                    {"role": "user", "content": data_context},
                ],
                temperature=0.3,
                max_tokens=800
            )
        else:
            # Tool is irrelevant → IGNORE it completely
            final = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": SYSTEM_FALLBACK_PROMPT},
                    *CHAT_HISTORY,
                    {"role": "user", "content": question},
                ],
                temperature=0.6,
            )




        answer = final.choices[0].message.content

    # -------- No tool path --------
    else:
        final = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": SYSTEM_FINAL_PROMPT},
                *CHAT_HISTORY,
                {"role": "user", "content": question},
            ],
            temperature=0.6,
        )

        answer = final.choices[0].message.content

    # -------- Save memory --------
    CHAT_HISTORY.append({"role": "user", "content": question})
    CHAT_HISTORY.append({"role": "assistant", "content": answer})

    return answer
